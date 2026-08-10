import 'package:geolocator/geolocator.dart';

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

enum LocationFailure { serviceDisabled, permissionDenied, permissionDeniedForever, unknown }

/// Thin wrapper around `geolocator` that handles permission requests and
/// service checks so views don't need to know the details.
abstract final class LocationService {
  static Future<LocationResult> getCurrentLocation() async {
    try {
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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LocationResult.success(position);
    } catch (_) {
      return const LocationResult.failure(LocationFailure.unknown);
    }
  }
}
