import 'dart:async';
import 'dart:math';

import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/local_storage.dart';

class ChatRepositoryImpl implements ChatRepository {
  final LocalStorage _storage;

  ChatRepositoryImpl(this._storage);

  final Map<String, StreamController<List<MessageEntity>>> _controllers = {};

  StreamController<List<MessageEntity>> _controllerFor(String chatId) {
    return _controllers.putIfAbsent(
      chatId,
      () => StreamController<List<MessageEntity>>.broadcast(),
    );
  }

  @override
  Stream<List<MessageEntity>> watchMessages(String chatId) {
    final controller = _controllerFor(chatId);
    Future.microtask(() => _emit(chatId));
    return controller.stream;
  }

  void _emit(String chatId) {
    final messages = _getMessagesSync(chatId);
    _controllerFor(chatId).add(messages);
  }

  List<MessageEntity> _getMessagesSync(String chatId) {
    return _storage
        .getAll(_storage.messages)
        .where((m) => m['chatId'] == chatId)
        .map(MessageEntity.fromJson)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<List<MessageEntity>> getMessages(String chatId) async {
    return _getMessagesSync(chatId);
  }

  @override
  Future<void> sendMessage(MessageEntity message) async {
    await _storage.put(_storage.messages, message.id, message.toJson());
    _emit(message.chatId);

    final delay = 400 + Random().nextInt(400);
    await Future.delayed(Duration(milliseconds: delay));

    final read = message.copyWith(status: MessageStatus.read);
    await _storage.put(_storage.messages, read.id, read.toJson());
    _emit(read.chatId);
  }

  @override
  Future<void> markAsRead(String chatId, String currentUserId) async {
    final messages = _getMessagesSync(chatId);
    for (final m in messages) {
      if (m.receiverId == currentUserId && m.status != MessageStatus.read) {
        final updated = m.copyWith(status: MessageStatus.read);
        await _storage.put(_storage.messages, updated.id, updated.toJson());
      }
    }
    _emit(chatId);
  }

  @override
  int getUnreadCount(String chatId, String currentUserId) {
    return _getMessagesSync(chatId)
        .where((m) => m.receiverId == currentUserId && m.status != MessageStatus.read)
        .length;
  }
}
