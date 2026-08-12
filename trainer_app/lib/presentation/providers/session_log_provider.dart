import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/session_log_entity.dart';
import 'repository_providers.dart';

final sessionLogsProvider =
    StreamNotifierProviderFamily<SessionLogsNotifier, List<SessionLogEntity>, String>(
  SessionLogsNotifier.new,
);

class SessionLogsNotifier
    extends FamilyStreamNotifier<List<SessionLogEntity>, String> {
  @override
  Stream<List<SessionLogEntity>> build(String arg) {
    return ref.read(sessionLogRepositoryProvider).watchLogs(arg);
  }

  Future<void> addNotes(SessionLogEntity log, String notes) async {
    final updated = log.copyWith(trainerNotes: notes);
    await ref.read(sessionLogRepositoryProvider).updateLog(updated);
  }
}

enum SessionFilter { all, lastWeek, thisMonth }

final sessionFilterProvider = StateProvider<SessionFilter>((ref) => SessionFilter.all);

final filteredSessionLogsProvider = Provider.family<List<SessionLogEntity>, String>((ref, memberId) {
  final logs = ref.watch(sessionLogsProvider(memberId)).valueOrNull ?? [];
  final filter = ref.watch(sessionFilterProvider);
  final now = DateTime.now();

  return switch (filter) {
    SessionFilter.all => logs,
    SessionFilter.lastWeek =>
      logs.where((l) => l.startedAt.isAfter(now.subtract(const Duration(days: 7)))).toList(),
    SessionFilter.thisMonth =>
      logs.where((l) => l.startedAt.month == now.month && l.startedAt.year == now.year).toList(),
  };
});
