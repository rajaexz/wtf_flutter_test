import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/utils/app_logger.dart';
import '../../domain/entities/session_log_entity.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

enum CallState { idle, connecting, connected, reconnecting, error, ended }

class PeerTile {
  final HMSPeer peer;
  final HMSVideoTrack? videoTrack;

  const PeerTile({required this.peer, this.videoTrack});

  PeerTile copyWith({HMSPeer? peer, HMSVideoTrack? videoTrack}) {
    return PeerTile(
      peer: peer ?? this.peer,
      videoTrack: videoTrack ?? this.videoTrack,
    );
  }
}

class CallStateData {
  final CallState state;
  final List<PeerTile> tiles;
  final bool isMuted;
  final bool isVideoOff;
  final String? errorMessage;
  final DateTime? joinedAt;
  final String? roomId;
  final bool isMockToken;

  const CallStateData({
    required this.state,
    this.tiles = const [],
    this.isMuted = false,
    this.isVideoOff = false,
    this.errorMessage,
    this.joinedAt,
    this.roomId,
    this.isMockToken = false,
  });

  CallStateData copyWith({
    CallState? state,
    List<PeerTile>? tiles,
    bool? isMuted,
    bool? isVideoOff,
    String? errorMessage,
    DateTime? joinedAt,
    String? roomId,
    bool? isMockToken,
  }) {
    return CallStateData(
      state: state ?? this.state,
      tiles: tiles ?? this.tiles,
      isMuted: isMuted ?? this.isMuted,
      isVideoOff: isVideoOff ?? this.isVideoOff,
      errorMessage: errorMessage ?? this.errorMessage,
      joinedAt: joinedAt ?? this.joinedAt,
      roomId: roomId ?? this.roomId,
      isMockToken: isMockToken ?? this.isMockToken,
    );
  }
}

final callProvider = AsyncNotifierProvider<CallNotifier, CallStateData>(CallNotifier.new);

class CallNotifier extends AsyncNotifier<CallStateData> implements HMSUpdateListener {
  HMSSDK? _sdk;

