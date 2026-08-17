class SessionLog {
  final String id;
  final String memberId;
  final String trainerId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSec;
  final int? rating;
  final String? trainerNotes;
  final String? memberNotes;

  const SessionLog({
    required this.id,
    required this.memberId,
    required this.trainerId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSec,
    this.rating,
    this.trainerNotes,
    this.memberNotes,
  });
}
