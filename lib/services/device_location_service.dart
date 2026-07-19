import 'package:geolocator/geolocator.dart';

/// ═══════════════════════════════════════════════════════════════
/// DEVICE LOCATION SERVICE — GPS access for the Near Me map.
///
/// Wraps `geolocator` with Dalali's permission flow. Distinct from
/// `LocationService`, which holds static TZ place/ward data.
/// ═══════════════════════════════════════════════════════════════
class DeviceLocationService {
  /// Result of a position request, so the UI can explain failures.
  static const String errorServiceDisabled = 'serviceDisabled';
  static const String errorDenied = 'denied';
  static const String errorDeniedForever = 'deniedForever';

  /// Current GPS position, or null when unavailable. When null is
  /// returned, [lastError] holds one of the `error*` constants.
  String? lastError;

  Future<Position?> currentPosition() async {
    lastError = null;
    if (!await Geolocator.isLocationServiceEnabled()) {
      lastError = errorServiceDisabled;
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      lastError = errorDenied;
      return null;
    }
    if (permission == LocationPermission.deniedForever) {
      lastError = errorDeniedForever;
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      lastError = errorDenied;
      return null;
    }
  }

  /// Live position updates (emitted after ~10 m of movement) for live
  /// distance labels on listing cards. Caller must have permission.
  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 10,
      ),
    );
  }
}
