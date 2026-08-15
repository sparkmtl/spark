import 'map_secrets.dart';

/// Configuration for the Mapbox-powered map section.
///
/// Token resolution order:
/// 1. `--dart-define=MAPBOX_ACCESS_TOKEN=pk.…` (optional override)
/// 2. [MapSecrets.accessToken] from gitignored `map_secrets.dart`
abstract final class MapConfig {
  static const String accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: MapSecrets.accessToken,
  );

  /// Mapbox styles are served through a raster tile template.
  /// Dark theme by default to match the app.
  static const String _styleId = 'dark-v11';

  static String get tileUrlTemplate =>
      'https://api.mapbox.com/styles/v1/mapbox/$_styleId/tiles/256/{z}/{x}/{y}@2x'
      '?access_token=$accessToken';

  static const String attribution = '© Mapbox © OpenStreetMap';

  /// Fallback map center when location access is unavailable/denied
  /// (downtown Toronto, Canada).
  static const double fallbackLatitude = 43.6532;
  static const double fallbackLongitude = -79.3832;
  static const double defaultZoom = 12.0;

  static bool get hasAccessToken =>
      accessToken.isNotEmpty && !accessToken.contains('YOUR_MAPBOX');
}
