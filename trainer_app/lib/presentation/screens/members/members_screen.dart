import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../widgets/trainer_app_bar.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const members = [
      (id: 'member_dk', name: 'DK', email: 'dk@guru.app'),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: trainerAppBar(context: context, title: AppStrings.members),
      body: members.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 64, color: AppColors.textTertiary),
                  SizedBox(height: 16),
                  Text(
                    AppStrings.emptyMembersTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    AppStrings.emptyMembersSubtitle,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: members.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (_, i) {
                final member = members[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1769E0).withAlpha(20),
                    child: Text(
                      member.name[0],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1769E0),
                      ),
                    ),
                  ),
                  title: Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    member.email,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                  onTap: () {},
                );
              },
            ),
    );
  }
}
