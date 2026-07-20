import 'package:flutter_test/flutter_test.dart';
import 'package:dalali/models/chat_models.dart';

void main() {
  final conversationJson = {
    'id': 'conv1',
    'participant_a': 'user-a',
    'participant_b': 'user-b',
    'participant_a_name': 'Amina',
    'participant_b_name': 'Juma',
    'property_id': 'prop1',
    'property_title': '2BR Apartment, Kariakoo',
    'last_message_text': 'Habari, is it still available?',
    'last_message_at': '2026-07-20T10:00:00.000Z',
    'unread_a': 2,
    'unread_b': 0,
    'created_at': '2026-07-19T09:00:00.000Z',
  };

  group('ConversationModel', () {
    test('fromJson parses all fields', () {
      final c = ConversationModel.fromJson(conversationJson);
      expect(c.id, 'conv1');
      expect(c.participantA, 'user-a');
      expect(c.participantB, 'user-b');
      expect(c.participantAName, 'Amina');
      expect(c.participantBName, 'Juma');
      expect(c.propertyId, 'prop1');
      expect(c.propertyTitle, '2BR Apartment, Kariakoo');
      expect(c.lastMessageText, isNotEmpty);
      expect(c.lastMessageAt, isNotNull);
      expect(c.unreadA, 2);
      expect(c.unreadB, 0);
    });

    test('otherParticipantFor returns the other side for both directions', () {
      final c = ConversationModel.fromJson(conversationJson);
      expect(c.otherParticipantIdFor('user-a'), 'user-b');
      expect(c.otherParticipantIdFor('user-b'), 'user-a');
      expect(c.otherParticipantNameFor('user-a'), 'Juma');
      expect(c.otherParticipantNameFor('user-b'), 'Amina');
    });

    test('unreadFor picks the correct per-participant counter', () {
      final c = ConversationModel.fromJson(conversationJson);
      expect(c.unreadFor('user-a'), 2);
      expect(c.unreadFor('user-b'), 0);
    });

    test('empty denormalized name falls back to User', () {
      final c = ConversationModel.fromJson({
        ...conversationJson,
        'participant_b_name': '',
      });
      expect(c.otherParticipantNameFor('user-a'), 'User');
    });
  });

  group('ChatMessageModel', () {
    test('fromJson/toJson round-trip', () {
      final m = ChatMessageModel.fromJson({
        'id': 'msg1',
        'conversation_id': 'conv1',
        'sender_id': 'user-a',
        'body': 'Nipo!',
        'is_read': true,
        'created_at': '2026-07-20T10:00:00.000Z',
      });
      expect(m.id, 'msg1');
      expect(m.conversationId, 'conv1');
      expect(m.senderId, 'user-a');
      expect(m.body, 'Nipo!');
      expect(m.isRead, isTrue);

      final json = m.toJson();
      expect(json['conversation_id'], 'conv1');
      expect(json['sender_id'], 'user-a');
      expect(json['body'], 'Nipo!');
      // id is DB-generated — never sent on insert.
      expect(json.containsKey('id'), isFalse);
    });
  });
}
