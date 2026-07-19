import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/widgets/property_card.dart';
import 'package:dalali/widgets/filter_sheet.dart';
import 'package:dalali/screens/shared/property_detail_screen.dart';
import 'package:dalali/screens/move/start_move_screen.dart';
import 'package:dalali/screens/move/move_dashboard_screen.dart';
import 'package:dalali/screens/safety/neighbourhood_safety_screen.dart';
import 'package:dalali/screens/seeker/nearby_map_screen.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/move_listing_model.dart';
import 'package:dalali/widgets/notification_bell.dart';
import 'package:provider/provider.dart';

class SeekerHomeScreen extends StatefulWidget {
  const SeekerHomeScreen({super.key});

  @override
  State<SeekerHomeScreen> createState() => _SeekerHomeScreenState();
}

class _SeekerHomeScreenState extends State<SeekerHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic> _filters = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PropertyModel> _getFilteredProperties(AppState state) {
    return state.properties.where((p) {
      if (p.status != PropertyStatus.available) return false;
      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        final match = p.title.toLowerCase().contains(query) ||
            p.location.toLowerCase().contains(query);
        if (!match) return false;
      }
      if (_filters['minPrice'] != null && p.rentPrice < _filters['minPrice']) return false;
      if (_filters['maxPrice'] != null && p.rentPrice > _filters['maxPrice']) return false;
      if (_filters['bedrooms'] != null && p.bedrooms != _filters['bedrooms']) return false;
      if (_filters['furnished'] == true && !p.isFurnished) return false;
      if (_filters['water'] == true && !p.hasWater) return false;
      if (_filters['parking'] == true && !p.hasParking) return false;
      if (_filters['type'] != null && p.propertyType != _filters['type']) return false;
      if (_filters['paymentTerms'] != null) {
        final terms = _filters['paymentTerms'] as List<PaymentTerm>;
        if (terms.isNotEmpty) {
          final hasMatch = p.paymentOptions.any((option) => terms.contains(option));
          if (!hasMatch) return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final filtered = _getFilteredProperties(state);
    final featured = state.featuredProperties;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dalali'),
        centerTitle: true,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          const NotificationBell(iconColor: Colors.white),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: AppLocalizations.of(context)!.nearMeTitle,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NearbyMapScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => FilterSheet(
                  initialFilters: _filters,
                  onApply: (filters) => setState(() => _filters = filters),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by location or name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (featured.isNotEmpty && _searchController.text.isEmpty && _filters.isEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Featured Properties',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(
                          height: 280,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: featured.length,
                            itemBuilder: (context, index) {
                              final p = featured[index];
                              return SizedBox(
                                width: 300,
                                child: PropertyCard(
                                  property: p,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PropertyDetailScreen(property: p),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_searchController.text.isEmpty && _filters.isEmpty)
                  SliverToBoxAdapter(
                    child: _PeopleMovingSection(moves: state.activeMoveListings),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      _searchController.text.isEmpty && _filters.isEmpty
                          ? 'All Properties'
                          : 'Search Results (${filtered.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No properties found', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => PropertyCard(
                        property: filtered[index],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PropertyDetailScreen(property: filtered[index]),
                          ),
                        ),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _PeopleMovingSection extends StatelessWidget {
  final List<MoveListingModel> moves;

  const _PeopleMovingSection({required this.moves});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AppState>().currentUser;
    final isMoving = user?.isMoving ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Start Moving CTA
        if (!isMoving)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StartMoveScreen()),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_shipping, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Moving soon?',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'List your current home & find your next one.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),

        // Active move banner
        if (isMoving)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MoveDashboardScreen()),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your move is active',
                            style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Tap to view your move dashboard.',
                            style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.orange.shade700, size: 16),
                  ],
                ),
              ),
            ),
          ),

        // People moving near you
        if (moves.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'People Moving Near You',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: moves.length,
              itemBuilder: (context, index) {
                final m = moves[index];
                return SizedBox(
                  width: 260,
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Text(m.userName[0].toUpperCase(), style: const TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  m.userName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: m.status == MoveStatus.active
                                      ? Colors.blue.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  m.status == MoveStatus.active ? 'Active' : 'Planning',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: m.status == MoveStatus.active
                                        ? Colors.blue.shade700
                                        : Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Moving from: ${m.currentLocation}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (m.preferredLocation != null)
                            Text(
                              'Looking for: ${m.preferredLocation}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        // Neighbourhood Safety quick access
        if (!isMoving)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NeighbourhoodSafetyScreen()),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.shield, color: Colors.red.shade700),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Neighbourhood Safety',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'View incidents and report safety concerns.',
                            style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.red.shade700, size: 16),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}


