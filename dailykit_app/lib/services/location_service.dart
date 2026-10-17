import 'package:geolocator/geolocator.dart';

class SosLocationResult {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String locationSource; // 'live' | 'last_known' | 'unavailable'
  final String label;

  SosLocationResult({
    this.latitude,
    this.longitude,
    this.accuracy,
    required this.locationSource,
    required this.label,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  String get googleMapsUrl {
    if (hasCoordinates) {
      return 'https://maps.google.com/?q=$latitude,$longitude';
    }
    return '';
  }
}

class LocationService {
  static final LocationService instance = LocationService._internal();

  LocationService._internal();

  /// Checks location permissions and GPS service status.
  Future<bool> ensurePermissionAndService() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Obtains current GPS location within a 10-second timeout.
  /// If live GPS is unavailable or times out, seamlessly falls back to last known location.
  Future<SosLocationResult> getSosLocation() async {
    final hasAccess = await ensurePermissionAndService();

    if (!hasAccess) {
      // Try to read last known location even if fine GPS service is off
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return SosLocationResult(
            latitude: lastKnown.latitude,
            longitude: lastKnown.longitude,
            accuracy: lastKnown.accuracy,
            locationSource: 'last_known',
            label: 'last known location',
          );
        }
      } catch (_) {}

      return SosLocationResult(
        locationSource: 'unavailable',
        label: 'location unavailable',
      );
    }

    // Attempt high-accuracy foreground location with a strict 10-second timeout
    try {
      final Position livePos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return SosLocationResult(
        latitude: livePos.latitude,
        longitude: livePos.longitude,
        accuracy: livePos.accuracy,
        locationSource: 'live',
        label: 'live location',
      );
    } catch (_) {
      // 10-second timeout exceeded or GPS error -> fallback to last known location
      try {
        final Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return SosLocationResult(
            latitude: lastKnown.latitude,
            longitude: lastKnown.longitude,
            accuracy: lastKnown.accuracy,
            locationSource: 'last_known',
            label: 'last known location',
          );
        }
      } catch (_) {}

      return SosLocationResult(
        locationSource: 'unavailable',
        label: 'location unavailable',
      );
    }
  }
}

