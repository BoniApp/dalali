import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationService {
  static const String otherOption = 'Other';

  static const Map<String, LatLng> tzLocations = {
    'masaki, dar es salaam': LatLng(-6.7480, 39.2710),
    'mikocheni, dar es salaam': LatLng(-6.7630, 39.2500),
    'oyster bay, dar es salaam': LatLng(-6.7400, 39.2800),
    'upanga, dar es salaam': LatLng(-6.8100, 39.2700),
    'kariakoo, dar es salaam': LatLng(-6.8200, 39.2700),
    'kijitonyama, dar es salaam': LatLng(-6.7700, 39.2400),
    'ubungo, dar es salaam': LatLng(-6.7924, 39.2083),
    'buguruni, dar es salaam': LatLng(-6.8330, 39.2200),
    'tandika, dar es salaam': LatLng(-6.8600, 39.2300),
    'changombe, dar es salaam': LatLng(-6.8400, 39.2100),
    'makuburi, dar es salaam': LatLng(-6.8050, 39.2150),
    'kawe, dar es salaam': LatLng(-6.7200, 39.2600),
    'kinondoni, dar es salaam': LatLng(-6.7800, 39.2300),
    'ilala, dar es salaam': LatLng(-6.8250, 39.2700),
    'temeke, dar es salaam': LatLng(-6.8500, 39.2500),
    'city centre, dodoma': LatLng(-6.1731, 35.7419),
    'nyamagana, mwanza': LatLng(-2.5167, 32.9000),
    'ilemela, mwanza': LatLng(-2.5200, 32.9200),
    'arusha city, arusha': LatLng(-3.3869, 36.6830),
    'moshi, kilimanjaro': LatLng(-3.3400, 37.3400),
    'mbeya city, mbeya': LatLng(-8.9100, 33.4500),
    'morogoro, morogoro': LatLng(-6.8200, 37.6600),
    'tanga, tanga': LatLng(-5.0700, 39.1000),
    'zanzibar city, zanzibar': LatLng(-6.1659, 39.2026),
    'stone town, zanzibar': LatLng(-6.1622, 39.1921),
  };

  static const Map<String, List<String>> districtWards = {
    'Kinondoni': [
      'Masaki',
      'Mikocheni',
      'Kawe',
      'Kijitonyama',
      'Ubungo',
      'Kibamba',
      'Sinza',
      'Mwananyamala',
      'Makongo',
      otherOption,
    ],
    'Ilala': [
      'Upanga East',
      'Upanga West',
      'Kariakoo',
      'Mchikichini',
      'Vingunguti',
      'Kivukoni',
      'Mchafukoge',
      otherOption,
    ],
    'Temeke': [
      'Changombe',
      'Tandika',
      'Mbagala',
      'Yombo Vituka',
      'Kurasini',
      'Mtoni',
      otherOption,
    ],
    'Arusha': [
      'Olasiti',
      'Unga Limited',
      'Lemara',
      'Sokoni',
      'Kati',
      otherOption,
    ],
    'Mwanza': [
      'Nyamagana',
      'Ilemela',
      'Mkolani',
      'Mkuyuni',
      otherOption,
    ],
  };

  static LatLng resolveCoordinates(String location) {
    final key = location.toLowerCase().trim();
    if (tzLocations.containsKey(key)) {
      return tzLocations[key]!;
    }
    for (final entry in tzLocations.entries) {
      if (key.contains(entry.key.split(',').first.trim())) {
        return entry.value;
      }
    }
    return const LatLng(-6.7924, 39.2083);
  }

  static Map<String, String> resolveDistrictWard(String location) {
    final key = location.toLowerCase();
    for (final district in districtWards.keys) {
      final normalizedDistrict = district.toLowerCase();
      if (key.contains(normalizedDistrict)) {
        return { 'district': district, 'ward': '' };
      }
      for (final ward in districtWards[district]!) {
        if (ward == otherOption) continue;
        final normalizedWard = ward.toLowerCase();
        if (key.contains(normalizedWard)) {
          return { 'district': district, 'ward': ward };
        }
      }
    }
    return { 'district': '', 'ward': '' };
  }

  static Future<Map<String, String>> reverseGeocodeAddress(
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': latitude.toStringAsFixed(6),
      'lon': longitude.toStringAsFixed(6),
      'format': 'jsonv2',
      'addressdetails': '1',
    });

    final response = await http.get(uri, headers: {'User-Agent': 'DalaliApp/1.0'});
    if (response.statusCode != 200) return {};

    final body = jsonDecode(response.body) as Map<String, dynamic>?;
    if (body == null) return {};

    final address = body['address'] as Map<String, dynamic>?;
    if (address == null) return {};

    final street = address['road'] as String? ??
        address['pedestrian'] as String? ??
        address['footway'] as String? ??
        address['street'] as String? ??
        address['residential'] as String? ??
        '';

    var ward = address['suburb'] as String? ??
        address['quarter'] as String? ??
        address['hamlet'] as String? ??
        address['neighbourhood'] as String? ??
        '';

    var district = address['city_district'] as String? ??
        address['county'] as String? ??
        address['state_district'] as String? ??
        address['city'] as String? ??
        '';

    if (district.isEmpty && ward.isNotEmpty) {
      for (final entry in districtWards.entries) {
        if (entry.value.any((w) => w.toLowerCase() == ward.toLowerCase())) {
          district = entry.key;
          break;
        }
      }
    }

    if (district.isNotEmpty) {
      district = district[0].toUpperCase() + district.substring(1);
    }
    if (ward.isNotEmpty) {
      ward = ward[0].toUpperCase() + ward.substring(1);
    }

    return {
      'street': street,
      'district': district,
      'ward': ward,
    };
  }
}
