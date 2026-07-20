import 'package:dalali/models/chat_models.dart';
import 'package:dalali/services/supabase_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// CHAT SERVICE
/// ═══════════════════════════════════════════════════════════════
///
/// Realtime chat access (migration 017). Streams follow the
/// `.stream(primaryKey:)` convention used across the app.
/// Unread counters and last-message previews are maintained
/// server-side by trigger; read-marking goes through the
/// mark_conversation_read RPC.
///
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  static final _db = SupabaseService.client;

  /// All conversations the user participates in, newest activity first.
  /// RLS scopes the stream to the caller's rows; the where() filter
  /// shapes it for this user (admins can read all rows via RLS but
  /// should only see their own threads in the inbox).
  Stream<List<ConversationModel>> watchConversations(String userId) {
    return _db
        .from('conversations')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .map((rows) => rows
            .map(ConversationModel.fromJson)
            .where((c) => c.participantA == userId || c.participantB == userId)
            .toList());
  }

  /// Total unread message count across the user's conversations.
  Stream<int> watchTotalUnread(String userId) {
    return watchConversations(userId).map(
      (list) => list.fold<int>(0, (sum, c) => sum + c.unreadFor(userId)),
    );
  }

  /// Messages of one conversation, oldest first.
  Stream<List<ChatMessageModel>> watchMessages(String conversationId) {
    return _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(ChatMessageModel.fromJson).toList());
  }

  /// Find the existing thread between two users (either direction)
  /// or create it. The LEAST/GREATEST unique index protects against
  /// concurrent creation races.
  Future<ConversationModel> findOrCreateConversation({
    required String myId,
    required String myName,
    required String otherId,
    required String otherName,
    String? propertyId,
    String? propertyTitle,
  }) async {
    final existing = await _db
        .from('conversations')
        .select()
        .or('and(participant_a.eq.$myId,participant_b.eq.$otherId),'
            'and(participant_a.eq.$otherId,participant_b.eq.$myId)')
        .limit(1);
    if ((existing as List).isNotEmpty) {
      return ConversationModel.fromJson(existing.first);
    }

    try {
      final inserted = await _db
          .from('conversations')
          .insert({
            'participant_a': myId,
            'participant_b': otherId,
            'participant_a_name': myName,
            'participant_b_name': otherName,
            'property_id': propertyId,
            'property_title': propertyTitle,
          })
          .select()
          .single();
      return ConversationModel.fromJson(inserted);
    } catch (_) {
      // Lost a creation race — the other side created it first.
      final retry = await _db
          .from('conversations')
          .select()
          .or('and(participant_a.eq.$myId,participant_b.eq.$otherId),'
              'and(participant_a.eq.$otherId,participant_b.eq.$myId)')
          .limit(1);
      return ConversationModel.fromJson((retry as List).first);
    }
  }

  /// Send a message. The DB generates the id and the
  /// handle_new_chat_message trigger updates counters/preview and
  /// notifies the recipient.
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String body,
  }) async {
    await _db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'body': body.trim(),
    });
  }

  /// Mark all incoming messages read and zero the caller's counter.
  Future<void> markRead(String conversationId) async {
    await _db.rpc('mark_conversation_read', params: {'p_conversation_id': conversationId});
  }
}
