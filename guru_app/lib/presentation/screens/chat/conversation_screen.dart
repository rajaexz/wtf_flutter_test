import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/typing_indicator.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ConversationScreen({super.key, required this.chatId});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messagesProvider(widget.chatId).notifier).markRead();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _textController.clear();
    await ref.read(messagesProvider(widget.chatId).notifier).send(text.trim());
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
    final isTyping = ref.watch(isTypingProvider(widget.chatId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.trainerBubble.withAlpha(20),
              child: const Text(
                'A',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.trainerBubble,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aarav',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Lead Trainer',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                title: AppStrings.errorGeneric,
                subtitle: e.toString(),
                icon: Icons.error_outline,
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const EmptyState(
                    title: AppStrings.emptyChatTitle,
                    subtitle: AppStrings.emptyChatSubtitle,
                    icon: Icons.chat_bubble_outline,
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length + (isTyping ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (isTyping && i == messages.length) {
                      return const TypingIndicator();
                    }
                    final msg = messages[i];
                    return ChatBubble(
                      message: msg,
                      isMe: msg.senderId == user?.id,
                    );
                  },
                );
              },
            ),
          ),
          _QuickReplies(onReply: _send),
          _MessageInput(
            controller: _textController,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _QuickReplies extends StatelessWidget {
  final void Function(String) onReply;

  const _QuickReplies({required this.onReply});

  static const _replies = [
    AppStrings.quickReplyGotIt,
    AppStrings.quickReplyTalkAt6,
    AppStrings.quickReplySharePlan,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _replies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(
            _replies[i],
            style: const TextStyle(fontSize: 13),
          ),
          onPressed: () => onReply(_replies[i]),
          backgroundColor: AppColors.surfaceVariant,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSend;

  const _MessageInput({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        8,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Message...',
                filled: true,
                fillColor: AppColors.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () => onSend(controller.text),
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
