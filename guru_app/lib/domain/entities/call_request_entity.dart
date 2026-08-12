enum CallRequestStatus { pending, approved, declined, cancelled }

class CallRequestEntity {
  final String id;
  final String memberId;
  final String trainerId;
  final DateTime requestedAt;
  final DateTime scheduledFor;
  final String note;
  final CallRequestStatus status;
  final String? declineReason;

  const CallRequestEntity({
    required this.id,
    required this.memberId,
    required this.trainerId,
    required this.requestedAt,
    required this.scheduledFor,
    required this.note,
    required this.status,
    this.declineReason,
  });

  CallRequestEntity copyWith({
    CallRequestStatus? status,
    String? declineReason,
  }) {
    return CallRequestEntity(
      id: id,
      memberId: memberId,
      trainerId: trainerId,
      requestedAt: requestedAt,
      scheduledFor: scheduledFor,
      note: note,
      status: status ?? this.status,
      declineReason: declineReason ?? this.declineReason,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'trainerId': trainerId,
        'requestedAt': requestedAt.toIso8601String(),
        'scheduledFor': scheduledFor.toIso8601String(),
        'note': note,
        'status': status.name,
        'declineReason': declineReason,
      };

  factory CallRequestEntity.fromJson(Map<String, dynamic> json) => CallRequestEntity(
        id: json['id'] as String,
        memberId: json['memberId'] as String,
        trainerId: json['trainerId'] as String,
        requestedAt: DateTime.parse(json['requestedAt'] as String),
        scheduledFor: DateTime.parse(json['scheduledFor'] as String),
        note: json['note'] as String,
        status: CallRequestStatus.values.byName(json['status'] as String),
        declineReason: json['declineReason'] as String?,
      );
}
