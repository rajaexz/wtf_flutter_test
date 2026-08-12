import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/error/failures.dart';
import '../../core/services/notification_service.dart';
import '../../domain/entities/call_request_entity.dart';
import '../../domain/usecases/request_call_usecase.dart';
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

  Future<Failure?> requestCall(DateTime scheduledFor, String note) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return const AuthFailure('Not logged in.');

    final trainerId = user.assignedTrainerId ?? '';
    final request = CallRequestEntity(
      id: const Uuid().v4(),
      memberId: user.id,
      trainerId: trainerId,
      requestedAt: DateTime.now(),
      scheduledFor: scheduledFor,
      note: note,
      status: CallRequestStatus.pending,
    );

    final useCase = RequestCallUseCase(ref.read(callRequestRepositoryProvider));
    final failure = await useCase(request);
    if (failure == null) {
      await NotificationService.instance.showNow(
        title: 'Call requested',
        body: 'Call requested. Waiting for trainer approval.',
      );
      await NotificationService.instance.scheduleCallReminder(
        callRequestId: request.id,
        scheduledFor: scheduledFor,
        title: 'Ready to join?',
        body: 'Your call starts soon. Check mic and camera.',
      );
      await NotificationService.instance.notifyRemote(
        userId: trainerId,
        title: 'New call request',
        body: '${user.name}: $note',
      );
    }
    return failure;
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
