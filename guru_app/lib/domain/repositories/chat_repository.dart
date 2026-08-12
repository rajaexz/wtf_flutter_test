import '../entities/message_entity.dart';

abstract class ChatRepository {
  Stream<List<MessageEntity>> watchMessages(String chatId);
  Future<List<MessageEntity>> getMessages(String chatId);
  Future<void> sendMessage(MessageEntity message);
  Future<void> markAsRead(String chatId, String currentUserId);
  int getUnreadCount(String chatId, String currentUserId);
}
