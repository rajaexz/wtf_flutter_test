import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/app_logger.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/local_storage.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._storage);

  final LocalStorage _storage;

  static const _tokenServerUrl = String.fromEnvironment(
    'TOKEN_SERVER_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  final Map<String, StreamController<List<MessageEntity>>> _controllers = {};
  final Map<String, Timer> _pollers = {};

  StreamController<List<MessageEntity>> _controllerFor(String chatId) {
    return _controllers.putIfAbsent(
      chatId,
      () => StreamController<List<MessageEntity>>.broadcast(
        onListen: () => _startPolling(chatId),
        onCancel: () {
          Future.delayed(const Duration(seconds: 2), () {
            final c = _controllers[chatId];
            if (c != null && !c.hasListener) {
              _stopPolling(chatId);
            }
          });
        },
      ),
    );
  }

  void _startPolling(String chatId) {
    _pollers[chatId]?.cancel();
    _syncFromServer(chatId);
    _pollers[chatId] = Timer.periodic(const Duration(seconds: 2), (_) {
      _syncFromServer(chatId);
    });
  }

  void _stopPolling(String chatId) {
    _pollers.remove(chatId)?.cancel();
  }

  @override
  Stream<List<MessageEntity>> watchMessages(String chatId) {
    final controller = _controllerFor(chatId);
    Future.microtask(() {
      _emit(chatId);
      _syncFromServer(chatId);
    });
    return controller.stream;
  }

  void _emit(String chatId) {
    final messages = _getMessagesSync(chatId);
    if (!_controllerFor(chatId).isClosed) {
      _controllerFor(chatId).add(messages);
    }
  }

  List<MessageEntity> _getMessagesSync(String chatId) {
    return _storage
        .getAll(_storage.messages)
        .where((m) => m['chatId'] == chatId)
        .map(MessageEntity.fromJson)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> _syncFromServer(String chatId) async {
    try {
      final uri = Uri.parse('$_tokenServerUrl/chat/messages?chatId=$chatId');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['messages'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      var changed = false;
      for (final raw in list) {
        final remote = MessageEntity.fromJson(raw);
        final local = _storage.get(_storage.messages, remote.id);
        if (local == null ||
            local['status'] != remote.status.name ||
            local['text'] != remote.text) {
          await _storage.put(_storage.messages, remote.id, remote.toJson());
          changed = true;
        }
      }
      if (changed) {
        logger.chat('[CHAT] synced ${list.length} msgs for $chatId');
        _emit(chatId);
      }
    } catch (e) {
      logger.chat('[CHAT] sync failed: $e');
    }
  }

  @override
  Future<List<MessageEntity>> getMessages(String chatId) async {
    await _syncFromServer(chatId);
    return _getMessagesSync(chatId);
  }

  @override
  Future<void> sendMessage(MessageEntity message) async {
    final sending = message.copyWith(status: MessageStatus.sending);
    await _storage.put(_storage.messages, sending.id, sending.toJson());
    _emit(sending.chatId);

    final sent = message.copyWith(status: MessageStatus.sent);
    try {
      final res = await http
          .post(
            Uri.parse('$_tokenServerUrl/chat/messages'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(sent.toJson()),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        throw Exception('chat post ${res.statusCode}');
      }
      await _storage.put(_storage.messages, sent.id, sent.toJson());
      logger.chat('[CHAT] sent to server: ${sent.text}');
    } catch (e) {
      await _storage.put(_storage.messages, sent.id, sent.toJson());
      logger.chat('[CHAT] server post failed, kept local: $e');
    }
    _emit(sent.chatId);
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

    try {
      await http
          .post(
            Uri.parse('$_tokenServerUrl/chat/read'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'chatId': chatId, 'userId': currentUserId}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  @override
  int getUnreadCount(String chatId, String currentUserId) {
    return _getMessagesSync(chatId)
        .where((m) => m.receiverId == currentUserId && m.status != MessageStatus.read)
        .length;
  }
}
