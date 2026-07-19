import 'package:dalali/models/property_model.dart';
import 'package:dalali/services/supabase_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// NEARBY LISTINGS SERVICE — PostGIS "Listings Near Me" queries.
///
/// Talks to the `properties_nearby` RPC (migration 012), which
/// filters by radius/price/bedrooms/type/premium/verified and
/// returns rows sorted by distance, featured first, then newest.
/// Adds client-side smart-radius expansion and a short-TTL cache.
/// ═══════════════════════════════════════════════════════════════

/// Filters accepted by the `properties_nearby` RPC.
class NearbyFilter {
  final double? minPrice;
  final double? maxPrice;
  final int? bedrooms;
  final PropertyType? propertyType;
  final bool premiumOnly;
  final bool verifiedOnly;

  const NearbyFilter({
    this.minPrice,
    this.maxPrice,
    this.bedrooms,
    this.propertyType,
    this.premiumOnly = false,
    this.verifiedOnly = false,
  });

  bool get isEmpty =>
      minPrice == null &&
      maxPrice == null &&
      bedrooms == null &&
      propertyType == null &&
      !premiumOnly &&
      !verifiedOnly;

  NearbyFilter copyWith({
    double? Function()? minPrice,
    double? Function()? maxPrice,
    int? Function()? bedrooms,
    PropertyType? Function()? propertyType,
    bool? premiumOnly,
    bool? verifiedOnly,
  }) {
    return NearbyFilter(
      minPrice: minPrice != null ? minPrice() : this.minPrice,
      maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
      bedrooms: bedrooms != null ? bedrooms() : this.bedrooms,
      propertyType: propertyType != null ? propertyType() : this.propertyType,
      premiumOnly: premiumOnly ?? this.premiumOnly,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    );
  }

  String get cacheKey =>
      '${minPrice ?? ''}|${maxPrice ?? ''}|${bedrooms ?? ''}|'
      '${propertyType?.name ?? ''}|$premiumOnly|$verifiedOnly';
}

/// One page of nearby listings plus the radius actually used
/// (differs from the requested radius after smart expansion).
class NearbyResult {
  final List<PropertyModel> listings;
  final int radiusMeters;
  final bool expanded;

  const NearbyResult({
    required this.listings,
    required this.radiusMeters,
    this.expanded = false,
  });
}

class NearbyListingsService {
  static final _db = SupabaseService.client;

  /// Radius steps (meters) offered by the selector and walked by the
  /// smart-radius expansion. [cityRadiusMeters] is "Entire City".
  static const List<int> radiusStepsMeters = [500, 1000, 2000, 5000, 10000];
  static const int cityRadiusMeters = 30000;

  /// Smart radius keeps expanding until at least this many listings
  /// are found (or the steps run out).
  static const int smartRadiusMinResults = 5;

  static const int pageSize = 50;
  static const Duration _cacheTtl = Duration(minutes: 2);

  final Map<String, _CacheEntry> _cache = {};

  // ─── Pure helpers (unit-tested) ──────────────────────────────

  /// Next smart-radius step after [current], or [cityRadiusMeters]
  /// when the steps are exhausted. Returns null when already at city.
  static int? nextRadiusMeters(int current) {
    for (final step in radiusStepsMeters) {
      if (step > current) return step;
    }
    return current < cityRadiusMeters ? cityRadiusMeters : null;
  }

  /// "450 m" below 1 km, "1.2 km" above. Empty string when unknown.
  static String formatDistanceMeters(double? meters) {
    if (meters == null) return '';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Compact map-badge price: 250000 → "Tsh 250k", 1500000 → "Tsh 1.5M".
  static String compactTzs(double price) {
    if (price >= 1000000) {
      final m = price / 1000000;
      return 'Tsh ${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M';
    }
    if (price >= 1000) {
      final k = price / 1000;
      return 'Tsh ${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
    }
    return 'Tsh ${price.toStringAsFixed(0)}';
  }

  // ─── Queries ─────────────────────────────────────────────────

  /// Single-page nearby query against the RPC. Results are cached
  /// briefly (per rounded position + radius + filter) so panning the
  /// map or toggling the sheet doesn't re-hit PostGIS.
  Future<List<PropertyModel>> fetchNearby({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    NearbyFilter filter = const NearbyFilter(),
    int limit = pageSize,
    int offset = 0,
  }) async {
    final key = _cacheKey(latitude, longitude, radiusMeters, filter, offset);
    final cached = _cache[key];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.listings;
    }

    final rows = await _db.rpc('properties_nearby', params: {
      'p_lat': latitude,
      'p_lng': longitude,
      'p_radius_m': radiusMeters,
      'p_min_price': filter.minPrice,
      'p_max_price': filter.maxPrice,
      'p_bedrooms': filter.bedrooms,
      'p_property_type': filter.propertyType?.name,
      'p_premium_only': filter.premiumOnly,
      'p_verified_only': filter.verifiedOnly,
      'p_limit': limit,
      'p_offset': offset,
    });
    final listings = (rows as List<dynamic>)
        .map((r) => PropertyModel.fromJson(r as Map<String, dynamic>))
        .toList();

    _cache[key] = _CacheEntry(
      listings,
      DateTime.now().add(_cacheTtl),
    );
    return listings;
  }

  /// Smart radius: expands through [radiusStepsMeters] until enough
  /// listings are found, so sparse areas still show useful results.
  Future<NearbyResult> fetchWithSmartRadius({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    NearbyFilter filter = const NearbyFilter(),
    bool smartExpand = true,
  }) async {
    var radius = radiusMeters;
    while (true) {
      final listings = await fetchNearby(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radius,
        filter: filter,
      );
      final next = nextRadiusMeters(radius);
      if (!smartExpand ||
          listings.length >= smartRadiusMinResults ||
          next == null) {
        return NearbyResult(
          listings: listings,
          radiusMeters: radius,
          expanded: radius != radiusMeters,
        );
      }
      radius = next;
    }
  }

  /// Busts the cache after a realtime insert inside the search area.
  void invalidateCache() => _cache.clear();

  String _cacheKey(double lat, double lng, int radius, NearbyFilter f, int offset) =>
      '${lat.toStringAsFixed(3)}|${lng.toStringAsFixed(3)}|$radius|${f.cacheKey}|$offset';
}

class _CacheEntry {
  final List<PropertyModel> listings;
  final DateTime expiresAt;
  const _CacheEntry(this.listings, this.expiresAt);
}
