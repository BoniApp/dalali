import 'package:flutter/material.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/appointment_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:dalali/widgets/verification_badge.dart';
import 'package:dalali/widgets/utility_display.dart';
import 'package:dalali/screens/shared/reviews_screen.dart';
import 'package:dalali/screens/tenancy/reservation_requests_screen.dart';
import 'package:dalali/screens/safety/neighbourhood_safety_screen.dart';
import 'package:dalali/screens/safety/report_incident_screen.dart';
import 'package:dalali/screens/wallet/payment_screen.dart';
import 'package:dalali/screens/landlord/edit_property_screen.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/services/app_settings.dart';
import 'package:dalali/widgets/safety_badge.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

class PropertyDetailScreen extends StatefulWidget {
  final PropertyModel property;

  const PropertyDetailScreen({super.key, required this.property});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  int _currentImage = 0;
  late PropertyModel _property;

  @override
  void initState() {
    super.initState();
    _property = widget.property;
    _incrementView();
  }

  Future<void> _incrementView() async {
    try {
      await DataService().incrementPropertyView(_property.id, _property.viewCount);
      if (mounted) {
        setState(() {
          _property = _property.copyWith(viewCount: _property.viewCount + 1);
        });
      }
    } catch (e) {
      // Silently fail — views are best-effort
      debugPrint('incrementPropertyView error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _property;
    final isFav = context.watch<AppState>().isFavorite(p.id);
    final user = context.watch<AppState>().currentUser;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  PageView.builder(
                    itemCount: p.images.length,
                    onPageChanged: (index) => setState(() => _currentImage = index),
                    itemBuilder: (context, index) => Image.network(
                      p.images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, size: 64),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        p.images.length,
                        (i) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentImage == i ? Colors.white : Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (user?.id == p.landlordId) ...[
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditPropertyScreen(property: p)),
                  ),
                  tooltip: 'Edit Property',
                ),
              ],
              IconButton(
                icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.white),
                onPressed: () => context.read<AppState>().toggleFavorite(p.id),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.title,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          Helpers.formatPrice(p.rentPrice),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          p.location,
                          style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Property Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildDetailGrid(p: p),
                  const SizedBox(height: 16),
                  const Text('Rental Payment Terms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildPaymentTermsSection(p: p),
                  const SizedBox(height: 16),
                  const Text('Amenities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _AmenityChip(icon: Icons.chair, label: p.isFurnished ? 'Furnished' : 'Unfurnished', active: p.isFurnished),
                      _AmenityChip(icon: Icons.water_drop, label: 'Water', active: p.hasWater),
                      _AmenityChip(icon: Icons.local_parking, label: 'Parking', active: p.hasParking),
                      _AmenityChip(icon: Icons.security, label: 'Security', active: p.hasSecurity),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Neighbourhood Safety', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportIncidentScreen(
                              initialLocation: p.location,
                              initialLatitude: p.latitude,
                              initialLongitude: p.longitude,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.report, size: 16),
                        label: const Text('Report'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SafetySection(property: p),
                  const SizedBox(height: 16),
                  const Text('Utilities & Responsibilities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  UtilityDisplay(utilities: p.utilities),
                  const SizedBox(height: 16),
                  const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(p.description, style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5)),
                  const SizedBox(height: 16),
                  const Text('Location on Map', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 200,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(p.latitude, p.longitude),
                          initialZoom: 14,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.dalali.app',
                            tileProvider: CancellableNetworkTileProvider(),
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(p.latitude, p.longitude),
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ReviewsScreen(property: p)),
                        ),
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ReviewPreview(propertyId: p.id),
                  const SizedBox(height: 16),
                  const Text('Landlord', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade100,
                        child: const Icon(Icons.person, color: Colors.teal),
                      ),
                      title: Text(p.landlordName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              VerificationBadge(status: p.isLandlordVerified ? VerificationStatus.verified : VerificationStatus.unverified, size: 14),
                              const SizedBox(width: 4),
                              Text(p.isLandlordVerified ? 'Verified Landlord' : 'Unverified'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _SourceBadge(sourceType: p.sourceType),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.teal),
                            onPressed: () => _call(p.landlordPhone),
                          ),
                          IconButton(
                            icon: const Icon(Icons.message, color: Colors.teal),
                            onPressed: () => _sms(p.landlordPhone),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showScheduleDialog(context, p),
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Schedule Viewing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PaymentScreen(property: p)),
                      ),
                      icon: const Icon(Icons.payments),
                      label: Text('Pay Agency Fee ${Helpers.formatPrice(AppSettings.agencyFee)}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ApplyForTenancyButton(property: p),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _reportListing(context),
                      icon: const Icon(Icons.report, color: Colors.red),
                      label: const Text('Report Fake Listing', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTermsSection({required PropertyModel p}) {
    final rentDisplay = p.rentAmount > 0 ? p.rentAmount : p.rentPrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailItem(icon: Icons.payments, label: '${Helpers.formatPrice(rentDisplay)} / Month'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: p.paymentOptions.map((term) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 16, color: Colors.teal.shade600),
                const SizedBox(width: 4),
                Text(Helpers.paymentTermLabel(term), style: const TextStyle(fontSize: 14)),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        _DetailItem(
          icon: Icons.timer,
          label: 'Minimum Accepted: ${p.minimumAcceptedTerm != null ? Helpers.paymentTermLabel(p.minimumAcceptedTerm!) : 'Not specified'}',
        ),
        const SizedBox(height: 8),
        _DetailItem(
          icon: Icons.account_balance_wallet,
          label: p.depositRequired && p.depositAmount > 0
              ? 'Deposit: ${Helpers.formatPrice(p.depositAmount)}'
              : 'Deposit: Not required',
        ),
        const SizedBox(height: 8),
        _DetailItem(
          icon: Icons.business,
          label: 'Agency Fee: ${Helpers.formatPrice(AppSettings.agencyFee)}',
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.teal.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Cost Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _CostRow(label: 'First Month Rent', amount: rentDisplay),
                if (p.depositRequired && p.depositAmount > 0)
                  _CostRow(label: 'Deposit', amount: p.depositAmount),
                _CostRow(label: 'Agency Fee', amount: AppSettings.agencyFee),
                const Divider(),
                _CostRow(
                  label: 'Total',
                  amount: rentDisplay + (p.depositRequired ? p.depositAmount : 0) + AppSettings.agencyFee,
                  isTotal: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailGrid({required PropertyModel p}) {
    final items = [
      _DetailItem(icon: Icons.bed, label: '${p.bedrooms} Bedrooms'),
      _DetailItem(icon: Icons.bathtub, label: '${p.bathrooms} Bathrooms'),
      _DetailItem(icon: Helpers.propertyTypeIcon(p.propertyType), label: Helpers.propertyTypeLabel(p.propertyType)),
      _DetailItem(icon: Icons.visibility, label: '${p.viewCount} views'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3,
      children: items,
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sms(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showScheduleDialog(BuildContext context, PropertyModel property) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Viewing'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(Helpers.formatDateOnly(selectedDate)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(selectedTime.format(context)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (picked != null) setState(() => selectedTime = picked);
                },
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final dateTime = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                selectedTime.hour,
                selectedTime.minute,
              );
              final user = context.read<AppState>().currentUser;
              if (user != null) {
                context.read<AppState>().addAppointment(AppointmentModel(
                  id: 'a${DateTime.now().millisecondsSinceEpoch}',
                  propertyId: property.id,
                  propertyTitle: property.title,
                  seekerId: user.id,
                  seekerName: user.fullName,
                  seekerPhone: user.phone,
                  landlordId: property.landlordId,
                  scheduledDate: dateTime,
                  notes: notesController.text,
                  createdAt: DateTime.now(),
                ));
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Viewing scheduled successfully!')),
              );
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }

  void _reportListing(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Listing'),
        content: const Text('Are you sure you want to report this listing as fake or misleading?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted. Thank you for keeping Dalali safe!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DetailItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.teal),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

class _CostRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isTotal;

  const _CostRow({required this.label, required this.amount, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            Helpers.formatPrice(amount),
            style: TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.teal : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _AmenityChip({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? Colors.teal.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? Colors.teal : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: active ? Colors.teal : Colors.grey),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: active ? Colors.teal : Colors.grey)),
        ],
      ),
    );
  }
}


class _ReviewPreview extends StatelessWidget {
  final String propertyId;

  const _ReviewPreview({required this.propertyId});

  @override
  Widget build(BuildContext context) {
    final reviews = context.watch<AppState>().reviews.where((r) => r.propertyId == propertyId).toList();

    if (reviews.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.rate_review_outlined, color: Colors.grey),
            SizedBox(width: 12),
            Text('No reviews yet. Be the first!', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final latest = reviews.first;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.amber.shade100,
                child: Text(latest.reviewerName[0].toUpperCase(), style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Text(latest.reviewerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 8),
              if (latest.stayVerified)
                const Icon(Icons.verified, size: 14, color: Colors.green),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.star, size: 14, color: Colors.amber[700]),
                  Text(latest.overallScore.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          if (latest.comment != null && latest.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(latest.comment!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final ListingSource sourceType;

  const _SourceBadge({required this.sourceType});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (sourceType) {
      ListingSource.landlordListing => ('Landlord Listing', Colors.teal, Icons.business),
      ListingSource.userMoveListing => ('Move Listing', Colors.orange, Icons.local_shipping),
      ListingSource.agentListing => ('Agent Listing', Colors.purple, Icons.support_agent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}


class _SafetySection extends StatelessWidget {
  final PropertyModel property;

  const _SafetySection({required this.property});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reports = context.watch<AppState>().activeNeighbourhoodReports;
    final nearbyCount = reports.where((r) {
      // Simple distance filter client-side
      final dx = (r.latitude - property.latitude).abs();
      final dy = (r.longitude - property.longitude).abs();
      return dx < 0.015 && dy < 0.015; // roughly 1.5km
    }).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SafetyBadge(safetyScore: property.safetyScore),
              const Spacer(),
              if (nearbyCount > 0)
                Text(
                  '$nearbyCount active incident${nearbyCount == 1 ? '' : 's'} nearby',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: property.safetyScore / 100,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation(
              property.safetyScore >= 80
                  ? Colors.green
                  : property.safetyScore >= 60
                      ? Colors.orange
                      : Colors.red,
            ),
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NeighbourhoodSafetyScreen()),
                  ),
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('View Safety Map'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
