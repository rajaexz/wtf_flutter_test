import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/message_entity.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

final isTypingProvider = StateProvider.family<bool, String>((ref, chatId) => false);

final messagesProvider = StreamNotifierProviderFamily<MessagesNotifier, List<MessageEntity>, String>(
  MessagesNotifier.new,
);

class MessagesNotifier extends FamilyStreamNotifier<List<MessageEntity>, String> {
  @override
  Stream<List<MessageEntity>> build(String arg) {
    return ref.read(chatRepositoryProvider).watchMessages(arg);
  }

  Future<void> send(String text, String receiverId) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final chatId = arg;
    final message = MessageEntity(
      id: const Uuid().v4(),
      chatId: chatId,
      senderId: user.id,
      receiverId: receiverId,
      text: text,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );

    await ref.read(chatRepositoryProvider).sendMessage(message);

    ref.read(isTypingProvider(chatId).notifier).state = true;
    final delay = 400 + Random().nextInt(400);
    await Future.delayed(Duration(milliseconds: delay));
    ref.read(isTypingProvider(chatId).notifier).state = false;
  }

  Future<void> markRead() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    await ref.read(chatRepositoryProvider).markAsRead(arg, user.id);
  }
}

final unreadCountProvider = Provider.family<int, String>((ref, chatId) {
  final user = ref.read(currentUserProvider).valueOrNull;
  if (user == null) return 0;
  return ref.read(chatRepositoryProvider).getUnreadCount(chatId, user.id);
});
