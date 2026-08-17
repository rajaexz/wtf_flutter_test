import '../entities/message_entity.dart';

abstract class ChatRepository {
  Future<void> connect(String userId);
  Future<void> disconnect();

  Stream<List<MessageEntity>> watchMessages(String chatId);
  Future<List<MessageEntity>> getMessages(String chatId);
  Future<void> sendMessage(MessageEntity message);
  Future<void> markAsRead(String chatId, String currentUserId);
  int getUnreadCount(String chatId, String currentUserId);

  void setTyping({
    required String chatId,
    required String userId,
    required bool isTyping,
  });

  Stream<bool> watchPeerTyping(String chatId, String peerUserId);
  Stream<bool> watchPeerOnline(String userId);
  bool isPeerOnline(String userId);
}
