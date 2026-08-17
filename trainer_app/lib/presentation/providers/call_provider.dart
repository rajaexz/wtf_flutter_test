import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/app_logger.dart';
import '../../domain/entities/session_log_entity.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

enum CallState { idle, connecting, connected, ended }

class CallStateData {
  final CallState state;
  final DateTime? joinedAt;
  final String? roomId;

  const CallStateData({
    required this.state,
    this.joinedAt,
    this.roomId,
  });

  CallStateData copyWith({
    CallState? state,
    DateTime? joinedAt,
    String? roomId,
  }) {
    return CallStateData(
      state: state ?? this.state,
      joinedAt: joinedAt ?? this.joinedAt,
      roomId: roomId ?? this.roomId,
    );
  }
}

final callProvider = AsyncNotifierProvider<CallNotifier, CallStateData>(CallNotifier.new);

class CallNotifier extends AsyncNotifier<CallStateData> {
  @override
  Future<CallStateData> build() async {
    return const CallStateData(state: CallState.idle);
  }

  /// Called when ZEGOCLOUD call screen becomes active.
  void onCallStarted(String callRequestId) {
    logger.rtc('[CALL] trainer started callRequestId=$callRequestId');
    state = AsyncData(CallStateData(
      state: CallState.connected,
      joinedAt: DateTime.now(),
      roomId: callRequestId,
    ));
  }

  /// Called when ZEGOCLOUD onCallEnd fires or user taps End.
  Future<void> endCall(String callRequestId) async {
    final current = state.valueOrNull;
    final joinedAt = current?.joinedAt ?? DateTime.now();
    final endedAt = DateTime.now();
    final durationSec = endedAt.difference(joinedAt).inSeconds;

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      // Resolve memberId from call request
      String memberId = 'member_dk';
      try {
        final requests = await ref.read(callRequestRepositoryProvider).getRequests(user.id);
        final match = requests.where((r) => r.id == callRequestId).toList();
        if (match.isNotEmpty) memberId = match.first.memberId;
      } catch (_) {}

      final log = SessionLogEntity(
        id: const Uuid().v4(),
        memberId: memberId,
        trainerId: user.id,
        startedAt: joinedAt,
        endedAt: endedAt,
        durationSec: durationSec,
      );
      await ref.read(sessionLogRepositoryProvider).saveLog(log);
      logger.rtc('[CALL] session log saved: ${log.id}');
    }

    state = const AsyncData(CallStateData(state: CallState.ended));
  }
}
