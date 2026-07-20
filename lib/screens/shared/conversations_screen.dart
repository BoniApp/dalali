import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/chat_models.dart';
import 'package:dalali/services/chat_service.dart';
import 'package:dalali/screens/shared/chat_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// CONVERSATIONS SCREEN
/// ═══════════════════════════════════════════════════════════════
///
/// WhatsApp-style chat list: other party, property context, last
/// message preview, relative time and an unread-count pill.
/// Realtime via ChatService.watchConversations.
///
class ConversationsScreen extends StatelessWidget {
  final String userId;

  const ConversationsScreen({super.key, required this.userId});

  String _timeLabel(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return '${two(local.hour)}:${two(local.minute)}';
    }
    return '${two(local.day)}/${two(local.month)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.messages),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<ConversationModel>>(
        stream: ChatService().watchConversations(userId),
        builder: (context, snapshot) {
          final conversations = snapshot.data ?? [];
          if (conversations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 72, color: AppTheme.primary.withAlpha(51)),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noConversationsYet,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final c = conversations[index];
              final unread = c.unreadFor(userId);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary.withAlpha(26),
                  child: Text(
                    c.otherParticipantNameFor(userId)[0].toUpperCase(),
                    style: TextStyle(
                        color: AppTheme.primaryDark, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  c.otherParticipantNameFor(userId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal),
                ),
                subtitle: Text(
                  c.propertyTitle != null && c.propertyTitle!.isNotEmpty
                      ? '${c.propertyTitle} · ${c.lastMessageText ?? ''}'
                      : (c.lastMessageText ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _timeLabel(c.lastMessageAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 4),
                    if (unread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(conversation: c, myId: userId),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
