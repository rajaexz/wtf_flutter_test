import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/message_entity.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

final isTypingProvider = StreamProvider.family<bool, String>((ref, chatId) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final peerId = user?.assignedTrainerId;
  if (user == null || peerId == null || peerId.isEmpty) {
    return Stream.value(false);
  }
  return ref.read(chatRepositoryProvider).watchPeerTyping(chatId, peerId);
});

final peerOnlineProvider = StreamProvider.family<bool, String>((ref, peerUserId) {
  return ref.read(chatRepositoryProvider).watchPeerOnline(peerUserId);
});

final messagesProvider =
    StreamNotifierProviderFamily<MessagesNotifier, List<MessageEntity>, String>(
  MessagesNotifier.new,
);

class MessagesNotifier extends FamilyStreamNotifier<List<MessageEntity>, String> {
  Timer? _typingStopTimer;
  bool _typingActive = false;

  @override
  Stream<List<MessageEntity>> build(String arg) {
    ref.onDispose(() {
      _typingStopTimer?.cancel();
      _stopTyping();
    });
    return ref.read(chatRepositoryProvider).watchMessages(arg);
  }

  Future<void> send(String text) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final chatId = arg;
    final trainerId = user.assignedTrainerId ?? '';
    if (trainerId.isEmpty) return;

    _stopTyping();

    final message = MessageEntity(
      id: const Uuid().v4(),
      chatId: chatId,
      senderId: user.id,
      receiverId: trainerId,
      text: text,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );

    await ref.read(chatRepositoryProvider).sendMessage(message);
  }

  void onComposerChanged(String text) {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    if (text.trim().isEmpty) {
      _stopTyping();
      return;
    }

    if (!_typingActive) {
      _typingActive = true;
      ref.read(chatRepositoryProvider).setTyping(
            chatId: arg,
            userId: user.id,
            isTyping: true,
          );
    }

    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(milliseconds: 1500), _stopTyping);
  }

  void _stopTyping() {
    _typingStopTimer?.cancel();
    _typingStopTimer = null;
    if (!_typingActive) return;
    _typingActive = false;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    ref.read(chatRepositoryProvider).setTyping(
          chatId: arg,
          userId: user.id,
          isTyping: false,
        );
  }

  Future<void> markRead() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    await ref.read(chatRepositoryProvider).markAsRead(arg, user.id);
  }
}

final unreadCountProvider = Provider.family<int, String>((ref, chatId) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return 0;
  final messages = ref.watch(messagesProvider(chatId)).valueOrNull ?? [];
  return messages
      .where((m) => m.receiverId == user.id && m.status != MessageStatus.read)
      .length;
});
