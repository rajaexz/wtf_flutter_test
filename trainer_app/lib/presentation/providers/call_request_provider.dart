import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/call_request_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/room_meta_entity.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

final callRequestsProvider =
    StreamNotifierProviderFamily<CallRequestsNotifier, List<CallRequestEntity>, String>(
  CallRequestsNotifier.new,
);

class CallRequestsNotifier
    extends FamilyStreamNotifier<List<CallRequestEntity>, String> {
  @override
  Stream<List<CallRequestEntity>> build(String arg) {
    return ref.read(callRequestRepositoryProvider).watchRequests(arg);
  }

  Future<void> approve(CallRequestEntity request) async {
    await ref.read(callRequestRepositoryProvider).updateStatus(
          request.id,
          CallRequestStatus.approved,
        );

    final meta = RoomMetaEntity(
      id: const Uuid().v4(),
      callRequestId: request.id,
      hmsRoomId: 'room_${request.id}',
      hmsRoleMember: 'member',
      hmsRoleTrainer: 'trainer',
    );
    await ref.read(callRequestRepositoryProvider).saveRoomMeta(meta);

    final trainer = ref.read(currentUserProvider).valueOrNull;
    if (trainer == null) return;

    final chatId = _chatId(request.memberId, trainer.id);
    final dt = request.scheduledFor;
    final formatted =
        '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    await ref.read(chatRepositoryProvider).sendMessage(
          MessageEntity(
            id: const Uuid().v4(),
            chatId: chatId,
            senderId: trainer.id,
            receiverId: request.memberId,
            text: 'Call approved for $formatted.',
            createdAt: DateTime.now(),
            status: MessageStatus.sent,
          ),
        );
  }

  Future<void> decline(CallRequestEntity request, String reason) async {
    await ref.read(callRequestRepositoryProvider).updateStatus(
          request.id,
          CallRequestStatus.declined,
          declineReason: reason,
        );

    final trainer = ref.read(currentUserProvider).valueOrNull;
    if (trainer == null) return;

    final chatId = _chatId(request.memberId, trainer.id);

    await ref.read(chatRepositoryProvider).sendMessage(
          MessageEntity(
            id: const Uuid().v4(),
            chatId: chatId,
            senderId: trainer.id,
            receiverId: request.memberId,
            text: 'Call request declined. Reason: $reason',
            createdAt: DateTime.now(),
            status: MessageStatus.sent,
          ),
        );
  }

  String _chatId(String memberId, String trainerId) {
    final sorted = [memberId, trainerId]..sort();
    return sorted.join('_');
  }
}

final upcomingCallsProvider = Provider.family<List<CallRequestEntity>, String>((ref, userId) {
  final requests = ref.watch(callRequestsProvider(userId)).valueOrNull ?? [];
  final now = DateTime.now();
  return requests
      .where((r) =>
          r.status == CallRequestStatus.approved &&
          r.scheduledFor.isAfter(now.subtract(const Duration(hours: 1))))
      .toList();
});
