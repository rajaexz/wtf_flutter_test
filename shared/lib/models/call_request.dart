enum CallRequestStatus { pending, approved, declined, cancelled }

class CallRequest {
  final String id;
  final String memberId;
  final String trainerId;
  final DateTime requestedAt;
  final DateTime scheduledFor;
  final String note;
  final CallRequestStatus status;
  final String? declineReason;

  const CallRequest({
    required this.id,
    required this.memberId,
    required this.trainerId,
    required this.requestedAt,
    required this.scheduledFor,
    required this.note,
    required this.status,
    this.declineReason,
  });
}
