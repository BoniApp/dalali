import 'package:flutter/material.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:dalali/screens/shared/property_detail_screen.dart';
import 'package:dalali/screens/landlord/add_property_screen.dart';
import 'package:dalali/screens/landlord/edit_property_screen.dart';
import 'package:provider/provider.dart';

class LandlordDashboardScreen extends StatelessWidget {
  const LandlordDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final properties = context.watch<AppState>().landlordProperties;
    final totalViews = properties.fold<int>(0, (sum, p) => sum + p.viewCount);
    final totalInquiries = properties.fold<int>(0, (sum, p) => sum + p.inquiryCount);
    final activeListings = properties.where((p) => p.status == PropertyStatus.available).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatCard(
                    icon: Icons.home,
                    label: 'Active Listings',
                    value: '$activeListings',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.visibility,
                    label: 'Total Views',
                    value: '$totalViews',
                    color: Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatCard(
                    icon: Icons.message,
                    label: 'Inquiries',
                    value: '$totalInquiries',
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.trending_up,
                    label: 'Occupancy',
                    value: properties.isEmpty ? '0%' : '${((properties.where((p) => p.status == PropertyStatus.occupied).length / properties.length) * 100).toInt()}%',
                    color: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('My Properties', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddPropertyScreen()),
                      );
                    },
                    child: const Text('+ Add New'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (properties.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.home_work_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No properties yet', style: TextStyle(color: Colors.grey)),
                        Text('Tap + Add to list your first property', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: properties.length,
                  itemBuilder: (context, index) {
                    final p = properties[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: p)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  p.images.first,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(p.location, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    const SizedBox(height: 4),
                                    Text(Helpers.formatPrice(p.rentPrice), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  _StatusChip(status: p.status),
                                  const SizedBox(height: 8),
                                  Text('${p.viewCount} views', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: Colors.teal),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => EditPropertyScreen(property: p)),
                                    ),
                                    tooltip: 'Edit',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final PropertyStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case PropertyStatus.available:
        color = Colors.green;
        label = 'Available';
        break;
      case PropertyStatus.occupied:
        color = Colors.red;
        label = 'Occupied';
        break;
      case PropertyStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
