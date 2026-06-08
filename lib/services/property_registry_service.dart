import 'dart:math' as math;
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/property_registry_model.dart';
import 'package:dalali/services/data_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// PROPERTY REGISTRY SERVICE
/// ═══════════════════════════════════════════════════════════════
///
/// Handles duplicate detection, registry creation, and property
/// claim workflows.
///
class PropertyRegistryService {
  final DataService _data = DataService();

  /// Check if a property already exists in the registry.
  /// Returns the existing registry entry if found.
  Future<PropertyRegistryModel?> checkDuplicate({
    required double latitude,
    required double longitude,
    required String landlordPhone,
    required PropertyType propertyType,
    required int rooms,
  }) async {
    final hash = PropertyRegistryModel.generatePropertyHash(
      latitude: latitude,
      longitude: longitude,
      landlordPhone: landlordPhone,
      propertyType: propertyType,
      rooms: rooms,
    );
    return await _data.getRegistryByHash(hash);
  }

  /// Create a new registry entry and return it.
  Future<PropertyRegistryModel> createRegistry({
    required double latitude,
    required double longitude,
    required String landlordPhone,
    required String landlordName,
    required PropertyType propertyType,
    required int rooms,
    required String address,
  }) async {
    final hash = PropertyRegistryModel.generatePropertyHash(
      latitude: latitude,
      longitude: longitude,
      landlordPhone: landlordPhone,
      propertyType: propertyType,
      rooms: rooms,
    );

    final registry = PropertyRegistryModel(
      registryId: 'reg_${DateTime.now().millisecondsSinceEpoch}',
      propertyHash: hash,
      latitude: latitude,
      longitude: longitude,
      landlordPhone: landlordPhone,
      landlordName: landlordName,
      propertyType: propertyType,
      rooms: rooms,
      address: address,
      createdAt: DateTime.now(),
    );

    await _data.addRegistry(registry);
    return registry;
  }

  /// Proximity check: returns true if another registry entry exists
  /// within [thresholdMeters] of the given coordinates.
  Future<bool> isNearbyPropertyExists(
    double latitude,
    double longitude, {
    double thresholdMeters = 50.0,
  }) async {
    // NOTE: In production, use a geohash-based or PostGIS query.
    // For now we stream all and filter client-side as fallback.
    final all = await _data.getPropertyRegistry(limit: 1000).first;
    for (final reg in all) {
      final dist = _haversine(latitude, longitude, reg.latitude, reg.longitude);
      if (dist <= thresholdMeters) return true;
    }
    return false;
  }

  /// Simple address similarity check (placeholder).
  /// In production, integrate a string-similarity library or fuzzy match.
  bool isAddressSimilar(String a, String b) {
    final normA = a.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final normB = b.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return normA == normB || normA.contains(normB) || normB.contains(normA);
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _toRad(double deg) => deg * math.pi / 180;
}
