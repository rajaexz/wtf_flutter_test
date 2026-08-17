import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final IconData icon;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCta,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight.withValues(alpha: 0.4),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, size: 40, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onCta,
                child: Text(ctaLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
