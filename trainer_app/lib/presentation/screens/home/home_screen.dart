import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_request_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final upcoming = ref.watch(upcomingCallsProvider(user.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${user.name}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Text(
              'Trainer',
              style: TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: AppColors.textSecondary),
            onPressed: () {
              ref.read(currentUserProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (upcoming.isNotEmpty) ...[
            const Text(
              'Upcoming Calls',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...upcoming.map((call) => _UpcomingCallCard(
                  scheduledFor: call.scheduledFor,
                  callRequestId: call.id,
                )),
            const SizedBox(height: 16),
          ],
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            label: AppStrings.members,
            icon: Icons.people_outline_rounded,
            color: AppColors.primary,
            onTap: () => context.go('/members'),
          ),
          _ActionCard(
            label: AppStrings.chats,
            icon: Icons.chat_bubble_outline_rounded,
            color: const Color(0xFF1769E0),
            onTap: () => context.go('/chat'),
          ),
          _ActionCard(
            label: AppStrings.requests,
            icon: Icons.calendar_month_outlined,
            color: AppColors.warning,
            onTap: () => context.go('/requests'),
          ),
          _ActionCard(
            label: AppStrings.sessions,
            icon: Icons.bar_chart_rounded,
            color: AppColors.success,
            onTap: () => context.go('/sessions'),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _UpcomingCallCard extends StatelessWidget {
  final DateTime scheduledFor;
  final String callRequestId;

  const _UpcomingCallCard({
    required this.scheduledFor,
    required this.callRequestId,
  });

  @override
  Widget build(BuildContext context) {
    final isNow = scheduledFor.difference(DateTime.now()).abs().inMinutes <= 10;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNow ? AppColors.primary.withAlpha(15) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isNow ? AppColors.primary : AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Video Call',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${scheduledFor.day}/${scheduledFor.month} at ${scheduledFor.hour.toString().padLeft(2, '0')}:${scheduledFor.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          if (isNow)
            FilledButton.icon(
              onPressed: () => context.go('/call/$callRequestId'),
              icon: const Icon(Icons.videocam, size: 16),
              label: const Text(AppStrings.joinCall),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
