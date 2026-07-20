import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/config/supabase_config.dart';
import 'package:dalali/services/supabase_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// BROADCAST ADMIN SCREEN
/// ═══════════════════════════════════════════════════════════════
///
/// Compose a message and send it to all users (or one role) via
/// the admin-broadcast edge function. Each recipient gets the
/// message as a chat conversation with the admin, plus a
/// notification (created by the new-message trigger).
///
class BroadcastAdminScreen extends StatefulWidget {
  final String adminId;

  const BroadcastAdminScreen({super.key, required this.adminId});

  @override
  State<BroadcastAdminScreen> createState() => _BroadcastAdminScreenState();
}

class _BroadcastAdminScreenState extends State<BroadcastAdminScreen> {
  final _messageController = TextEditingController();
  String _target = 'all';
  bool _sending = false;
  String? _result;

  static const _targets = {
    'all': 'All users',
    'seeker': 'Seekers',
    'landlord': 'Landlords',
    'agent': 'Agents',
    'influencer': 'Influencers',
  };

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send broadcast?'),
        content: Text(
          'This will send the message to ${_targets[_target]} as a chat message. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _result = null;
    });

    try {
      final token = SupabaseService.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final functionsHost =
          SupabaseConfig.url.replaceFirst('.supabase.co', '.functions.supabase.co');
      final resp = await http.post(
        Uri.parse('$functionsHost/admin-broadcast'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': message,
          'target': _target,
          'admin_user_id': widget.adminId,
        }),
      );

      final respBody = json.decode(resp.body);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(respBody is Map && respBody['error'] != null
            ? respBody['error'].toString()
            : 'HTTP ${resp.statusCode}');
      }

      setState(() {
        _result = 'Sent to ${respBody['sent']} of ${respBody['recipients']} users.';
        _messageController.clear();
      });
    } catch (e) {
      setState(() => _result = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast Message'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: AppTheme.primary.withAlpha(13),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'The message is delivered as a chat conversation from you to each user, and triggers a notification. Users can reply in the chat — replies appear in the Messages section.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _target,
              decoration: const InputDecoration(
                labelText: 'Audience',
                border: OutlineInputBorder(),
              ),
              items: _targets.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _target = v ?? 'all'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              minLines: 4,
              maxLines: 8,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'e.g. Scheduled maintenance this Sunday 02:00–04:00 EAT...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.campaign),
              label: Text(_sending ? 'Sending...' : 'Send Broadcast'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              Card(
                color: _result!.startsWith('Failed')
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_result!, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
