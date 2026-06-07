import 'package:flutter/material.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:provider/provider.dart';

class MoveChecklistScreen extends StatelessWidget {
  final String tenancyId;
  const MoveChecklistScreen({super.key, required this.tenancyId});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final checklist = appState.getMyChecklist(tenancyId);

    if (checklist == null) {
      return const Center(child: Text('No checklist found for this move.'));
    }

    final progress = checklist.progress;

    return Column(
      children: [
        // Progress Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Move Progress',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: progress == 1 ? Colors.green : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(progress == 1 ? Colors.green : Colors.teal),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                '${checklist.completedCount} of ${checklist.totalCount} completed',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        // Checklist Items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: checklist.items.length,
            itemBuilder: (context, index) {
              final item = checklist.items[index];
              return CheckboxListTile(
                value: item.completed,
                onChanged: (_) => appState.toggleChecklistItem(checklist.id, item.id),
                title: Text(
                  item.title,
                  style: TextStyle(
                    decoration: item.completed ? TextDecoration.lineThrough : null,
                    color: item.completed ? Colors.grey : null,
                  ),
                ),
                secondary: Icon(
                  item.completed ? Icons.check_circle : Icons.circle_outlined,
                  color: item.completed ? Colors.green : Colors.grey[400],
                ),
                activeColor: Colors.teal,
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
      ],
    );
  }
}
