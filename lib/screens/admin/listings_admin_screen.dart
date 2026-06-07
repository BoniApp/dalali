import 'package:flutter/material.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:dalali/utils/helpers.dart';

class ListingsAdminScreen extends StatelessWidget {
  const ListingsAdminScreen({super.key});

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
              child: StreamBuilder<List<PropertyModel>>(
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
                      rows: listings.map((p) => DataRow(
                        cells: [
                          DataCell(
                            p.images.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(p.images.first, width: 50, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40)),
                                  )
                                : const Icon(Icons.image, size: 40),
                          ),
                          DataCell(Text(p.title, style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(Text(p.location)),
                          DataCell(Text(Helpers.formatPrice(p.rentPrice))),
                          DataCell(Text(p.landlordName)),
                          DataCell(Chip(
                            label: Text(p.status.name, style: const TextStyle(fontSize: 10)),
                            backgroundColor: p.status == PropertyStatus.available ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                            labelStyle: TextStyle(fontSize: 10, color: p.status == PropertyStatus.available ? Colors.green : Colors.grey),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )),
                          DataCell(
                            p.isApproved
                                ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                : const Icon(Icons.pending, color: Colors.orange, size: 20),
                          ),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!p.isApproved)
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                  tooltip: 'Approve',
                                  onPressed: () {},
                                ),
                              IconButton(
                                icon: const Icon(Icons.block, color: Colors.red, size: 18),
                                tooltip: 'Remove',
                                onPressed: () {},
                              ),
                            ],
                          )),
                        ],
                      )).toList(),
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
