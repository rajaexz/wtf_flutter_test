import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../domain/entities/message_entity.dart';

class ChatBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  bool get _isMemberSender =>
      message.senderId.startsWith('member') || message.senderId == 'member_dk';

  @override
  Widget build(BuildContext context) {
    final color = _isMemberSender ? AppColors.memberBubble : AppColors.trainerBubble;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: EdgeInsets.only(
          left: isMe ? 48 : 16,
          right: isMe ? 16 : 48,
          bottom: 6,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.createdAt.chatTimestamp,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _StatusTick(status: message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTick extends StatelessWidget {
  final MessageStatus status;

  const _StatusTick({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      MessageStatus.sending =>
        const Icon(Icons.access_time, size: 12, color: Colors.white54),
      MessageStatus.sent => const Icon(Icons.done, size: 12, color: Colors.white70),
      MessageStatus.read => const Icon(Icons.done_all, size: 12, color: Colors.white),
      MessageStatus.failed =>
        const Icon(Icons.error_outline, size: 12, color: Colors.orangeAccent),
    };
  }
}
