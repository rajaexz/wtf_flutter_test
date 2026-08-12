import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/guru_app_bar.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final trainerId = user.assignedTrainerId ?? '';
    final chatId = _chatId(user.id, trainerId);
    final messagesAsync = ref.watch(messagesProvider(chatId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: guruAppBar(
        context: context,
        title: 'Chats',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primaryLight),
            onPressed: () => context.push('/chat/$chatId'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/chat/$chatId'),
        child: const Icon(Icons.chat_rounded, color: Colors.white),
      ),
      body: messagesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryLight),
        ),
        error: (e, _) => EmptyState(
          title: AppStrings.errorGeneric,
          subtitle: e.toString(),
          icon: Icons.error_outline,
        ),
        data: (messages) {
          if (messages.isEmpty) {
            return EmptyState(
              title: AppStrings.emptyChatTitle,
              subtitle: AppStrings.emptyChatSubtitle,
              icon: Icons.chat_bubble_outline,
              ctaLabel: 'Say hi',
              onCta: () => context.push('/chat/$chatId'),
            );
          }

          final last = messages.last;
          final unread = ref.watch(unreadCountProvider(chatId));

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _ChatRow(
                name: 'Aarav (Lead Trainer)',
                lastMessage: last.text,
                timestamp: last.createdAt,
                unreadCount: unread,
                chatId: chatId,
              ),
            ],
          );
        },
      ),
    );
  }

  String _chatId(String userId, String trainerId) {
    final sorted = [userId, trainerId]..sort();
    return sorted.join('_');
  }
}

class _ChatRow extends StatelessWidget {
  final String name;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final String chatId;

  const _ChatRow({
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.chatId,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/chat/$chatId'),
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
                  backgroundColor: AppColors.primary.withValues(alpha: 0.25),
                  child: const Text(
                    'A',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryLight,
                      fontSize: 18,
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
                      color: AppColors.onlineDot,
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
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        timeago.format(timestamp),
                        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: unreadCount > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.unreadBadge,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
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
    );
  }
}
