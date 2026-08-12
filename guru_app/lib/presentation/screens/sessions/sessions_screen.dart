import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/extensions.dart';
import '../../../domain/entities/session_log_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_log_provider.dart';
import '../../widgets/empty_state.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final filter = ref.watch(sessionFilterProvider);
    final logs = ref.watch(filteredSessionLogsProvider(user.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'My Sessions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          _FilterChips(current: filter),
          Expanded(
            child: logs.isEmpty
                ? const EmptyState(
                    title: AppStrings.emptySessionsTitle,
                    subtitle: AppStrings.emptySessionsSubtitle,
                    icon: Icons.bar_chart_outlined,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _SessionRow(log: logs[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  final SessionFilter current;

  const _FilterChips({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: SessionFilter.values.map((f) {
          final selected = f == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_label(f)),
              selected: selected,
              onSelected: (_) => ref.read(sessionFilterProvider.notifier).state = f,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
              ),
              backgroundColor: AppColors.surface,
              side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(SessionFilter f) => switch (f) {
        SessionFilter.all => 'All',
        SessionFilter.lastWeek => 'Last 7 days',
        SessionFilter.thisMonth => 'This Month',
      };
}

class _SessionRow extends StatelessWidget {
  final SessionLogEntity log;

  const _SessionRow({required this.log});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.videocam_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.startedAt.shortDate,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log.durationSec.formattedDuration,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (log.rating != null)
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 2),
                  Text(
                    '${log.rating}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SessionDetailSheet(log: log),
    );
  }
}

class _SessionDetailSheet extends StatelessWidget {
  final SessionLogEntity log;

  const _SessionDetailSheet({required this.log});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Session Detail',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _DetailRow('Date', log.startedAt.fullDateTime),
          _DetailRow('Duration', log.durationSec.formattedDuration),
          if (log.rating != null) _DetailRow('Rating', '${log.rating}/5'),
          if (log.memberNotes != null && log.memberNotes!.isNotEmpty)
            _DetailRow('Your notes', log.memberNotes!),
          if (log.trainerNotes != null && log.trainerNotes!.isNotEmpty)
            _DetailRow('Trainer notes', log.trainerNotes!),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
