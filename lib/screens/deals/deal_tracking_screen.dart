import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/models/deal_model.dart';
import 'package:dalali/services/deal_service.dart';

class DealTrackingScreen extends StatelessWidget {
  const DealTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final deals = appState.myDeals;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dealTracking),
      ),
      body: deals.isEmpty
          ? Center(
              child: Text('No deals yet'),
            )
          : ListView.builder(
              itemCount: deals.length,
              itemBuilder: (context, index) {
                final deal = deals[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Chip(
                              label: Text(
                                deal.status.name,
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: _statusColor(deal.status).withAlpha(40),
                            ),
                            const Spacer(),
                            Text(
                              '#${deal.dealId.substring(0, deal.dealId.length > 8 ? 8 : deal.dealId.length)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Property: ${deal.propertyId}'),
                        const SizedBox(height: 12),
                        _DualConfirmation(
                          deal: deal,
                          onTenantConfirm: () => DealService().confirmTenant(deal.dealId),
                          onLandlordConfirm: () => DealService().confirmLandlord(deal.dealId),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _statusColor(DealStatus status) {
    switch (status) {
      case DealStatus.matched:
        return Colors.blue;
      case DealStatus.viewingScheduled:
        return Colors.indigo;
      case DealStatus.viewingCompleted:
        return Colors.purple;
      case DealStatus.negotiating:
        return Colors.orange;
      case DealStatus.tenancyConfirmed:
        return Colors.green;
      case DealStatus.agencyFeePending:
        return Colors.amber;
      case DealStatus.agencyFeePaid:
        return Colors.teal;
      case DealStatus.closed:
        return Colors.grey;
    }
  }
}

class _DualConfirmation extends StatelessWidget {
  final DealModel deal;
  final VoidCallback onTenantConfirm;
  final VoidCallback onLandlordConfirm;

  const _DualConfirmation({
    required this.deal,
    required this.onTenantConfirm,
    required this.onLandlordConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: deal.tenantConfirmed,
          onChanged: deal.tenantConfirmed
              ? null
              : (_) => onTenantConfirm(),
          title: Text(l10n.tenantConfirmation),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: deal.landlordConfirmed,
          onChanged: deal.landlordConfirmed
              ? null
              : (_) => onLandlordConfirm(),
          title: Text(l10n.landlordConfirmation),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (deal.isTenancyConfirmed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Chip(
              avatar: const Icon(Icons.verified, size: 16, color: Colors.white),
              label: Text(l10n.tenancyConfirmed),
              backgroundColor: Colors.green,
              labelStyle: const TextStyle(color: Colors.white),
            ),
          ),
      ],
    );
  }
}
