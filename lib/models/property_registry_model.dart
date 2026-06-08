import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dalali/models/property_model.dart';

enum RegistryVerificationStatus { unverified, pending, verified, rejected }

/// ═══════════════════════════════════════════════════════════════
/// PROPERTY REGISTRY MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// The Property Registry is the canonical record of a physical property.
/// One physical property exists exactly once. All listings reference
/// a registry entry via [registryId].
///
class PropertyRegistryModel {
  final String registryId;
  final String propertyHash;
  final double latitude;
  final double longitude;
  final String landlordPhone;
  final String landlordName;
  final PropertyType propertyType;
  final int rooms;
  final String address;
  final RegistryVerificationStatus verificationStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PropertyRegistryModel({
    required this.registryId,
    required this.propertyHash,
    required this.latitude,
    required this.longitude,
    required this.landlordPhone,
    required this.landlordName,
    required this.propertyType,
    required this.rooms,
    required this.address,
    this.verificationStatus = RegistryVerificationStatus.unverified,
    required this.createdAt,
    this.updatedAt,
  });

  /// Generate a deterministic hash for a physical property.
  /// This hash is used for duplicate detection.
  static String generatePropertyHash({
    required double latitude,
    required double longitude,
    required String landlordPhone,
    required PropertyType propertyType,
    required int rooms,
  }) {
    // Round GPS to 5 decimal places (~1.1m precision) for hashing
    final lat = latitude.toStringAsFixed(5);
    final lng = longitude.toStringAsFixed(5);
    final phone = landlordPhone.replaceAll(RegExp(r'\D'), '');
    final raw = '$lat|$lng|$phone|${propertyType.name}|$rooms';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Map<String, dynamic> toJson() => {
        'registry_id': registryId,
        'property_hash': propertyHash,
        'latitude': latitude,
        'longitude': longitude,
        'landlord_phone': landlordPhone,
        'landlord_name': landlordName,
        'property_type': propertyType.name,
        'rooms': rooms,
        'address': address,
        'verification_status': verificationStatus.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory PropertyRegistryModel.fromJson(Map<String, dynamic> json) {
    return PropertyRegistryModel(
      registryId: json['registry_id'] ?? '',
      propertyHash: json['property_hash'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      landlordPhone: json['landlord_phone'] ?? '',
      landlordName: json['landlord_name'] ?? '',
      propertyType: PropertyType.values.firstWhere(
        (e) => e.name == json['property_type'],
        orElse: () => PropertyType.apartment,
      ),
      rooms: json['rooms'] ?? 0,
      address: json['address'] ?? '',
      verificationStatus: RegistryVerificationStatus.values.firstWhere(
        (e) => e.name == json['verification_status'],
        orElse: () => RegistryVerificationStatus.unverified,
      ),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  PropertyRegistryModel copyWith({
    RegistryVerificationStatus? verificationStatus,
    DateTime? updatedAt,
  }) {
    return PropertyRegistryModel(
      registryId: registryId,
      propertyHash: propertyHash,
      latitude: latitude,
      longitude: longitude,
      landlordPhone: landlordPhone,
      landlordName: landlordName,
      propertyType: propertyType,
      rooms: rooms,
      address: address,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
