import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/notification_service.dart';
import '../../../domain/entities/call_request_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_request_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scheduledIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    ref.watch(callRequestsProvider(user.id));
    ref.listen(callRequestsProvider(user.id), (_, next) {
      for (final r in next.valueOrNull ?? const <CallRequestEntity>[]) {
        if (r.status == CallRequestStatus.approved &&
            !_scheduledIds.contains(r.id)) {
          _scheduledIds.add(r.id);
          NotificationService.instance.scheduleCallReminder(
            callRequestId: r.id,
            scheduledFor: r.scheduledFor,
            title: 'Ready to join?',
            body: 'Your call starts soon. Check mic and camera.',
          );
        }
      }
    });

    final upcoming = ref.watch(upcomingCallsProvider(user.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryLight, AppColors.primaryDark],
                        ),
                        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'A',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi, ${user.name}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'Trainer • Lead Coach',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
                      onPressed: () {
                        ref.read(currentUserProvider.notifier).logout();
                        context.go('/login');
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF3A1020),
                      Color(0xFF1A0A10),
                      AppColors.surface,
                    ],
                  ),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coach Dashboard',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Manage members, chats, call requests, and session logs.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
            ),
            if (upcoming.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upcoming Calls',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...upcoming.map(
                        (call) => _UpcomingCallCard(
                          scheduledFor: call.scheduledFor,
                          callRequestId: call.id,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ActionCard(
                    label: AppStrings.members,
                    subtitle: 'View assigned members',
                    icon: Icons.people_rounded,
                    onTap: () => context.push('/members'),
                  ).animate().fadeIn(delay: 80.ms).slideX(begin: 0.05, end: 0),
                  _ActionCard(
                    label: AppStrings.chats,
                    subtitle: 'Reply to member messages',
                    icon: Icons.chat_bubble_rounded,
                    onTap: () => context.push('/chat'),
                  ).animate().fadeIn(delay: 140.ms).slideX(begin: 0.05, end: 0),
                  _ActionCard(
                    label: AppStrings.requests,
                    subtitle: 'Approve or decline calls',
                    icon: Icons.calendar_month_rounded,
                    onTap: () => context.push('/requests'),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.05, end: 0),
                  _ActionCard(
                    label: AppStrings.sessions,
                    subtitle: 'Notes and session history',
                    icon: Icons.bar_chart_rounded,
                    onTap: () => context.push('/sessions'),
                  ).animate().fadeIn(delay: 260.ms).slideX(begin: 0.05, end: 0),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.35),
                        AppColors.primaryLight.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                  child: Icon(icon, color: AppColors.primaryLight, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingCallCard extends StatefulWidget {
  final DateTime scheduledFor;
  final String callRequestId;

  const _UpcomingCallCard({
    required this.scheduledFor,
    required this.callRequestId,
  });

  @override
  State<_UpcomingCallCard> createState() => _UpcomingCallCardState();
}

class _UpcomingCallCardState extends State<_UpcomingCallCard> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNow = widget.scheduledFor.difference(DateTime.now()).abs().inMinutes <= 10;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNow ? AppColors.wineSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNow ? AppColors.primaryLight : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam_rounded, color: AppColors.primaryLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Video Call',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${widget.scheduledFor.day}/${widget.scheduledFor.month} at ${widget.scheduledFor.hour.toString().padLeft(2, '0')}:${widget.scheduledFor.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (isNow)
            FilledButton.icon(
              onPressed: () => context.push('/call/${widget.callRequestId}'),
              icon: const Icon(Icons.videocam, size: 16),
              label: const Text(AppStrings.joinCall),
              style: FilledButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
