import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/inquiry_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inquiries = context.watch<AppState>().inquiries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: inquiries.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.message_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No messages yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: inquiries.length,
              itemBuilder: (context, index) {
                final i = inquiries[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withAlpha(26),
                    child: const Icon(Icons.person, color: AppTheme.primary),
                  ),
                  title: Text(i.seekerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(i.message, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    Helpers.formatDateOnly(i.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  onTap: () => _showMessageDetail(context, i),
                );
              },
            ),
    );
  }

  void _showMessageDetail(BuildContext context, InquiryModel inquiry) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(inquiry.seekerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Re: ${inquiry.propertyTitle}', style: TextStyle(color: AppTheme.primary)),
            const SizedBox(height: 8),
            Text(Helpers.formatDate(inquiry.createdAt), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const Divider(),
            Text(inquiry.message, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse('tel:${inquiry.seekerPhone}');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse('sms:${inquiry.seekerPhone}');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    icon: const Icon(Icons.message),
                    label: const Text('Reply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
