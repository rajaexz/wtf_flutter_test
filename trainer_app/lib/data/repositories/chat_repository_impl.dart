import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/services/chat_socket_service.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/local_storage.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._storage, {ChatSocketService? socket})
      : _socket = socket ?? ChatSocketService();

  final LocalStorage _storage;
  final ChatSocketService _socket;

  static const _tokenServerUrl = String.fromEnvironment(
    'TOKEN_SERVER_URL',
    defaultValue: 'http://192.168.1.2:3000',
  );

  final Map<String, StreamController<List<MessageEntity>>> _controllers = {};
  final Map<String, StreamController<bool>> _typingControllers = {};
  final Map<String, StreamController<bool>> _presenceControllers = {};
  final Map<String, bool> _typingState = {};
  StreamSubscription<MessageEntity>? _msgSub;
  StreamSubscription<ReadEvent>? _readSub;
  StreamSubscription<TypingEvent>? _typingSub;
  StreamSubscription<PresenceEvent>? _presenceSub;
  bool _listenersBound = false;

  void _ensureSocketListeners() {
    if (_listenersBound) return;
    _listenersBound = true;

    _msgSub = _socket.onMessage.listen((remote) async {
      await _upsertLocal(remote);
      _emit(remote.chatId);
    });

    _readSub = _socket.onRead.listen((event) async {
      final messages = _getMessagesSync(event.chatId);
      var changed = false;
      for (final m in messages) {
        if (m.receiverId == event.userId && m.status != MessageStatus.read) {
          await _storage.put(
            _storage.messages,
            m.id,
            m.copyWith(status: MessageStatus.read).toJson(),
          );
          changed = true;
        }
      }
      if (changed) _emit(event.chatId);
    });

    _typingSub = _socket.onTyping.listen((event) {
      final key = '${event.chatId}|${event.userId}';
      _typingState[key] = event.isTyping;
      final c = _typingControllers[key];
      if (c != null && !c.isClosed) c.add(event.isTyping);
    });

    _presenceSub = _socket.onPresence.listen((event) {
      final c = _presenceControllers[event.userId];
      if (c != null && !c.isClosed) c.add(event.online);
    });
  }

  StreamController<List<MessageEntity>> _controllerFor(String chatId) {
    return _controllers.putIfAbsent(
      chatId,
      () => StreamController<List<MessageEntity>>.broadcast(
        onListen: () {
          _socket.joinChat(chatId);
          _syncFromServer(chatId);
        },
        onCancel: () {
          Future.delayed(const Duration(seconds: 2), () {
            final c = _controllers[chatId];
            if (c != null && !c.hasListener) {
              _socket.leaveChat(chatId);
            }
          });
        },
      ),
    );
  }

  @override
  Future<void> connect(String userId) async {
    _ensureSocketListeners();
    await _socket.connect(userId);
    logger.chat('[CHAT] socket connect requested for $userId');
  }

  @override
  Future<void> disconnect() async {
    await _msgSub?.cancel();
    await _readSub?.cancel();
    await _typingSub?.cancel();
    await _presenceSub?.cancel();
    _msgSub = null;
    _readSub = null;
    _typingSub = null;
    _presenceSub = null;
    _listenersBound = false;
    await _socket.disconnect();
  }

  @override
  Stream<List<MessageEntity>> watchMessages(String chatId) {
    final controller = _controllerFor(chatId);
    Future.microtask(() {
      _emit(chatId);
      _syncFromServer(chatId);
      _socket.joinChat(chatId);
    });
    return controller.stream;
  }

  void _emit(String chatId) {
    final messages = _getMessagesSync(chatId);
    final c = _controllers[chatId];
    if (c != null && !c.isClosed) {
      c.add(messages);
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

  Future<void> _upsertLocal(MessageEntity message) async {
    final local = _storage.get(_storage.messages, message.id);
    if (local == null ||
        local['status'] != message.status.name ||
        local['text'] != message.text) {
      await _storage.put(_storage.messages, message.id, message.toJson());
    }
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

    MessageEntity? acked;
    try {
      acked = await _socket.sendMessage(sending.copyWith(status: MessageStatus.sent));
    } catch (e) {
      logger.chat('[CHAT] socket send failed: $e');
    }

    if (acked != null) {
      await _storage.put(_storage.messages, acked.id, acked.toJson());
      _emit(acked.chatId);
      logger.chat('[CHAT] sent via socket: ${acked.text}');
      return;
    }

    // HTTP fallback when socket is down
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
      logger.chat('[CHAT] sent via HTTP fallback: ${sent.text}');
    } catch (e) {
      final failed = message.copyWith(status: MessageStatus.failed);
      await _storage.put(_storage.messages, failed.id, failed.toJson());
      logger.chat('[CHAT] send failed: $e');
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

    final ok = await _socket.markRead(chatId, currentUserId);
    if (ok) return;

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

  @override
  void setTyping({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) {
    _socket.setTyping(chatId: chatId, userId: userId, isTyping: isTyping);
  }

  @override
  Stream<bool> watchPeerTyping(String chatId, String peerUserId) {
    final key = '$chatId|$peerUserId';
    final controller = _typingControllers.putIfAbsent(
      key,
      () => StreamController<bool>.broadcast(
        onListen: () {
          final c = _typingControllers[key];
          if (c != null && !c.isClosed) {
            c.add(_typingState[key] ?? false);
          }
        },
      ),
    );
    return controller.stream;
  }

  @override
  Stream<bool> watchPeerOnline(String userId) {
    final controller = _presenceControllers.putIfAbsent(
      userId,
      () => StreamController<bool>.broadcast(
        onListen: () {
          final c = _presenceControllers[userId];
          if (c != null && !c.isClosed) {
            c.add(_socket.isOnline(userId));
          }
          _socket.queryPresence([userId]);
        },
      ),
    );
    return controller.stream;
  }

  @override
  bool isPeerOnline(String userId) => _socket.isOnline(userId);
}
