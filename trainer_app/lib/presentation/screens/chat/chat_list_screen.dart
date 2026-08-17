import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/trainer_app_bar.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    const memberId = 'member_dk';
    final chatId = _chatId(memberId, user.id);
    final messagesAsync = ref.watch(messagesProvider(chatId));
    final unread = ref.watch(unreadCountProvider(chatId));
    final peerOnline = ref.watch(peerOnlineProvider(memberId)).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: trainerAppBar(context: context, title: AppStrings.chats),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/chat/$chatId/$memberId'),
        child: const Icon(Icons.chat_rounded, color: Colors.white),
      ),
      body: messagesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryLight),
        ),
        error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.textSecondary))),
        data: (messages) {
          if (messages.isEmpty) {
            return EmptyState(
              title: AppStrings.emptyChatTitle,
              subtitle: AppStrings.emptyChatSubtitle,
              icon: Icons.chat_bubble_outline,
              ctaLabel: 'Say hi',
              onCta: () => context.push('/chat/$chatId/$memberId'),
            );
          }

          final last = messages.last;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              InkWell(
                onTap: () => context.push('/chat/$chatId/$memberId'),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.memberBubble.withValues(alpha: 0.25),
                            child: const Text(
                              'DK',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.memberBubble,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: peerOnline ? AppColors.onlineDot : AppColors.textTertiary,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.surface, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'DK',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  timeago.format(last.createdAt),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    last.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: unread > 0
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                      fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (unread > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.unreadBadge,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      unread > 9 ? '9+' : '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _chatId(String memberId, String trainerId) {
    final sorted = [memberId, trainerId]..sort();
    return sorted.join('_');
  }
}
