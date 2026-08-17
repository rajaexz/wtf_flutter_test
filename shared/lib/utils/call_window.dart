/// Returns true when Join Call should be shown (from 10 min before until 1h after).
bool canJoinCall(DateTime scheduledFor, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final windowStart = scheduledFor.subtract(const Duration(minutes: 10));
  final windowEnd = scheduledFor.add(const Duration(hours: 1));
  return !n.isBefore(windowStart) && !n.isAfter(windowEnd);
}

int sessionDurationSec(DateTime startedAt, DateTime endedAt) {
  final sec = endedAt.difference(startedAt).inSeconds;
  return sec < 0 ? 0 : sec;
}

bool isPastSlot(DateTime slot, {DateTime? now}) {
  return slot.isBefore(now ?? DateTime.now());
}

bool exceedsNoteLimit(String note, {int max = 140}) => note.length > max;
