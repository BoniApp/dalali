import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dalali/models/move_listing_model.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/screens/move/start_move_screen.dart';
import 'package:dalali/screens/shared/property_detail_screen.dart';
import 'package:dalali/services/matching_engine.dart';

class MoveDashboardScreen extends StatelessWidget {
  const MoveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final myMoves = appState.myMoveListings;
    final activeMove = myMoves.isNotEmpty ? myMoves.first : null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Move')),
      body: activeMove == null
          ? _EmptyMoveState(onStart: () => _goToStartMove(context))
          : _ActiveMoveBody(
              move: activeMove,
              appState: appState,
              theme: theme,
            ),
      floatingActionButton: activeMove == null
          ? FloatingActionButton.extended(
              onPressed: () => _goToStartMove(context),
              icon: const Icon(Icons.local_shipping),
              label: const Text('Start Move'),
            )
          : null,
    );
  }

  void _goToStartMove(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StartMoveScreen()),
    );
  }
}

class _EmptyMoveState extends StatelessWidget {
  final VoidCallback onStart;

  const _EmptyMoveState({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Not Moving Yet?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Start your move to list your current home and discover your next one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.add),
              label: const Text('Start a Move'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveMoveBody extends StatelessWidget {
  final MoveListingModel move;
  final AppState appState;
  final ThemeData theme;

  const _ActiveMoveBody({
    required this.move,
    required this.appState,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'sw_TZ', symbol: 'TZS ', decimalDigits: 0);
    final engine = MatchingEngine();
    final matches = engine.matchForMove(
      move: move,
      user: appState.currentUser,
      allProperties: appState.properties,
      favoritePropertyIds: appState.favorites
          .where((f) => f.userId == appState.currentUser?.id)
          .map((f) => f.propertyId)
          .toList(),
      maxResults: 5,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusCard(move: move, theme: theme),
        const SizedBox(height: 20),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Move Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _DetailRow(icon: Icons.home, label: 'From', value: move.currentPropertyTitle),
                _DetailRow(icon: Icons.location_on, label: 'Location', value: move.currentLocation),
                _DetailRow(
                  icon: Icons.calendar_today,
                  label: 'Move Date',
                  value: DateFormat('MMM d, yyyy').format(move.moveDate),
                ),
                if (move.budgetMin != null && move.budgetMax != null)
                  _DetailRow(
                    icon: Icons.account_balance_wallet,
                    label: 'Budget',
                    value: '${currency.format(move.budgetMin)} – ${currency.format(move.budgetMax)}',
                  ),
                if (move.preferredLocation != null)
                  _DetailRow(icon: Icons.map, label: 'Looking in', value: move.preferredLocation!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _confirmCancel(context),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            if (move.status == MoveStatus.planning)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => appState.activateMove(move.id),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Activate'),
                ),
              )
            else
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showCompleteDialog(context),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),

        if (matches.isNotEmpty) ...[
          Text(
            'Recommended for Your Move',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...matches.map((p) => _MatchCard(property: p)),
        ],
      ],
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Move?'),
        content: const Text('This will remove your move listing. You can start a new move anytime.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep')),
          ElevatedButton(
            onPressed: () {
              appState.cancelMove(move.id);
              Navigator.pop(ctx);
            },
            child: const Text('Cancel Move'),
          ),
        ],
      ),
    );
  }

  void _showCompleteDialog(BuildContext context) {
    final properties = appState.properties.where((p) => p.status == PropertyStatus.available).toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Your Move'),
        content: SizedBox(
          width: double.maxFinite,
          child: properties.isEmpty
              ? const Text('No available properties to select.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: properties.length,
                  itemBuilder: (_, i) {
                    final p = properties[i];
                    return ListTile(
                      title: Text(p.title),
                      subtitle: Text(p.location),
                      onTap: () {
                        appState.completeMove(move.id, p.id);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Move completed! Welcome to ${p.title}')),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final MoveListingModel move;
  final ThemeData theme;

  const _StatusCard({required this.move, required this.theme});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (move.status) {
      MoveStatus.planning => (Colors.orange, Icons.inventory_2_outlined, 'Planning'),
      MoveStatus.active => (Colors.blue, Icons.local_shipping, 'Active'),
      MoveStatus.completed => (Colors.green, Icons.check_circle, 'Completed'),
      MoveStatus.cancelled => (Colors.red, Icons.cancel, 'Cancelled'),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Move Status',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (move.status == MoveStatus.planning || move.status == MoveStatus.active)
                  Text(
                    'Moving on ${DateFormat('MMM d').format(move.moveDate)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text('$label:', style: TextStyle(color: Colors.grey[700])),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final PropertyModel property;

  const _MatchCard({required this.property});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'sw_TZ', symbol: 'TZS ', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: property.images.isNotEmpty
              ? Image.network(property.images.first, width: 56, height: 56, fit: BoxFit.cover)
              : Container(width: 56, height: 56, color: Colors.grey[300]),
        ),
        title: Text(property.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${property.location}\n${currency.format(property.rentPrice)}'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: property)),
          );
        },
      ),
    );
  }
}
