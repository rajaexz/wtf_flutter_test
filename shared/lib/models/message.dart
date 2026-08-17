enum MessageStatus { sending, sent, read }

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime createdAt;
  final MessageStatus status;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.createdAt,
    required this.status,
  });
}
