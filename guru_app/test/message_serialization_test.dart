import 'package:flutter_test/flutter_test.dart';
import 'package:guru_app/domain/entities/message_entity.dart';

void main() {
  group('MessageEntity serialization', () {
    final message = MessageEntity(
      id: 'msg_001',
      chatId: 'chat_abc',
      senderId: 'member_dk',
      receiverId: 'trainer_aarav',
      text: 'Hi Coach',
      createdAt: DateTime(2026, 8, 11, 10, 30),
      status: MessageStatus.sent,
    );

    test('toJson contains all fields', () {
      final json = message.toJson();

      expect(json['id'], 'msg_001');
      expect(json['chatId'], 'chat_abc');
      expect(json['senderId'], 'member_dk');
      expect(json['receiverId'], 'trainer_aarav');
      expect(json['text'], 'Hi Coach');
      expect(json['status'], 'sent');
    });

    test('fromJson round-trips correctly', () {
      final json = message.toJson();
      final restored = MessageEntity.fromJson(json);

      expect(restored.id, message.id);
      expect(restored.chatId, message.chatId);
      expect(restored.senderId, message.senderId);
      expect(restored.receiverId, message.receiverId);
      expect(restored.text, message.text);
      expect(restored.createdAt, message.createdAt);
      expect(restored.status, message.status);
    });

    test('copyWith changes only status', () {
      final updated = message.copyWith(status: MessageStatus.read);

      expect(updated.status, MessageStatus.read);
      expect(updated.id, message.id);
      expect(updated.text, message.text);
    });
  });
}
