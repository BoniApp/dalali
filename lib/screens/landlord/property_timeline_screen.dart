import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/services/data_service.dart';

/// Chronological view of a single property's lifecycle — listed,
/// tenant selected, tenancy started, notice/renewal, inspection,
/// relisted — assembled from already-persisted rows by
/// DataService.getPropertyTimeline (no dedicated DB view).
class PropertyTimelineScreen extends StatelessWidget {
  final String propertyId;
  final String propertyTitle;

  const PropertyTimelineScreen({super.key, required this.propertyId, required this.propertyTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Timeline · $propertyTitle'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DataService().getPropertyTimeline(propertyId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load timeline: ${snapshot.error}'));
          }
          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return Center(
              child: Text('No history yet.', style: TextStyle(color: Colors.grey[600])),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return _TimelineTile(
                date: event['date'] as DateTime,
                title: event['title'] as String,
                subtitle: (event['subtitle'] as String?) ?? '',
                isFirst: index == 0,
                isLast: index == events.length - 1,
              );
            },
          );
        },
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final DateTime date;
  final String title;
  final String subtitle;
  final bool isFirst;
  final bool isLast;

  const _TimelineTile({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.isFirst,
    required this.isLast,
  });

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '${_months[date.month - 1]} ${date.year}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppTheme.primary.withAlpha(60)),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
