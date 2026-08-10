import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../services/map_config.dart';
import '../theme/spark_colors.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();

  LatLng _center = const LatLng(
    MapConfig.fallbackLatitude,
    MapConfig.fallbackLongitude,
  );
  LatLng? _userLocation;
  bool _isLocating = true;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  Future<void> _locateUser({bool showMessages = false}) async {
    setState(() {
      _isLocating = true;
      _locationMessage = null;
    });

    final result = await LocationService.getCurrentLocation();

    if (!mounted) return;

    if (result.isSuccess) {
      final position = result.position!;
      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _userLocation = location;
        _center = location;
        _isLocating = false;
      });
      _mapController.move(location, MapConfig.defaultZoom);
    } else {
      setState(() {
        _isLocating = false;
        _locationMessage = showMessages
            ? _messageFor(result.failure!)
            : null;
      });
    }
  }

  String _messageFor(LocationFailure failure) {
    switch (failure) {
      case LocationFailure.serviceDisabled:
        return 'Turn on location services to see where you are.';
      case LocationFailure.permissionDenied:
        return 'Location permission denied.';
      case LocationFailure.permissionDeniedForever:
        return 'Location permission is blocked. Enable it in Settings.';
      case LocationFailure.unknown:
        return "Couldn't get your location.";
    }
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!MapConfig.hasAccessToken) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Mapbox token missing.\n\n'
              'Run with:\n'
              'flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: SparkColors.fieldText,
                  ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: MapConfig.defaultZoom,
              minZoom: 2,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrlTemplate,
                userAgentPackageName: 'com.spark.app',
                maxZoom: 19,
              ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution(MapConfig.attribution),
                ],
              ),
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 44,
                      height: 44,
                      child: const _UserLocationDot(),
                    ),
                  ],
                ),
            ],
          ),

          if (_isLocating)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _StatusPill(
                icon: Icons.my_location,
                label: 'Finding your location…',
                showSpinner: true,
              ),
            )
          else if (_locationMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _StatusPill(
                icon: Icons.location_off_outlined,
                label: _locationMessage!,
                onTap: () => _locateUser(showMessages: true),
              ),
            ),

          Positioned(
            right: 16,
            bottom: 24,
            child: Column(
              children: [
                _MapButton(
                  icon: Icons.add,
                  onPressed: () => _zoomBy(1),
                ),
                const SizedBox(height: 10),
                _MapButton(
                  icon: Icons.remove,
                  onPressed: () => _zoomBy(-1),
                ),
                const SizedBox(height: 18),
                _MapButton(
                  icon: Icons.my_location,
                  isPrimary: true,
                  onPressed: () => _locateUser(showMessages: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SparkColors.accent.withValues(alpha: 0.22),
      ),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SparkColors.accent,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? SparkColors.accent : SparkColors.surfaceElevated,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: 22,
            color: isPrimary ? SparkColors.onAccent : SparkColors.title,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    this.showSpinner = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool showSpinner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SparkColors.surfaceElevated.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (showSpinner)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SparkColors.accent,
                  ),
                )
              else
                Icon(icon, size: 18, color: SparkColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: SparkColors.title,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.refresh,
                  size: 16,
                  color: SparkColors.placeholder,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
