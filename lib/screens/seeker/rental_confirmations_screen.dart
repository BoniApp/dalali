import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/rental_confirmation_model.dart';
import 'package:dalali/providers/user_state.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:provider/provider.dart';

/// Seeker side of the "mark as rented" flow (migration 030): lists
/// open marks — "a landlord/agent says you rented their listing" —
/// for the seeker to confirm (the listing drops to 'occupied' and a
/// tenancy is created server-side) or dispute (listing stays live).
class RentalConfirmationsScreen extends StatelessWidget {
  const RentalConfirmationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userId = context.watch<UserState>().currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rentalConfirmationsTitle),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: userId == null
          ? Center(child: Text(l10n.notLoggedIn))
          : StreamBuilder<List<RentalConfirmationModel>>(
              stream: DataService().watchPendingRentalConfirmations(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined, size: 56, color: Colors.grey[400]),
                        const SizedBox(height: AppTheme.spacingXs),
                        Text(l10n.noPendingRentalConfirmations),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _ConfirmationCard(confirmation: items[index]),
                );
              },
            ),
    );
  }
}

class _ConfirmationCard extends StatefulWidget {
  final RentalConfirmationModel confirmation;
  const _ConfirmationCard({required this.confirmation});

  @override
  State<_ConfirmationCard> createState() => _ConfirmationCardState();
}

class _ConfirmationCardState extends State<_ConfirmationCard> {
  bool _busy = false;

  Future<void> _respond(bool confirm) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await DataService().respondRentalConfirmation(widget.confirmation.id, confirm);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(confirm ? l10n.rentalConfirmedSnack : l10n.rentalDisputedSnack)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    }
  }

  Future<void> _dispute() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.disputeRentalTitle),
        content: Text(l10n.disputeRentalBody(widget.confirmation.markedByName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.notMe)),
        ],
      ),
    );
    if (confirmed == true) _respond(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = widget.confirmation;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.propertyTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              l10n.markedByLine(c.markedByName, c.markedByRole),
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              Helpers.formatDateOnly(c.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : () => _respond(true),
                    icon: const Icon(Icons.check),
                    label: Text(l10n.confirmIRented),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingXs),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _dispute,
                    child: Text(l10n.notMe, style: const TextStyle(color: Colors.red)),
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
