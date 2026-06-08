import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/providers/app_state.dart';

class AgencyFeeHistoryScreen extends StatelessWidget {
  const AgencyFeeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final entries = appState.myEarnings;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.agencyFeeHistory),
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(l10n.noEarningsYet),
            )
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final e = entries[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _colorForStatus(e.status).withAlpha(30),
                    child: Icon(
                      Icons.handshake,
                      color: _colorForStatus(e.status),
                    ),
                  ),
                  title: Text(e.propertyTitle ?? 'Property'),
                  subtitle: Text('${e.amount.toStringAsFixed(0)} ${e.currency}'),
                  trailing: Text(
                    e.status.name.toUpperCase(),
                    style: TextStyle(
                      color: _colorForStatus(e.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _colorForStatus(dynamic status) {
    switch (status.toString()) {
      case 'EarningsEntryStatus.available':
        return Colors.green;
      case 'EarningsEntryStatus.pending':
        return Colors.orange;
      case 'EarningsEntryStatus.withdrawn':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
