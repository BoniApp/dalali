import 'package:flutter/material.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:dalali/utils/helpers.dart';

class ListingsAdminScreen extends StatelessWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const ListingsAdminScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Listings Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Moderate property listings', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: AdminService().getAllListings(limit: 100),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                  }
                  final listings = snapshot.data ?? [];
                  if (listings.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No listings found')));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Image')),
                        DataColumn(label: Text('Title')),
                        DataColumn(label: Text('Location')),
                        DataColumn(label: Text('Price')),
                        DataColumn(label: Text('Landlord')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Approved')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: listings.map((p) {
                        final images = List<String>.from(p['images'] ?? []);
                        final status = p['status'] ?? '';
                        final isApproved = p['is_approved'] == true;
                        final propertyId = p['id']?.toString() ?? '';
                        return DataRow(
                          cells: [
                            DataCell(
                              images.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(images.first, width: 50, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40)),
                                    )
                                  : const Icon(Icons.image, size: 40),
                            ),
                            DataCell(Text(p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(Text(p['location'] ?? '')),
                            DataCell(Text(Helpers.formatPrice((p['rent_price'] as num?)?.toDouble() ?? 0.0))),
                            DataCell(Text(p['landlord_name'] ?? '')),
                            DataCell(Chip(
                              label: Text(status, style: const TextStyle(fontSize: 10)),
                              backgroundColor: status == 'available' ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                              labelStyle: TextStyle(fontSize: 10, color: status == 'available' ? Colors.green : Colors.grey),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            )),
                            DataCell(
                              isApproved
                                  ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                  : const Icon(Icons.pending, color: Colors.orange, size: 20),
                            ),
                            DataCell(_ActionCell(
                              propertyId: propertyId,
                              isApproved: isApproved,
                              title: p['title'] ?? 'this property',
                              adminId: adminId,
                              adminName: adminName,
                              adminRole: adminRole,
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCell extends StatefulWidget {
  final String propertyId;
  final bool isApproved;
  final String title;
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const _ActionCell({
    required this.propertyId,
    required this.isApproved,
    required this.title,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  @override
  State<_ActionCell> createState() => _ActionCellState();
}

class _ActionCellState extends State<_ActionCell> {
  bool _isLoading = false;

  Future<void> _handleApprove() async {
    if (widget.propertyId.isEmpty) {
      _showError('Property ID is empty. Cannot approve.');
      return;
    }
    final confirmed = await _showConfirmDialog('Approve', 'Approve "${widget.title}"?');
    if (!confirmed) return;
    _setLoading(true);
    try {
      await AdminService().approveProperty(
        adminId: widget.adminId,
        adminName: widget.adminName,
        adminRole: widget.adminRole,
        propertyId: widget.propertyId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property approved')),
        );
      }
    } catch (e) {
      if (mounted) _showError('Approve failed: $e');
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _handleReject() async {
    if (widget.propertyId.isEmpty) {
      _showError('Property ID is empty. Cannot reject.');
      return;
    }
    final confirmed = await _showConfirmDialog('Reject', 'Reject "${widget.title}"?');
    if (!confirmed) return;
    _setLoading(true);
    try {
      await AdminService().rejectProperty(
        adminId: widget.adminId,
        adminName: widget.adminName,
        adminRole: widget.adminRole,
        propertyId: widget.propertyId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property rejected')),
        );
      }
    } catch (e) {
      if (mounted) _showError('Reject failed: $e');
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  void _setLoading(bool v) => setState(() => _isLoading = v);

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<bool> _showConfirmDialog(String action, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Property'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(width: 80, height: 36, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.isApproved)
          Tooltip(
            message: 'Approve',
            child: InkWell(
              onTap: _handleApprove,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.check_circle, color: Colors.green, size: 20),
              ),
            ),
          ),
        Tooltip(
          message: 'Reject',
          child: InkWell(
            onTap: _handleReject,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.block, color: Colors.red, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}
