import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/services/notification_service.dart';
import '../../core/utils/app_logger.dart';
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
  static const _tokenServerUrl = String.fromEnvironment(
    'TOKEN_SERVER_URL',
    defaultValue: 'http://192.168.1.3:3000',
  );

  @override
  Stream<List<CallRequestEntity>> build(String arg) {
    return ref.read(callRequestRepositoryProvider).watchRequests(arg);
  }

  Future<void> approve(CallRequestEntity request) async {
    await ref.read(callRequestRepositoryProvider).updateStatus(
          request.id,
          CallRequestStatus.approved,
        );

    // Create real 100ms room (or mock) via token server
    String hmsRoomId = 'room_${request.id}';
    try {
      final res = await http
          .post(
            Uri.parse('$_tokenServerUrl/rooms'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'callRequestId': request.id,
              'description': 'WTF call ${request.note}',
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        hmsRoomId = body['roomId'] as String? ?? hmsRoomId;
        logger.rtc('[SCHEDULE] 100ms room created: $hmsRoomId');
      } else {
        logger.rtc('[SCHEDULE] room create failed: ${res.body}');
      }
    } catch (e) {
      logger.rtc('[SCHEDULE] room create error: $e');
    }

    final meta = RoomMetaEntity(
      id: const Uuid().v4(),
      callRequestId: request.id,
      hmsRoomId: hmsRoomId,
      hmsRoleMember: 'guest',
      hmsRoleTrainer: 'host',
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

    // Push + local reminder
    await NotificationService.instance.showNow(
      title: 'Call approved',
      body: 'Call approved for $formatted.',
    );
    await NotificationService.instance.scheduleCallReminder(
      callRequestId: request.id,
      scheduledFor: request.scheduledFor,
      title: 'Ready to join?',
      body: 'Your call starts soon. Check mic and camera.',
    );
    await NotificationService.instance.notifyRemote(
      userId: request.memberId,
      title: 'Call approved',
      body: 'Call approved for $formatted.',
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

    await NotificationService.instance.notifyRemote(
      userId: request.memberId,
      title: 'Call declined',
      body: 'Call request declined. Reason: $reason',
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
