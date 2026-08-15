import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_user_model.dart';
import '../services/chat_api.dart';
import '../services/location_service.dart';
import '../services/map_api.dart';
import '../services/map_config.dart';
import '../theme/spark_colors.dart';
import '../widgets/map_heat_layer.dart';
import 'conversation_view.dart';

/// Below this zoom, show density heat only (Snap Map style). At/above it,
/// reveal individual profile pins on top of the heat.
const double _markerRevealZoom = 12.0;

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  final MapApi _mapApi = MapApi();
  final ChatApi _chatApi = ChatApi();

  LatLng _center = const LatLng(
    MapConfig.fallbackLatitude,
    MapConfig.fallbackLongitude,
  );
  LatLng? _userLocation;
  bool _isLocating = true;
  String? _locationMessage;
  List<MapUserModel> _nearbyUsers = [];
  bool _isStartingConversation = false;
  double _mapZoom = MapConfig.defaultZoom;

  bool get _showIndividualMarkers => _mapZoom >= _markerRevealZoom;

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    final zoom = camera.zoom;
    final markersWereVisible = _showIndividualMarkers;
    final markersNowVisible = zoom >= _markerRevealZoom;
    _mapZoom = zoom;
    if (markersWereVisible != markersNowVisible) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _locateUser();
    _loadNearbyUsers();
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
      // Defer until after the first frame: FlutterMap must be laid out at
      // least once before its controller can be used (it's called from
      // initState via _locateUser(), which can resolve before that happens).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(location, MapConfig.defaultZoom);
      });
      _shareLocation(location);
    } else {
      setState(() {
        _isLocating = false;
        _locationMessage = showMessages
            ? _messageFor(result.failure!)
            : null;
      });
    }
  }

  Future<void> _shareLocation(LatLng location) async {
    try {
      await _mapApi.updateLocation(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      _loadNearbyUsers();
    } catch (_) {
      // Sharing location is best-effort; the map still works without it.
    }
  }

  Future<void> _loadNearbyUsers() async {
    try {
      final users = await _mapApi.getNearbyUsers();
      if (!mounted) return;
      setState(() {
        _nearbyUsers = users;
      });
    } catch (_) {
      // Keep whatever markers we already have; fail silently on the map.
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

  void _showUserDetails(MapUserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SparkColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _UserDetailsSheet(
        user: user,
        onMessage: () {
          Navigator.of(context).pop();
          _startConversation(user);
        },
      ),
    );
  }

  Future<void> _startConversation(MapUserModel user) async {
    if (_isStartingConversation) return;
    setState(() => _isStartingConversation = true);
    try {
      final conversation = await _chatApi.startConversation(user.id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ConversationView(
            conversationId: conversation.id,
            otherUserName: conversation.otherUserName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't start the conversation. Try again.")),
      );
    } finally {
      if (mounted) setState(() => _isStartingConversation = false);
    }
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
              onPositionChanged: _onPositionChanged,
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
              if (_nearbyUsers.isNotEmpty) ...[
                MapHeatLayer(users: _nearbyUsers),
                // Profile pins only once zoomed in enough to read them —
                // zoomed out the heat spots are the signal (Snap Map).
                if (_showIndividualMarkers)
                  MarkerLayer(
                    markers: [
                      for (final user in _nearbyUsers)
                        Marker(
                          point: LatLng(user.latitude, user.longitude),
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          child: _NearbyUserMarker(
                            user: user,
                            onTap: () => _showUserDetails(user),
                          ),
                        ),
                    ],
                  ),
              ],
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

          if (_nearbyUsers.isNotEmpty)
            Positioned(
              left: 16,
              bottom: 24,
              child: _SimilarityLegend(showActivity: !_showIndividualMarkers),
            ),
        ],
      ),
    );
  }
}

/// Maps a similarity score (0.0-1.0) to a blue → cyan → yellow → red heat
/// color, matching how "hot" a user's marker looks based on how similar
/// their profile settings are to the current user's.
Color similarityHeatColor(double similarity) {
  const stops = <double>[0.0, 0.35, 0.65, 1.0];
  const colors = <Color>[
    Color(0xFF2E6BFF), // blue — least similar
    Color(0xFF29D3C6), // cyan
    Color(0xFFFFD23F), // yellow
    Color(0xFFFF3B30), // red — most similar
  ];

  final value = similarity.clamp(0.0, 1.0);
  for (var i = 0; i < stops.length - 1; i++) {
    if (value <= stops[i + 1]) {
      final segment = (value - stops[i]) / (stops[i + 1] - stops[i]);
      return Color.lerp(colors[i], colors[i + 1], segment.clamp(0.0, 1.0))!;
    }
  }
  return colors.last;
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

/// A nearby user's profile icon on the map, wrapped in a heat-colored glow
/// that scales from blue (less similar) to red (more similar) based on
/// [MapUserModel.similarity].
class _NearbyUserMarker extends StatelessWidget {
  const _NearbyUserMarker({required this.user, required this.onTap});

  final MapUserModel user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final heatColor = similarityHeatColor(user.similarity);
    final initial = user.name.trim().isNotEmpty
        ? user.name.trim()[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: '${user.name} · ${(user.similarity * 100).round()}% match',
        child: RepaintBoundary(
          child: SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Blurred heat glow behind the icon — the actual "heat color".
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        heatColor.withValues(alpha: 0.65),
                        heatColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                // Profile icon.
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SparkColors.surfaceElevated,
                    border: Border.all(color: heatColor, width: 2.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: SparkColors.title,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Legend for the cyan → red ramp. Zoomed out this is people density;
/// zoomed in it matches the profile-similarity pin colors.
class _SimilarityLegend extends StatelessWidget {
  const _SimilarityLegend({required this.showActivity});

  final bool showActivity;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SparkColors.surfaceElevated.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              showActivity ? 'Activity' : 'Profile match',
              style: const TextStyle(
                color: SparkColors.title,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 110,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: showActivity
                      ? const [
                          Colors.lightBlue,
                          Colors.cyan,
                          Colors.yellow,
                          Colors.orange,
                          Colors.red,
                        ]
                      : [
                          similarityHeatColor(0),
                          similarityHeatColor(0.35),
                          similarityHeatColor(0.65),
                          similarityHeatColor(1),
                        ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  showActivity ? 'Quiet' : 'Less alike',
                  style: const TextStyle(
                    color: SparkColors.placeholder,
                    fontSize: 9,
                  ),
                ),
                Text(
                  showActivity ? 'Busy' : 'More alike',
                  style: const TextStyle(
                    color: SparkColors.placeholder,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with a nearby user's basic details, match percentage, and a
/// way to start a conversation with them.
class _UserDetailsSheet extends StatelessWidget {
  const _UserDetailsSheet({required this.user, required this.onMessage});

  final MapUserModel user;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final heatColor = similarityHeatColor(user.similarity);
    final initial = user.name.trim().isNotEmpty
        ? user.name.trim()[0].toUpperCase()
        : '?';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SparkColors.surface,
                    border: Border.all(color: heatColor, width: 3),
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: SparkColors.title,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.age != null ? '${user.name}, ${user.age}' : user.name,
                        style: const TextStyle(
                          color: SparkColors.title,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(user.similarity * 100).round()}% profile match',
                        style: TextStyle(
                          color: heatColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: Text('Message ${user.name}'),
            ),
          ],
        ),
      ),
    );
  }
}
