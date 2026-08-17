import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../utils/app_logger.dart';
import '../../domain/entities/message_entity.dart';

class TypingEvent {
  final String chatId;
  final String userId;
  final bool isTyping;

  const TypingEvent({
    required this.chatId,
    required this.userId,
    required this.isTyping,
  });
}

class PresenceEvent {
  final String userId;
  final bool online;

  const PresenceEvent({required this.userId, required this.online});
}

class ReadEvent {
  final String chatId;
  final String userId;

  const ReadEvent({required this.chatId, required this.userId});
}

/// Realtime chat transport over Socket.IO (token_server).
class ChatSocketService {
  ChatSocketService({String? serverUrl})
      : _serverUrl = serverUrl ??
            const String.fromEnvironment(
              'TOKEN_SERVER_URL',
              defaultValue: 'http://192.168.1.2:3000',
            );

  final String _serverUrl;
  io.Socket? _socket;
  String? _userId;

  final _messageController = StreamController<MessageEntity>.broadcast();
  final _typingController = StreamController<TypingEvent>.broadcast();
  final _presenceController = StreamController<PresenceEvent>.broadcast();
  final _readController = StreamController<ReadEvent>.broadcast();
  final _online = <String, bool>{};
  final _joinedChats = <String>{};

  Stream<MessageEntity> get onMessage => _messageController.stream;
  Stream<TypingEvent> get onTyping => _typingController.stream;
  Stream<PresenceEvent> get onPresence => _presenceController.stream;
  Stream<ReadEvent> get onRead => _readController.stream;

  bool get isConnected => _socket?.connected == true;

  bool isOnline(String userId) => _online[userId] == true;

  Future<void> connect(String userId) async {
    if (_socket != null && _userId == userId && isConnected) return;

    await disconnect();
    _userId = userId;

    final socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableForceNew()
          .setQuery({'userId': userId})
          .build(),
    );

    socket.onConnect((_) {
      logger.chat('[SOCKET] connected as $userId');
      for (final chatId in _joinedChats) {
        socket.emit('chat:join', {'chatId': chatId});
      }
    });

    socket.onDisconnect((_) => logger.chat('[SOCKET] disconnected'));
    socket.onConnectError((e) => logger.chat('[SOCKET] connect error: $e'));

    socket.on('message:new', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        _messageController.add(MessageEntity.fromJson(map));
      } catch (e) {
        logger.chat('[SOCKET] bad message:new: $e');
      }
    });

    socket.on('message:read', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        _readController.add(
          ReadEvent(
            chatId: map['chatId'] as String,
            userId: map['userId'] as String,
          ),
        );
      } catch (e) {
        logger.chat('[SOCKET] bad message:read: $e');
      }
    });

    socket.on('typing:start', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _typingController.add(
        TypingEvent(
          chatId: map['chatId'] as String,
          userId: map['userId'] as String,
          isTyping: true,
        ),
      );
    });

    socket.on('typing:stop', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _typingController.add(
        TypingEvent(
          chatId: map['chatId'] as String,
          userId: map['userId'] as String,
          isTyping: false,
        ),
      );
    });

    socket.on('presence:update', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final id = map['userId'] as String;
      final online = map['online'] == true;
      _online[id] = online;
      _presenceController.add(PresenceEvent(userId: id, online: online));
    });

    _socket = socket;
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    _userId = null;
    _joinedChats.clear();
    if (socket != null) {
      socket.clearListeners();
      socket.dispose();
    }
  }

  void joinChat(String chatId) {
    _joinedChats.add(chatId);
    if (isConnected) {
      _socket!.emit('chat:join', {'chatId': chatId});
    }
  }

  void leaveChat(String chatId) {
    _joinedChats.remove(chatId);
    if (isConnected) {
      _socket!.emit('chat:leave', {'chatId': chatId});
    }
  }

  Future<MessageEntity?> sendMessage(MessageEntity message) async {
    final socket = _socket;
    if (socket == null || !socket.connected) return null;

    final completer = Completer<MessageEntity?>();
    socket.emitWithAck('message:send', message.toJson(), ack: (dynamic response) {
      try {
        final map = Map<String, dynamic>.from(response as Map);
        if (map['ok'] == true && map['message'] != null) {
          completer.complete(
            MessageEntity.fromJson(Map<String, dynamic>.from(map['message'] as Map)),
          );
        } else {
          completer.complete(null);
        }
      } catch (_) {
        completer.complete(null);
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
  }

  Future<bool> markRead(String chatId, String userId) async {
    final socket = _socket;
    if (socket == null || !socket.connected) return false;

    final completer = Completer<bool>();
    socket.emitWithAck(
      'message:read',
      {'chatId': chatId, 'userId': userId},
      ack: (dynamic response) {
        try {
          final map = Map<String, dynamic>.from(response as Map);
          completer.complete(map['ok'] == true);
        } catch (_) {
          completer.complete(false);
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    );
  }

  void setTyping({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) {
    if (!isConnected) return;
    _socket!.emit(
      isTyping ? 'typing:start' : 'typing:stop',
      {'chatId': chatId, 'userId': userId},
    );
  }

  Future<void> queryPresence(List<String> userIds) async {
    final socket = _socket;
    if (socket == null || !socket.connected || userIds.isEmpty) return;

    socket.emitWithAck('presence:query', {'userIds': userIds}, ack: (dynamic response) {
      try {
        final map = Map<String, dynamic>.from(response as Map);
        final online = Map<String, dynamic>.from(map['online'] as Map? ?? {});
        for (final entry in online.entries) {
          final value = entry.value == true;
          _online[entry.key] = value;
          _presenceController.add(PresenceEvent(userId: entry.key, online: value));
        }
      } catch (_) {}
    });
  }
}
