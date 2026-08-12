import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../../core/utils/app_logger.dart';
import '../../domain/entities/session_log_entity.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

enum CallState { idle, connecting, connected, error, ended }

class CallStateData {
  final CallState state;
  final List<HMSPeer> peers;
  final bool isMuted;
  final bool isVideoOff;
  final String? errorMessage;
  final DateTime? joinedAt;

  const CallStateData({
    required this.state,
    this.peers = const [],
    this.isMuted = false,
    this.isVideoOff = false,
    this.errorMessage,
    this.joinedAt,
  });

  CallStateData copyWith({
    CallState? state,
    List<HMSPeer>? peers,
    bool? isMuted,
    bool? isVideoOff,
    String? errorMessage,
    DateTime? joinedAt,
  }) {
    return CallStateData(
      state: state ?? this.state,
      peers: peers ?? this.peers,
      isMuted: isMuted ?? this.isMuted,
      isVideoOff: isVideoOff ?? this.isVideoOff,
      errorMessage: errorMessage ?? this.errorMessage,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

final callProvider = AsyncNotifierProvider<CallNotifier, CallStateData>(CallNotifier.new);

class CallNotifier extends AsyncNotifier<CallStateData> implements HMSUpdateListener {
  HMSSDK? _sdk;
  static const _tokenServerUrl = 'http://10.0.2.2:3000';

  @override
  Future<CallStateData> build() async {
    return const CallStateData(state: CallState.idle);
  }

  Future<void> joinRoom(String roomId, String callRequestId) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    state = const AsyncData(CallStateData(state: CallState.connecting));
    logger.rtc('[CALL] joining room $roomId as member');

    try {
      final token = await _fetchToken(user.id, 'member');

      _sdk = HMSSDK();
      await _sdk!.build();
      _sdk!.addUpdateListener(listener: this);

      final config = HMSConfig(
        authToken: token,
        userName: user.name,
      );
      await _sdk!.join(config: config);

      state = AsyncData(
        const CallStateData(state: CallState.idle).copyWith(
          state: CallState.connected,
          joinedAt: DateTime.now(),
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

  Future<String> _fetchToken(String userId, String role) async {
    try {
      final uri = Uri.parse('$_tokenServerUrl/token?userId=$userId&role=$role');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['token'] as String;
      }
    } catch (_) {}
    return _mockToken(userId, role);
  }

  String _mockToken(String userId, String role) {
    logger.rtc('[CALL] using mock token for $userId ($role)');
    return 'mock_token_${userId}_$role';
  }

  Future<void> toggleMute() async {
    final current = state.valueOrNull;
    if (current == null || _sdk == null) return;
    if (current.isMuted) {
      await _sdk!.unMuteRoomAudioLocally();
    } else {
      await _sdk!.muteRoomAudioLocally();
    }
    state = AsyncData(current.copyWith(isMuted: !current.isMuted));
  }

  Future<void> toggleVideo() async {
    final current = state.valueOrNull;
    if (current == null || _sdk == null) return;
    final local = await _sdk!.getLocalPeer();
    if (local == null) return;
    final track = local.videoTrack;
    if (track != null) {
      await _sdk!.toggleCameraMuteState();
      state = AsyncData(current.copyWith(isVideoOff: !current.isVideoOff));
    }
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

  @override
  void onJoin({required HMSRoom room}) {
    logger.rtc('[CALL] joined room ${room.id}');
  }

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    final current = state.valueOrNull;
    if (current == null) return;
    final peers = List<HMSPeer>.from(current.peers);
    switch (update) {
      case HMSPeerUpdate.peerJoined:
        if (!peers.any((p) => p.peerId == peer.peerId)) peers.add(peer);
      case HMSPeerUpdate.peerLeft:
        peers.removeWhere((p) => p.peerId == peer.peerId);
      default:
        break;
    }
    state = AsyncData(current.copyWith(peers: peers));
    logger.rtc('[CALL] peer update: ${peer.name} — $update');
  }

  @override
  void onTrackUpdate({required HMSTrack track, required HMSTrackUpdate trackUpdate, required HMSPeer peer}) {}

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
  }

  @override
  void onReconnecting() {
    logger.rtc('[CALL] reconnecting...');
  }

  @override
  void onRemovedFromRoom({required HMSPeerRemovedFromPeer hmsPeerRemovedFromPeer}) {}

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
  }
}
