import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/providers/app_state.dart';
// import 'package:dalali/models/inquiry_model.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class InquiriesScreen extends StatelessWidget {
  const InquiriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inquiries = context.watch<AppState>().landlordInquiries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inquiries'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: inquiries.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No inquiries yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: inquiries.length,
              itemBuilder: (context, index) {
                final i = inquiries[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(i.propertyTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                            if (!i.isRead)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(i.message, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(i.seekerName, style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(width: 16),
                            const Icon(Icons.access_time, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(Helpers.formatDate(i.createdAt), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _call(i.seekerPhone),
                                icon: const Icon(Icons.phone, size: 18),
                                label: const Text('Call'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _sms(i.seekerPhone),
                                icon: const Icon(Icons.message, size: 18),
                                label: const Text('SMS'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => context.read<AppState>().markInquiryRead(i.id),
                                icon: const Icon(Icons.done, size: 18),
                                label: const Text('Mark Read'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sms(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
