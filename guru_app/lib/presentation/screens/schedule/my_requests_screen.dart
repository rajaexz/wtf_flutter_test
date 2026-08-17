import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/entities/call_request_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_request_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/guru_app_bar.dart';

class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final async = ref.watch(callRequestsProvider(user.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: guruAppBar(context: context, title: AppStrings.myRequests),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          title: AppStrings.errorGeneric,
          subtitle: e.toString(),
          icon: Icons.error_outline,
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return EmptyState(
              title: 'No requests yet',
              subtitle: AppStrings.emptySessionsSubtitle,
              icon: Icons.event_note_outlined,
              ctaLabel: AppStrings.scheduleCall,
              onCta: () => context.push('/schedule'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(callRequestsProvider(user.id));
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _RequestTile(request: requests[i]),
            ),
          );
        },
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final CallRequestEntity request;

  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final dt = DateFormat('EEE, d MMM • HH:mm').format(request.scheduledFor);
    final (label, color) = switch (request.status) {
      CallRequestStatus.pending => (
          '${AppStrings.pendingApproval} Aarav',
          AppColors.warning,
        ),
      CallRequestStatus.approved => ('Approved', AppColors.success),
      CallRequestStatus.declined => (
          'Declined${request.declineReason != null ? ': ${request.declineReason}' : ''}',
          AppColors.error,
        ),
      CallRequestStatus.cancelled => ('Cancelled', AppColors.textTertiary),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dt,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.note.isEmpty ? 'No note' : request.note,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
