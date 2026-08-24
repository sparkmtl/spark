import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Result of a location lookup attempt, including why it may have failed.
class LocationResult {
  const LocationResult.success(this.position)
      : failure = null;

  const LocationResult.failure(LocationFailure this.failure)
      : position = null;

  final Position? position;
  final LocationFailure? failure;

  bool get isSuccess => position != null;
}

enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unknown,
}

/// Auto check-out radius in kilometers (must match backend GeoUtils).
const double checkInAutoCheckoutRadiusKm = 1.0;

/// Prefer a fix at or below this horizontal accuracy (meters).
const double _acceptableAccuracyMeters = 50.0;

/// How long to wait for a good GPS fix after permission is granted.
const Duration _freshFixTimeout = Duration(seconds: 25);

/// Thin wrapper around `geolocator` that handles permission requests and
/// service checks so views don't need to know the details.
abstract final class LocationService {
  static const LocationSettings _highAccuracySettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
  );

  static const LocationSettings _streamSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  static Future<LocationResult> getCurrentLocation() async {
    try {
      final permissionResult = await _ensurePermission();
      if (permissionResult != null) return permissionResult;

      final fromStream = await _waitForFreshFix();
      if (fromStream != null) {
        return LocationResult.success(fromStream);
      }

      // Stream timed out with no reading — one last one-shot attempt.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      ).timeout(const Duration(seconds: 22));
      return LocationResult.success(position);
    } catch (_) {
      return const LocationResult.failure(LocationFailure.unknown);
    }
  }

  /// Continuous high-accuracy updates for live map / check-in tracking.
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(locationSettings: _streamSettings);
  }

  static double distanceKm(LatLng a, LatLng b) {
    const earthRadiusKm = 6371.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final deltaLat = (b.latitude - a.latitude) * math.pi / 180;
    final deltaLon = (b.longitude - a.longitude) * math.pi / 180;

    final sinHalfLat = math.sin(deltaLat / 2);
    final sinHalfLon = math.sin(deltaLon / 2);
    final haversine = sinHalfLat * sinHalfLat +
        math.cos(lat1) * math.cos(lat2) * sinHalfLon * sinHalfLon;
    final c = 2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
    return earthRadiusKm * c;
  }

  /// Returns a failure result if location cannot be used; otherwise null.
  static Future<LocationResult?> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult.failure(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const LocationResult.failure(LocationFailure.permissionDenied);
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.failure(
        LocationFailure.permissionDeniedForever,
      );
    }
    return null;
  }

  /// Listens to the position stream until we get an accurate fix, or the
  /// best reading within [_freshFixTimeout]. Returns null if nothing arrived.
  static Future<Position?> _waitForFreshFix() async {
    final completer = Completer<Position?>();
    StreamSubscription<Position>? subscription;
    Timer? timeout;
    Position? best;

    void finish(Position? value) {
      if (completer.isCompleted) return;
      timeout?.cancel();
      subscription?.cancel();
      completer.complete(value);
    }

    timeout = Timer(_freshFixTimeout, () => finish(best));

    try {
      subscription = Geolocator.getPositionStream(
        locationSettings: _highAccuracySettings,
      ).listen(
        (position) {
          if (best == null || position.accuracy < best!.accuracy) {
            best = position;
          }
          if (position.accuracy <= _acceptableAccuracyMeters) {
            finish(position);
          }
        },
        onError: (_) => finish(best),
        cancelOnError: true,
      );
    } catch (_) {
      finish(best);
    }

    return completer.future;
  }
}
