import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/rental_confirmation_model.dart';
import 'package:dalali/services/data_service.dart';

/// "Mark as rented" sheet (migration 030): a landlord/agent picks the
/// seeker who rented their available listing on receipt of payment.
/// The listing stays in the feed until the seeker confirms in-app.
/// If an open mark already exists for the listing, the sheet instead
/// shows who it awaits and offers to cancel it.
class MarkRentedSheet extends StatefulWidget {
  final PropertyModel property;
  const MarkRentedSheet({super.key, required this.property});

  /// Opens the sheet; on success the sheet pops with the snackbar
  /// message, which is shown on the caller's context.
  static Future<void> show(BuildContext context, PropertyModel property) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MarkRentedSheet(property: property),
    );
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  State<MarkRentedSheet> createState() => _MarkRentedSheetState();
}

class _MarkRentedSheetState extends State<MarkRentedSheet> {
  final _data = DataService();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  RentalConfirmationModel? _pending;
  List<RentableSeeker> _seekers = [];
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pending = await _data.getPendingRentalConfirmation(widget.property.id);
      final seekers = pending == null
          ? await _data.listRentableSeekers(widget.property.id)
          : <RentableSeeker>[];
      if (!mounted) return;
      setState(() {
        _pending = pending;
        _seekers = seekers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _mark() async {
    final seekerId = _selectedId;
    if (seekerId == null || _busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _data.markListingRented(widget.property.id, seekerId);
      if (!mounted) return;
      Navigator.pop(context, l10n.markedAwaitingConfirmation);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.actionFailed;
      });
    }
  }

  Future<void> _cancelMark() async {
    final pending = _pending;
    if (pending == null || _busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _data.cancelRentalConfirmation(pending.id);
      if (!mounted) return;
      Navigator.pop(context, l10n.markCancelledSnack);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.actionFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppTheme.spacingSm,
          right: AppTheme.spacingSm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingSm,
        ),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(AppTheme.spacingLg),
                child: Center(child: CircularProgressIndicator()),
              )
            : _pending != null
                ? _buildPending(l10n, _pending!)
                : _buildPicker(l10n),
      ),
    );
  }

  Widget _buildPending(AppLocalizations l10n, RentalConfirmationModel pending) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.hourglass_top, size: 40, color: AppTheme.action),
        const SizedBox(height: AppTheme.spacingXs),
        Text(
          l10n.awaitingConfirmationFrom(pending.seekerName),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppTheme.spacingXs),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: AppTheme.spacingSm),
        OutlinedButton.icon(
          onPressed: _busy ? null : _cancelMark,
          icon: const Icon(Icons.close, color: Colors.red),
          label: Text(l10n.cancelMark, style: const TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildPicker(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.selectSeekerWhoRented,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTheme.spacingXs),
        if (_seekers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
            child: Text(l10n.noEligibleSeekers, textAlign: TextAlign.center),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _seekers.length,
              itemBuilder: (context, index) {
                final s = _seekers[index];
                final selected = s.userId == _selectedId;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, color: AppTheme.primary),
                  ),
                  title: Text(s.fullName.isEmpty ? s.phone : s.fullName),
                  subtitle: Row(
                    children: [
                      if (s.paid) _SourceChip(label: l10n.paidFeeChip, color: Colors.green),
                      if (s.applied) _SourceChip(label: l10n.appliedChip, color: Colors.blue),
                    ],
                  ),
                  trailing: selected ? const Icon(Icons.check_circle, color: AppTheme.primary) : null,
                  selected: selected,
                  onTap: _busy ? null : () => setState(() => _selectedId = s.userId),
                );
              },
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: AppTheme.spacingXs),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: AppTheme.spacingSm),
        ElevatedButton.icon(
          onPressed: (_selectedId == null || _busy) ? null : _mark,
          icon: const Icon(Icons.handshake),
          label: Text(l10n.markAsRented),
        ),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SourceChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
