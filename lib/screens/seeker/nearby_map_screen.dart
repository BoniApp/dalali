import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dalali/config/app_theme.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/screens/shared/property_detail_screen.dart';
import 'package:dalali/services/device_location_service.dart';
import 'package:dalali/services/nearby_listings_service.dart';
import 'package:dalali/services/supabase_service.dart';
import 'package:dalali/utils/helpers.dart';

/// ═══════════════════════════════════════════════════════════════
/// NEAR ME MAP — "Listings Near Me" experience.
///
/// Full-screen OpenStreetMap with the user's GPS position, a search
/// radius circle, clustered price-badge markers fed by the PostGIS
/// `properties_nearby` RPC, and a draggable sheet of listing cards.
///
///  - Radius chips (500 m → Entire City) reload listings instantly;
///    a smart radius auto-expands when an area has too few results.
///  - Distance labels update live as the user moves (position stream).
///  - Supabase Realtime announces new listings inside the radius.
///  - Optional heatmap layer: translucent circles brighten where
///    listings concentrate.
/// ═══════════════════════════════════════════════════════════════

/// Straight-line distance in meters between two map points.
double _distMeters(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Meter, a, b);

class NearbyMapScreen extends StatefulWidget {
  const NearbyMapScreen({super.key});

  @override
  State<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends State<NearbyMapScreen> {
  static const _fallbackCenter = LatLng(-6.7924, 39.2083); // Dar es Salaam

  final _mapController = MapController();
  final _cardController = PageController(viewportFraction: 0.9);
  final _searchController = TextEditingController();
  final _nearby = NearbyListingsService();
  final _deviceLocation = DeviceLocationService();

  StreamSubscription<Position>? _positionSub;
  RealtimeChannel? _channel;
  Timer? _panDebounce;

  LatLng _center = _fallbackCenter;
  LatLng? _userLocation;
  int _radiusMeters = 1000;
  NearbyFilter _filter = const NearbyFilter();
  List<PropertyModel> _listings = [];
  String? _selectedId;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _heatmapOn = false;
  bool _mapReady = false;
  bool _rotated = false;
  int _offset = 0;

  /// Listings after the free-text search is applied. Markers and
  /// cards both index into this list.
  List<PropertyModel> get _visible {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _listings;
    return _listings.where((p) {
      return p.title.toLowerCase().contains(query) ||
          p.location.toLowerCase().contains(query) ||
          p.ward.toLowerCase().contains(query) ||
          p.street.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _panDebounce?.cancel();
    if (_channel != null) SupabaseService.client.removeChannel(_channel!);
    _searchController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  // ─── Bootstrap & data loading ───────────────────────────────

  Future<void> _bootstrap() async {
    final pos = await _deviceLocation.currentPosition();
    if (!mounted) return;
    if (pos != null) {
      _userLocation = LatLng(pos.latitude, pos.longitude);
      _center = _userLocation!;
      _subscribePosition();
    } else {
      _showLocationFallback();
    }
    await _fetch(smartExpand: true);
    _subscribeRealtime();
    if (mounted && _mapReady) {
      _mapController.move(_center, _zoomForRadius(_radiusMeters));
    }
  }

  Future<void> _fetch({required bool smartExpand}) async {
    setState(() => _loading = true);
    try {
      final result = await _nearby.fetchWithSmartRadius(
        latitude: _center.latitude,
        longitude: _center.longitude,
        radiusMeters: _radiusMeters,
        filter: _filter,
        smartExpand: smartExpand,
      );
      if (!mounted) return;
      setState(() {
        _listings = result.listings;
        _radiusMeters = result.radiusMeters;
        _hasMore = result.listings.length >= NearbyListingsService.pageSize;
        _offset = result.listings.length;
        _loading = false;
        _selectedId = null;
      });
      _fitResults();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.nearbyLoadError),
        action: SnackBarAction(
          label: l10n.retryLabel,
          onPressed: () => _fetch(smartExpand: smartExpand),
        ),
      ));
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _nearby.fetchNearby(
        latitude: _center.latitude,
        longitude: _center.longitude,
        radiusMeters: _radiusMeters,
        filter: _filter,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _listings = [..._listings, ...more];
        _offset += more.length;
        _hasMore = more.length >= NearbyListingsService.pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// After a fetch, make sure the radius circle (and results) are
  /// comfortably in view.
  void _fitResults() {
    if (!_mapReady) return;
    final zoom = _zoomForRadius(_radiusMeters);
    _mapController.move(_center, math.min(_mapController.camera.zoom, zoom));
  }

  static double _zoomForRadius(int meters) {
    if (meters <= 500) return 15.5;
    if (meters <= 1000) return 14.8;
    if (meters <= 2000) return 14.2;
    if (meters <= 5000) return 13.4;
    if (meters <= 10000) return 12.6;
    return 11.6;
  }

  // ─── Live GPS ────────────────────────────────────────────────

  void _subscribePosition() {
    _positionSub = _deviceLocation.positionStream().listen((pos) {
      if (!mounted) return;
      final user = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userLocation = user;
        _listings = _listings
            .map((p) => p.copyWith(
                  distanceMeters:
                      _distMeters(user, LatLng(p.latitude, p.longitude)),
                ))
            .toList()
          ..sort((a, b) =>
              (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
      });
      // Refetch when the user has walked well away from the fetch center.
      if (_distMeters(user, _center) > 250) {
        _center = user;
        _fetch(smartExpand: false);
      }
    });
  }

  // ─── Realtime "new listing nearby" ───────────────────────────

  void _subscribeRealtime() {
    final channel = SupabaseService.client.channel('nearby-new-listings');
    _channel = channel;
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'properties',
          callback: _onNewListing,
        )
        .subscribe();
  }

  void _onNewListing(PostgresChangePayload payload) {
    final row = payload.newRecord;
    final lat = double.tryParse('${row['latitude']}') ?? 0;
    final lng = double.tryParse('${row['longitude']}') ?? 0;
    if (lat == 0 || lng == 0) return;
    if (row['status'] != 'available' || row['is_approved'] != true) return;
    final from = _userLocation ?? _center;
    final distance = _distMeters(from, LatLng(lat, lng));
    if (distance > _radiusMeters) return;
    _nearby.invalidateCache();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.newListingNearby(
        NearbyListingsService.formatDistanceMeters(distance),
      )),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: l10n.viewNow,
        onPressed: () => _fetch(smartExpand: false),
      ),
    ));
  }

  // ─── Map events ──────────────────────────────────────────────

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    final rotated = camera.rotation.abs() > 0.5;
    if (rotated != _rotated) setState(() => _rotated = rotated);
    if (!hasGesture) return;
    // Fetch only around what the user is actually looking at: when the
    // map is panned far from the last fetch center, reload there.
    _panDebounce?.cancel();
    _panDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_distMeters(camera.center, _center) > _radiusMeters * 0.4) {
        _center = camera.center;
        _fetch(smartExpand: false);
      }
    });
  }

  void _onMarkerTap(PropertyModel property) {
    final visible = _visible;
    final index = visible.indexWhere((p) => p.id == property.id);
    if (index < 0) return;
    setState(() => _selectedId = property.id);
    if (_cardController.hasClients) {
      _cardController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    if (_mapReady) {
      _mapController.move(
        LatLng(property.latitude, property.longitude),
        math.max(_mapController.camera.zoom, 15),
      );
    }
  }

  void _onCardChanged(int index) {
    final visible = _visible;
    if (index < 0 || index >= visible.length) return;
    final property = visible[index];
    setState(() => _selectedId = property.id);
    if (_mapReady) {
      _mapController.move(
        LatLng(property.latitude, property.longitude),
        _mapController.camera.zoom,
      );
    }
  }

  void _centerOnUser() {
    final user = _userLocation;
    if (user != null && _mapReady) {
      _mapController.move(user, math.max(_mapController.camera.zoom, 15));
      _center = user;
      _fetch(smartExpand: false);
    } else {
      _bootstrap();
    }
  }

  void _showLocationFallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final error = _deviceLocation.lastError;
      final message = error == DeviceLocationService.errorServiceDisabled
          ? l10n.locationServicesOff
          : l10n.locationPermissionDenied;
      SnackBarAction? action;
      if (error == DeviceLocationService.errorDeniedForever) {
        action = SnackBarAction(
          label: l10n.openSettings,
          onPressed: Geolocator.openAppSettings,
        );
      } else if (error == DeviceLocationService.errorServiceDisabled) {
        action = SnackBarAction(
          label: l10n.enableGps,
          onPressed: Geolocator.openLocationSettings,
        );
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message), action: action));
    });
  }

  String _radiusLabel(AppLocalizations l10n, int meters) {
    if (meters >= NearbyListingsService.cityRadiusMeters) {
      return l10n.entireCity;
    }
    if (meters >= 1000) return '${meters ~/ 1000} km';
    return '$meters m';
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = _visible;

    return Scaffold(
      body: Stack(
        children: [
          _buildMap(visible),
          _buildTopBar(l10n),
          _buildFabs(l10n),
          if (!_loading && _listings.isEmpty) _buildEmptyState(l10n),
          if (!_loading && _listings.isNotEmpty && visible.isEmpty)
            _buildNoSearchMatch(l10n),
          if (visible.isNotEmpty) _buildListingSheet(l10n, visible),
          if (_loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(List<PropertyModel> visible) {
    final markers = visible
        .map((p) => Marker(
              point: LatLng(p.latitude, p.longitude),
              width: p.id == _selectedId ? 108 : 88,
              height: p.id == _selectedId ? 44 : 36,
              child: _PriceMarker(
                key: ValueKey('marker_${p.id}'),
                property: p,
                selected: p.id == _selectedId,
                onTap: () => _onMarkerTap(p),
              ),
            ))
        .toList();

    return AnimatedOpacity(
      opacity: _loading && _listings.isEmpty ? 0.45 : 1,
      duration: const Duration(milliseconds: 300),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: 13,
          onMapReady: () => setState(() => _mapReady = true),
          onPositionChanged: _onPositionChanged,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.dalali.app',
            tileProvider: CancellableNetworkTileProvider(),
          ),
          if (_radiusMeters < NearbyListingsService.cityRadiusMeters)
            CircleLayer(circles: [
              CircleMarker(
                point: _userLocation ?? _center,
                radius: _radiusMeters.toDouble(),
                useRadiusInMeter: true,
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderColor: AppTheme.primary.withValues(alpha: 0.4),
                borderStrokeWidth: 1.5,
              ),
            ]),
          if (_heatmapOn)
            CircleLayer(
              circles: visible
                  .map((p) => CircleMarker(
                        point: LatLng(p.latitude, p.longitude),
                        radius: 160,
                        useRadiusInMeter: true,
                        color: Colors.blue.withValues(alpha: 0.12),
                      ))
                  .toList(),
            ),
          MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              markers: markers,
              size: const Size(44, 44),
              maxClusterRadius: 56,
              showPolygon: false,
              markerChildBehavior: true,
              builder: (context, clusterMarkers) => Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${clusterMarkers.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          if (_userLocation != null)
            MarkerLayer(markers: [
              Marker(
                point: _userLocation!,
                width: 56,
                height: 56,
                child: const _PulsingUserDot(),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    final radiusOptions = [
      ...NearbyListingsService.radiusStepsMeters,
      NearbyListingsService.cityRadiusMeters,
    ];
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              Row(
                children: [
                  _roundButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/dalali_logo.png',
                      width: 36,
                      height: 36,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(24),
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: l10n.searchNearbyHint,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _roundButton(
                    icon: Icons.tune,
                    badge: !_filter.isEmpty,
                    onTap: _openFilters,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: radiusOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final meters = radiusOptions[i];
                    return ChoiceChip(
                      label: Text(_radiusLabel(l10n, meters)),
                      selected: _radiusMeters == meters,
                      onSelected: (_) {
                        setState(() => _radiusMeters = meters);
                        _fetch(smartExpand: false);
                      },
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _radiusMeters == meters
                            ? Colors.white
                            : AppTheme.textPrimary,
                      ),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFabs(AppLocalizations l10n) {
    final sheetMinPx = MediaQuery.of(context).size.height * 0.30;
    return Positioned(
      right: 12,
      bottom: sheetMinPx + 16,
      child: Column(
        children: [
          _roundButton(
            icon: _heatmapOn ? Icons.layers : Icons.layers_outlined,
            tooltip: l10n.heatmapLabel,
            active: _heatmapOn,
            onTap: () => setState(() => _heatmapOn = !_heatmapOn),
          ),
          if (_rotated) ...[
            const SizedBox(height: 10),
            _roundButton(
              icon: Icons.explore,
              onTap: () => _mapController.rotate(0),
            ),
          ],
          const SizedBox(height: 10),
          _roundButton(
            icon: Icons.my_location,
            onTap: _centerOnUser,
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    bool badge = false,
    bool active = false,
  }) {
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: active
          ? AppTheme.primary
          : Theme.of(context).scaffoldBackgroundColor,
      child: IconButton(
        icon: Badge(
          isLabelVisible: badge,
          smallSize: 8,
          child: Icon(
            icon,
            size: 20,
            color: active ? Colors.white : AppTheme.primary,
          ),
        ),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    final next = NearbyListingsService.nextRadiusMeters(_radiusMeters);
    return Center(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_searching,
                  size: 48, color: AppTheme.primary),
              const SizedBox(height: 12),
              Text(
                l10n.noListingsNearby,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (next != null) ...[
                const SizedBox(height: 8),
                Text(l10n.expandSearchRadius),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _radiusMeters = next);
                    _fetch(smartExpand: false);
                  },
                  child: Text(l10n.searchWithinRadius(
                      _radiusLabel(l10n, next))),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _radiusMeters =
                        NearbyListingsService.cityRadiusMeters);
                    _fetch(smartExpand: false);
                  },
                  child: Text(
                      l10n.searchWithinRadius(l10n.entireCity)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoSearchMatch(AppLocalizations l10n) {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.30 + 16,
      left: 32,
      right: 32,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            l10n.noMatchingFilters,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildListingSheet(
      AppLocalizations l10n, List<PropertyModel> visible) {
    return DraggableScrollableSheet(
      initialChildSize: 0.30,
      minChildSize: 0.30,
      maxChildSize: 0.62,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.listingsNearby(visible.length),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _radiusLabel(l10n, _radiusMeters),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 196,
                child: PageView.builder(
                  controller: _cardController,
                  onPageChanged: _onCardChanged,
                  itemCount: visible.length,
                  itemBuilder: (context, i) =>
                      _NearbyCard(property: visible[i]),
                ),
              ),
              if (_hasMore)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: OutlinedButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: _loadingMore
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.loadMore),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NearbyFilterSheet(
        initial: _filter,
        onApply: (filter) {
          setState(() => _filter = filter);
          _fetch(smartExpand: false);
        },
      ),
    );
  }
}

/// ─── Price-badge map marker ──────────────────────────────────
/// House icon + compact price ("Tsh 250k"). Drops in with a bounce,
/// premium listings pulse gold, the selected marker glows orange.
class _PriceMarker extends StatelessWidget {
  final PropertyModel property;
  final bool selected;
  final VoidCallback onTap;

  const _PriceMarker({
    super.key,
    required this.property,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final premium = property.listingType == ListingType.featured;
    final badge = GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.12 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: premium
                ? const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                  )
                : null,
            color: premium
                ? null
                : (selected ? AppTheme.action : AppTheme.primary),
            borderRadius: BorderRadius.circular(16),
            border: selected ? Border.all(color: Colors.white, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AppTheme.action.withValues(alpha: 0.6)
                    : Colors.black26,
                blurRadius: selected ? 10 : 4,
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.home, color: Colors.white, size: 13),
                const SizedBox(width: 3),
                Text(
                  NearbyListingsService.compactTzs(property.rentPrice),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final animated = premium ? _Pulse(child: badge) : badge;

    // Drop-in from above with a bounce when the marker first appears.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, -28 * (1 - t)),
        child: Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: animated,
    );
  }
}

/// Subtle infinite pulse for premium (featured) listing markers.
class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.07).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

/// Animated blue GPS dot with an expanding pulse ring.
class _PulsingUserDot extends StatefulWidget {
  const _PulsingUserDot();

  @override
  State<_PulsingUserDot> createState() => _PulsingUserDotState();
}

class _PulsingUserDotState extends State<_PulsingUserDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 0.4 + 0.6 * t,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(alpha: 0.35 * (1 - t)),
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// ─── Listing card in the bottom sheet ────────────────────────
class _NearbyCard extends StatelessWidget {
  final PropertyModel property;

  const _NearbyCard({required this.property});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<AppState>();
    final favorite = state.isFavorite(property.id);
    final area = property.ward.isNotEmpty ? property.ward : property.location;
    final premium = property.listingType == ListingType.featured;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PropertyDetailScreen(property: property),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(16)),
                child: SizedBox(
                  width: 118,
                  height: double.infinity,
                  child: property.images.isNotEmpty
                      ? Image.network(
                          property.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              property.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              favorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 20,
                              color: favorite ? Colors.red : Colors.grey,
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                state.toggleFavorite(property.id),
                          ),
                        ],
                      ),
                      Text(
                        l10n.pricePerMonth(
                            Helpers.formatPrice(property.rentPrice)),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Helpers.propertyTypeLabel(property.propertyType)} · '
                        '${property.bedrooms} bd · ${property.bathrooms} ba',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.near_me,
                              size: 13, color: AppTheme.action),
                          const SizedBox(width: 3),
                          Text(
                            l10n.distanceAway(
                              NearbyListingsService.formatDistanceMeters(
                                  property.distanceMeters),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.action,
                            ),
                          ),
                          if (area.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                area,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (property.isLandlordVerified)
                            const _MiniBadge(
                              icon: Icons.verified,
                              color: Colors.green,
                            ),
                          if (premium)
                            const _MiniBadge(
                              icon: Icons.workspace_premium,
                              color: Color(0xFFB8860B),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        color: Colors.grey.shade300,
        child: const Icon(Icons.home, size: 40, color: Colors.grey),
      );
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MiniBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

/// ─── Filter sheet (RPC-backed filters only) ──────────────────
class _NearbyFilterSheet extends StatefulWidget {
  final NearbyFilter initial;
  final ValueChanged<NearbyFilter> onApply;

  const _NearbyFilterSheet({required this.initial, required this.onApply});

  @override
  State<_NearbyFilterSheet> createState() => _NearbyFilterSheetState();
}

class _NearbyFilterSheetState extends State<_NearbyFilterSheet> {
  static const double _priceCap = 5000000;

  late RangeValues _price;
  late int? _bedrooms;
  late PropertyType? _type;
  late bool _premiumOnly;
  late bool _verifiedOnly;

  @override
  void initState() {
    super.initState();
    _price = RangeValues(
      widget.initial.minPrice ?? 0,
      widget.initial.maxPrice ?? _priceCap,
    );
    _bedrooms = widget.initial.bedrooms;
    _type = widget.initial.propertyType;
    _premiumOnly = widget.initial.premiumOnly;
    _verifiedOnly = widget.initial.verifiedOnly;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.filtersTitle,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Text(l10n.priceRangeTzs,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            RangeSlider(
              values: _price,
              min: 0,
              max: _priceCap,
              divisions: 25,
              labels: RangeLabels(
                Helpers.formatPrice(_price.start),
                Helpers.formatPrice(_price.end),
              ),
              onChanged: (v) => setState(() => _price = v),
            ),
            const SizedBox(height: 8),
            Text(l10n.bedroomsLabel,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.anyOption),
                  selected: _bedrooms == null,
                  onSelected: (_) => setState(() => _bedrooms = null),
                ),
                ...[1, 2, 3, 4].map((n) => ChoiceChip(
                      label: Text(n == 4 ? '4+' : '$n'),
                      selected: _bedrooms == n,
                      onSelected: (_) => setState(() => _bedrooms = n),
                    )),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.propertyTypeHeader,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: Text(l10n.anyOption),
                  selected: _type == null,
                  onSelected: (_) => setState(() => _type = null),
                ),
                ...PropertyType.values.map((t) => ChoiceChip(
                      label: Text(Helpers.propertyTypeLabel(t)),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    )),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.premiumOnly),
              value: _premiumOnly,
              onChanged: (v) => setState(() => _premiumOnly = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.verifiedOnly),
              value: _verifiedOnly,
              onChanged: (v) => setState(() => _verifiedOnly = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _price = const RangeValues(0, _priceCap);
                    _bedrooms = null;
                    _type = null;
                    _premiumOnly = false;
                    _verifiedOnly = false;
                  }),
                  child: Text(l10n.resetFilters),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    widget.onApply(NearbyFilter(
                      minPrice: _price.start > 0 ? _price.start : null,
                      maxPrice: _price.end < _priceCap ? _price.end : null,
                      bedrooms: _bedrooms,
                      propertyType: _type,
                      premiumOnly: _premiumOnly,
                      verifiedOnly: _verifiedOnly,
                    ));
                    Navigator.pop(context);
                  },
                  child: Text(l10n.applyFilters),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
