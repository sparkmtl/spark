import 'package:latlong2/latlong.dart';

/// A geographic area with a high concentration of users who are a strong
/// profile match for the current user. Rendered on the map as a single,
/// consistently-colored translucent circle (see `map_clustering.dart`).
class MapHotZone {
  const MapHotZone({
    required this.center,
    required this.radiusMeters,
    required this.userCount,
    required this.intensity,
  });

  final LatLng center;
  final double radiusMeters;
  final int userCount;

  /// 0.0-1.0, driven by how many relevant users are in the zone. Used to
  /// scale the zone's opacity so denser zones stand out more.
  final double intensity;
}
