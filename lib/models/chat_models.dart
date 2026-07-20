/// ═══════════════════════════════════════════════════════════════
/// CHAT MODELS
/// ═══════════════════════════════════════════════════════════════
///
/// Conversation + message models for the in-app chat (migration
/// 017). One conversation per user pair; participant names are
/// denormalized because users RLS only exposes a user's own row.
///
class ConversationModel {
  final String id;
  final String participantA;
  final String participantB;
  final String participantAName;
  final String participantBName;
  final String? propertyId;
  final String? propertyTitle;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadA;
  final int unreadB;
  final DateTime createdAt;

  const ConversationModel({
    required this.id,
    required this.participantA,
    required this.participantB,
    this.participantAName = '',
    this.participantBName = '',
    this.propertyId,
    this.propertyTitle,
    this.lastMessageText,
    this.lastMessageAt,
    this.unreadA = 0,
    this.unreadB = 0,
    required this.createdAt,
  });

  String otherParticipantIdFor(String myId) =>
      myId == participantA ? participantB : participantA;

  String otherParticipantNameFor(String myId) {
    final name = myId == participantA ? participantBName : participantAName;
    return name.isEmpty ? 'User' : name;
  }

  int unreadFor(String myId) => myId == participantA ? unreadA : unreadB;

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] ?? '',
      participantA: json['participant_a'] ?? '',
      participantB: json['participant_b'] ?? '',
      participantAName: json['participant_a_name'] ?? '',
      participantBName: json['participant_b_name'] ?? '',
      propertyId: json['property_id'],
      propertyTitle: json['property_title'],
      lastMessageText: json['last_message_text'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'])
          : null,
      unreadA: (json['unread_a'] as num?)?.toInt() ?? 0,
      unreadB: (json['unread_b'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'participant_a': participantA,
        'participant_b': participantB,
        'participant_a_name': participantAName,
        'participant_b_name': participantBName,
        'property_id': propertyId,
        'property_title': propertyTitle,
      };
}

class ChatMessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    this.isRead = false,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      body: json['body'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'body': body,
      };
}
