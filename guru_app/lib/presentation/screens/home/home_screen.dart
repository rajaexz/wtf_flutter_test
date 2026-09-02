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

  // Tracks the last known status for each call request so we can detect changes.
  final _prevStatus = <String, CallRequestStatus>{};

  // One persistent bottom-sheet controller per pending request id.
  final _sheetControllers = <String, PersistentBottomSheetController>{};

  // Key to access ScaffoldState for showBottomSheet.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    for (final c in _sheetControllers.values) {
      c.close();
    }
    _sheetControllers.clear();
    super.dispose();
  }

  void _handleRequestChanges(List<CallRequestEntity> requests) {
    for (final r in requests) {
      final prev = _prevStatus[r.id];
      _prevStatus[r.id] = r.status;

      // ── Schedule local reminder once when approved ──────────────────────────
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

      // ── Open a persistent sheet for newly-pending requests ──────────────────
      if (r.status == CallRequestStatus.pending &&
          !_sheetControllers.containsKey(r.id)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final scaffoldState = _scaffoldKey.currentState;
          if (scaffoldState == null) return;
          final controller = scaffoldState.showBottomSheet(
            enableDrag: false,
            backgroundColor: Colors.transparent,
            (_) => _PendingApprovalSheet(request: r),
          );
          _sheetControllers[r.id] = controller;
        });
      }

      // ── Close the sheet when the request is no longer pending ───────────────
      if (prev == CallRequestStatus.pending &&
          r.status != CallRequestStatus.pending) {
        final controller = _sheetControllers.remove(r.id);
        controller?.close();

        if (!mounted) return;
        final ctx = _scaffoldKey.currentContext;
        if (ctx == null) return;

        if (r.status == CallRequestStatus.approved) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: const Text('✅ Call request approved by your trainer!'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () => ctx.push('/requests'),
              ),
            ),
          );
        } else if (r.status == CallRequestStatus.declined) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(
                r.declineReason != null && r.declineReason!.isNotEmpty
                    ? 'Call declined: ${r.declineReason}'
                    : 'Call request was declined.',
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    // Keep requests synced + react to status changes
    ref.watch(callRequestsProvider(user.id));
    ref.listen(callRequestsProvider(user.id), (_, next) {
      final requests = next.valueOrNull ?? const <CallRequestEntity>[];
      _handleRequestChanges(requests);
    });

    final upcoming = ref.watch(upcomingCallsProvider(user.id));

    return Scaffold(
      key: _scaffoldKey,
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
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'D',
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
                              'Member • Guru',
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
                        context.go('/onboarding');
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
                      'Ready to train?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Chat with Aarav, schedule a call, or review your sessions.',
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
                    label: AppStrings.chatWithTrainer,
                    subtitle: 'Message Aarav anytime',
                    icon: Icons.chat_bubble_rounded,
                    onTap: () => context.push('/chat'),
                  ).animate().fadeIn(delay: 80.ms).slideX(begin: 0.05, end: 0),
                  _ActionCard(
                    label: AppStrings.scheduleCall,
                    subtitle: 'Book a 30-min slot',
                    icon: Icons.calendar_month_rounded,
                    onTap: () => context.push('/schedule'),
                  ).animate().fadeIn(delay: 140.ms).slideX(begin: 0.05, end: 0),
                  _ActionCard(
                    label: AppStrings.mySessions,
                    subtitle: 'Ratings, notes & history',
                    icon: Icons.bar_chart_rounded,
                    onTap: () => context.push('/sessions'),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.05, end: 0),
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
    // Rebuild every 30 seconds so the Join button appears right on time
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
    // Show Join button from 30 min before until 2 hours after scheduled time
    final diff = widget.scheduledFor.difference(DateTime.now());
    final isNow = diff.inMinutes <= 30 && diff.inHours >= -2;

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

class _PendingApprovalSheet extends StatelessWidget {
  final CallRequestEntity request;

  const _PendingApprovalSheet({required this.request});

  @override
  Widget build(BuildContext context) {
    final dt = request.scheduledFor;
    final formatted =
        '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Waiting for trainer approval…',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Call requested for $formatted',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
