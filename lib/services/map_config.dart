/// Configuration for the Mapbox-powered map section.
///
/// Pass the Mapbox **public** token (`pk.…`) at build/run time:
///   flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.xxxxx
///
/// Do not commit real tokens to source control.
abstract final class MapConfig {
  static const String accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  /// Mapbox styles are served through a raster tile template. `{styleId}`
  /// selects the look of the map (dark theme by default to match the app).
  static const String _styleId = 'dark-v11';

  /// Mapbox requires a unique-per-app identifier suffix for raster tile
  /// requests via the Static Tiles API.
  static String get tileUrlTemplate =>
      'https://api.mapbox.com/styles/v1/mapbox/$_styleId/tiles/256/{z}/{x}/{y}@2x'
      '?access_token=$accessToken';

  static const String attribution = '© Mapbox © OpenStreetMap';

  /// Fallback map center when location access is unavailable/denied
  /// (downtown Toronto, Canada).
  static const double fallbackLatitude = 43.6532;
  static const double fallbackLongitude = -79.3832;
  static const double defaultZoom = 12.0;

  static bool get hasAccessToken => accessToken.isNotEmpty;
}