  /// Android emulator → host machine. Override with --dart-define=TOKEN_SERVER_URL=...
  static const _tokenServerUrl = String.fromEnvironment(
    'TOKEN_SERVER_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  @override
  Future<CallStateData> build() async {
    return const CallStateData(state: CallState.idle);
  }

  Future<void> joinRoom({
    required String callRequestId,
    bool micEnabled = true,
    bool camEnabled = true,
  }) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    state = const AsyncData(CallStateData(state: CallState.connecting));
    logger.rtc('[CALL] joining as member for $callRequestId');

    try {
      final tokenResult = await _fetchToken(
        userId: user.id,
        role: 'member',
        callRequestId: callRequestId,
      );

      if (tokenResult.token.startsWith('mock')) {
        throw Exception(
          '100ms credentials missing. Add APP_ACCESS_KEY and APP_SECRET to token_server/.env and restart the server.',
        );
      }

      _sdk = HMSSDK();
      await _sdk!.build();
      _sdk!.addUpdateListener(listener: this);

      final config = HMSConfig(
        authToken: tokenResult.token,
        userName: user.name,
      );
      await _sdk!.join(config: config);

      // Stay in connecting until onJoin — apply pre-join toggles there
      state = AsyncData(
        CallStateData(
          state: CallState.connecting,
          roomId: tokenResult.roomId,
          isMockToken: tokenResult.mock,
          isMuted: !micEnabled,
          isVideoOff: !camEnabled,
        ),
      );
    } catch (e) {
      logger.rtc('[CALL] join failed: $e');
      state = AsyncData(CallStateData(
        state: CallState.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<({String token, String? roomId, bool mock})> _fetchToken({
    required String userId,
    required String role,
    required String callRequestId,
  }) async {
    final uri = Uri.parse(
      '$_tokenServerUrl/token?userId=$userId&role=$role&callRequestId=$callRequestId',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Token server error ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      token: body['token'] as String,
      roomId: body['roomId'] as String?,
      mock: body['mock'] == true,
    );
  }

  Future<void> toggleMute() async {
    final current = state.valueOrNull;
    if (current == null || _sdk == null) return;
    await _sdk!.toggleMicMuteState();
    state = AsyncData(current.copyWith(isMuted: !current.isMuted));
  }

  Future<void> toggleVideo() async {
    final current = state.valueOrNull;
    if (current == null || _sdk == null) return;
    await _sdk!.toggleCameraMuteState();
    state = AsyncData(current.copyWith(isVideoOff: !current.isVideoOff));
  }

  Future<void> switchCamera() async {
    await _sdk?.switchCamera();
  }

  Future<void> endCall(String callRequestId) async {
    final current = state.valueOrNull;
    final joinedAt = current?.joinedAt ?? DateTime.now();
    final endedAt = DateTime.now();
    final durationSec = endedAt.difference(joinedAt).inSeconds;

    await _sdk?.leave();
    _sdk?.removeUpdateListener(listener: this);
    _sdk = null;

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      final log = SessionLogEntity(
        id: const Uuid().v4(),
        memberId: user.id,
        trainerId: user.assignedTrainerId ?? '',
        startedAt: joinedAt,
        endedAt: endedAt,
        durationSec: durationSec,
      );
      await ref.read(sessionLogRepositoryProvider).saveLog(log);
      logger.rtc('[CALL] session log saved: ${log.id}');
    }

    state = const AsyncData(CallStateData(state: CallState.ended));
  }

  void _upsertTile(HMSPeer peer, {HMSVideoTrack? track}) {
    final current = state.valueOrNull;
    if (current == null) return;
    final tiles = List<PeerTile>.from(current.tiles);
    final idx = tiles.indexWhere((t) => t.peer.peerId == peer.peerId);
    if (idx >= 0) {
      tiles[idx] = tiles[idx].copyWith(
        peer: peer,
        videoTrack: track ?? tiles[idx].videoTrack,
      );
    } else {
      tiles.add(PeerTile(peer: peer, videoTrack: track));
    }
    state = AsyncData(current.copyWith(tiles: tiles));
  }

  void _removeTile(HMSPeer peer) {
    final current = state.valueOrNull;
    if (current == null) return;
    final tiles = current.tiles.where((t) => t.peer.peerId != peer.peerId).toList();
    state = AsyncData(current.copyWith(tiles: tiles));
  }

  @override
  void onJoin({required HMSRoom room}) {
    logger.rtc('[CALL] joined room ${room.id}');
    final current = state.valueOrNull;
    final tiles = <PeerTile>[];
    for (final p in room.peers ?? const <HMSPeer>[]) {
      if (p.isLocal) {
        tiles.add(PeerTile(peer: p, videoTrack: p.videoTrack));
        break;
      }
    }

    state = AsyncData(
      (current ?? const CallStateData(state: CallState.idle)).copyWith(
        state: CallState.connected,
        joinedAt: DateTime.now(),
        roomId: room.id,
        tiles: tiles,
      ),
    );

    // Apply pre-join mic/cam preferences
    if (current?.isMuted == true) {
      _sdk?.toggleMicMuteState();
    }
    if (current?.isVideoOff == true) {
      _sdk?.toggleCameraMuteState();
    }
  }

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    switch (update) {
      case HMSPeerUpdate.peerJoined:
        _upsertTile(peer);
      case HMSPeerUpdate.peerLeft:
        _removeTile(peer);
      case HMSPeerUpdate.nameChanged:
      case HMSPeerUpdate.metadataChanged:
      case HMSPeerUpdate.roleUpdated:
        _upsertTile(peer);
      default:
        break;
    }
    logger.rtc('[CALL] peer update: ${peer.name} — $update');
  }

  @override
  void onTrackUpdate({
    required HMSTrack track,
    required HMSTrackUpdate trackUpdate,
    required HMSPeer peer,
  }) {
    if (track.kind != HMSTrackKind.kHMSTrackKindVideo) return;
    if (track.source != 'REGULAR') return;

    final videoTrack = track as HMSVideoTrack;
    if (trackUpdate == HMSTrackUpdate.trackRemoved) {
      final current = state.valueOrNull;
      if (current == null) return;
      final tiles = current.tiles.map((t) {
        if (t.peer.peerId == peer.peerId) {
          return PeerTile(peer: peer, videoTrack: null);
        }
        return t;
      }).toList();
      state = AsyncData(current.copyWith(tiles: tiles));
      return;
    }

    _upsertTile(peer, track: videoTrack);
    logger.rtc('[CALL] video track ${trackUpdate.name} for ${peer.name}');
  }

  @override
  void onMessage({required HMSMessage message}) {}

  @override
  void onRoleChangeRequest({required HMSRoleChangeRequest roleChangeRequest}) {}

  @override
  void onUpdateSpeakers({required List<HMSSpeaker> updateSpeakers}) {}

  @override
  void onRoomUpdate({required HMSRoom room, required HMSRoomUpdate update}) {}

  @override
  void onReconnected() {
    logger.rtc('[CALL] reconnected');
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(state: CallState.connected));
    }
  }

  @override
  void onReconnecting() {
    logger.rtc('[CALL] reconnecting...');
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(state: CallState.reconnecting));
    }
  }

  @override
  void onRemovedFromRoom({required HMSPeerRemovedFromPeer hmsPeerRemovedFromPeer}) {
    state = const AsyncData(CallStateData(state: CallState.ended));
  }

  @override
  void onChangeTrackStateRequest({required HMSTrackChangeRequest hmsTrackChangeRequest}) {}

  @override
  void onSessionStoreAvailable({HMSSessionStore? hmsSessionStore}) {}

  @override
  void onPeerListUpdate({required List<HMSPeer> addedPeers, required List<HMSPeer> removedPeers}) {}

  @override
  void onAudioDeviceChanged({
    HMSAudioDevice? currentAudioDevice,
    List<HMSAudioDevice>? availableAudioDevice,
  }) {}

  @override
  void onHMSError({required HMSException error}) {
    logger.rtc('[CALL] hms error: ${error.message}');
    state = AsyncData(CallStateData(
      state: CallState.error,
      errorMessage: error.message.isNotEmpty ? error.message : '100ms error',
    ));
  }
}
