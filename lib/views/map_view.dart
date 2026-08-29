import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_user_model.dart';
import '../services/chat_api.dart';
import '../services/check_in_api.dart';
import '../services/auth_api.dart';
import '../services/location_service.dart';
import '../services/map_api.dart';
import '../services/map_config.dart';
import '../theme/spark_colors.dart';
import '../widgets/map_heat_layer.dart';
import '../widgets/spark_snackbar.dart';
import 'conversation_view.dart';

/// Below this zoom, show density heat only (Snap Map style). At/above it,
/// reveal individual profile pins on top of the heat.
const double _markerRevealZoom = 12.0;

/// Skip local auto-checkout briefly after check-in so a stale last-known
/// anchor is not immediately invalidated by a fresh GPS fix.
const Duration _checkInAutoCheckoutGrace = Duration(seconds: 45);

/// Horizontal accuracy (meters) required before local auto-checkout may fire.
const double _autoCheckoutMaxAccuracyMeters = 50.0;

/// How often peer polling also reconciles check-in status with the server.
const int _statusReconcileEveryNPolls = 8;

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  final MapApi _mapApi = MapApi();
  final ChatApi _chatApi = ChatApi();
  final CheckInApi _checkInApi = CheckInApi();

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

  bool _isCheckedIn = false;
  String? _checkInMessage;
  LatLng? _checkInAnchor;
  List<MapUserModel> _checkedInUsers = [];
  StreamSubscription<Position>? _positionSub;
  Timer? _checkInPollTimer;
  Timer? _statusMessageTimer;
  DateTime? _lastLocationPushAt;
  LatLng? _lastPushedLocation;
  /// Bumped on user check-in/out so async stale-clear cannot clobber local state.
  int _checkInEpoch = 0;
  /// In-flight POST /api/check-in; awaited before DELETE on checkout.
  Future<void>? _persistCheckInFuture;
  /// True when a local checkout still needs a successful server DELETE.
  bool _checkoutNeedsRetry = false;
  DateTime? _checkInGraceUntil;
  int _checkInPollCount = 0;

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
    // Do not restore a previous check-in after login — start unchecked.
    // Clear any leftover active check-in from a prior session.
    _clearStaleCheckInOnOpen();
  }

  /// Ensures the user is not left checked in from a previous session when the
  /// map opens after login. Check-in must be an explicit button action.
  /// Skips entirely if the user already checked in/out while this was in flight.
  Future<void> _clearStaleCheckInOnOpen() async {
    final epoch = _checkInEpoch;
    try {
      final status = await _checkInApi.getCheckInStatus();
      if (!mounted || epoch != _checkInEpoch || _isCheckedIn) return;
      if (status.checkedIn) {
        await _checkInApi.checkOut();
      }
    } catch (_) {
      // Best-effort; local UI stays unchecked either way.
    }
    if (!mounted || epoch != _checkInEpoch || _isCheckedIn) return;
    setState(() {
      _isCheckedIn = false;
      _checkInAnchor = null;
      _checkedInUsers = [];
    });
    _stopCheckInPolling();
  }

  /// Shows a transient status pill that clears itself after [_notificationDuration].
  void _showCheckInMessage(String message) {
    _statusMessageTimer?.cancel();
    setState(() {
      _checkInMessage = message;
      _locationMessage = null;
    });
    _statusMessageTimer = Timer(kSparkNotificationDuration, () {
      if (!mounted) return;
      setState(() {
        if (_checkInMessage == message) {
          _checkInMessage = null;
        }
      });
    });
  }

  void _showLocationMessage(String message) {
    _statusMessageTimer?.cancel();
    setState(() {
      _locationMessage = message;
      _checkInMessage = null;
    });
    _statusMessageTimer = Timer(kSparkNotificationDuration, () {
      if (!mounted) return;
      setState(() {
        if (_locationMessage == message) {
          _locationMessage = null;
        }
      });
    });
  }

  Future<void> _locateUser({bool showMessages = false}) async {
    _statusMessageTimer?.cancel();
    setState(() {
      _isLocating = true;
      _checkInMessage = null;
      _locationMessage = null;
    });

    // Seed the map immediately from last-known / quick fix so check-in and
    // the blue dot are available without waiting on high-accuracy GPS.
    final quick = await LocationService.getQuickLocation();
    if (!mounted) return;

    if (quick.isSuccess) {
      final location =
          LatLng(quick.position!.latitude, quick.position!.longitude);
      setState(() {
        _userLocation = location;
        _center = location;
        _isLocating = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(location, MapConfig.defaultZoom);
      });
      _lastLocationPushAt = DateTime.now();
      _lastPushedLocation = location;
      _shareLocation(location);
      _startLocationTracking();
      // Refine accuracy in the background; do not block the UI.
      _refineLocationInBackground();
      return;
    }

    // No quick fix — fall back to the slower high-accuracy path once.
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(location, MapConfig.defaultZoom);
      });
      _lastLocationPushAt = DateTime.now();
      _lastPushedLocation = location;
      await _shareLocation(location);
      _startLocationTracking();
    } else {
      setState(() {
        _isLocating = false;
      });
      if (showMessages) {
        _showLocationMessage(_messageFor(result.failure!));
      }
    }
  }

  Future<void> _refineLocationInBackground() async {
    final result = await LocationService.getCurrentLocation();
    if (!mounted || !result.isSuccess) return;
    final location =
        LatLng(result.position!.latitude, result.position!.longitude);
    setState(() {
      _userLocation = location;
      _center = location;
    });
    _lastLocationPushAt = DateTime.now();
    _lastPushedLocation = location;
    _shareLocation(location);
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

  Future<void> _loadCheckedInUsers() async {
    if (!_isCheckedIn) return;
    try {
      final users = await _checkInApi.getCheckedInUsers();
      if (!mounted || !_isCheckedIn) return;
      setState(() {
        _checkedInUsers = users;
      });
    } catch (_) {
      // Keep existing checked-in markers on transient failures.
    }
  }

  void _toggleCheckIn() {
    if (_isCheckedIn) {
      _performCheckOut();
    } else {
      _performCheckIn();
    }
  }

  /// Instant local check-in when the blue-dot location is already on the map.
  /// Never waits on GPS or the network before updating UI.
  void _performCheckIn() {
    final location = _userLocation;
    if (location == null) {
      _showLocationMessage('Wait for your location on the map, then check in.');
      return;
    }

    _checkInEpoch++;
    _checkoutNeedsRetry = false;
    _checkInGraceUntil = DateTime.now().add(_checkInAutoCheckoutGrace);
    _statusMessageTimer?.cancel();
    setState(() {
      _isCheckedIn = true;
      _checkInAnchor = location;
      _checkInMessage = null;
    });
    _showCheckInMessage('Checked in — sharing live location');
    _startLocationTracking();
    _startCheckInPolling();
    unawaited(_loadCheckedInUsers());
    final future = _persistCheckIn(location);
    _persistCheckInFuture = future;
    unawaited(future.whenComplete(() {
      if (identical(_persistCheckInFuture, future)) {
        _persistCheckInFuture = null;
      }
    }));
  }

  Future<void> _persistCheckIn(LatLng location) async {
    final epoch = _checkInEpoch;
    try {
      final status = await _checkInApi.checkIn(
        latitude: location.latitude,
        longitude: location.longitude,
      );

      // User checked out (or rolled back) while POST was in flight — clear
      // the row we just created so it cannot become a ghost check-in.
      if (epoch != _checkInEpoch || !_isCheckedIn) {
        try {
          await _checkInApi.checkOut();
        } catch (_) {
          // Idempotent server checkout; retry path may follow.
        }
        return;
      }
      if (!mounted) return;

      setState(() {
        _isCheckedIn = status.checkedIn;
        _checkInAnchor = status.anchorLatitude != null &&
                status.anchorLongitude != null
            ? LatLng(status.anchorLatitude!, status.anchorLongitude!)
            : location;
      });
      unawaited(_loadCheckedInUsers());
    } on ApiException catch (e) {
      if (!mounted || epoch != _checkInEpoch) return;
      if (e.statusCode == 409) {
        _showCheckInMessage('Already checked in');
        unawaited(_syncCheckInStateFromServer(epoch: epoch));
        return;
      }
      _rollbackOptimisticCheckIn();
      _showCheckInMessage("Couldn't check in. Try again.");
    } catch (_) {
      if (!mounted || epoch != _checkInEpoch) return;
      _rollbackOptimisticCheckIn();
      _showCheckInMessage("Couldn't check in. Try again.");
    }
  }

  void _rollbackOptimisticCheckIn() {
    _checkInEpoch++;
    _checkInGraceUntil = null;
    _checkoutNeedsRetry = false;
    _stopCheckInPolling();
    setState(() {
      _isCheckedIn = false;
      _checkInAnchor = null;
      _checkedInUsers = [];
    });
  }

  /// Aligns local check-in UI with [CheckInApi.getCheckInStatus].
  /// Aborts if [epoch] no longer matches (e.g. user checked out mid-sync).
  Future<void> _syncCheckInStateFromServer({required int epoch}) async {
    try {
      final status = await _checkInApi.getCheckInStatus();
      if (!mounted || epoch != _checkInEpoch) return;

      if (!status.checkedIn) {
        _checkInGraceUntil = null;
        _stopCheckInPolling();
        setState(() {
          _isCheckedIn = false;
          _checkInAnchor = null;
          _checkedInUsers = [];
        });
        return;
      }

      final anchor = status.anchorLatitude != null &&
              status.anchorLongitude != null
          ? LatLng(status.anchorLatitude!, status.anchorLongitude!)
          : null;

      setState(() {
        _isCheckedIn = true;
        _checkInAnchor = anchor;
        if (status.latitude != null && status.longitude != null) {
          _userLocation = LatLng(status.latitude!, status.longitude!);
        }
      });
      _startLocationTracking();
      _startCheckInPolling();
      _loadCheckedInUsers();
    } catch (_) {
      // Keep whatever local state we already have.
    }
  }

  /// Instant local checkout; server DELETE awaits in-flight POST then retries.
  void _performCheckOut({bool autoCheckedOut = false}) {
    final wasCheckedIn = _isCheckedIn;
    _checkInEpoch++;
    _checkInGraceUntil = null;
    // Keep the GPS stream running so map location continues to update.
    _stopCheckInPolling();

    setState(() {
      _isCheckedIn = false;
      _checkInAnchor = null;
      _checkedInUsers = [];
    });

    if (autoCheckedOut) {
      _showCheckInMessage('Moved 1 km away — checked out');
    } else {
      _showCheckInMessage('Checked out');
    }

    if (wasCheckedIn || _checkoutNeedsRetry) {
      _checkoutNeedsRetry = true;
      unawaited(_finalizeCheckOutOnServer());
    }
  }

  /// Waits for any in-flight check-in POST, then DELETE with retries.
  Future<void> _finalizeCheckOutOnServer() async {
    final pending = _persistCheckInFuture;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // Persist errors are handled inside _persistCheckIn.
      }
    }

    const maxAttempts = 3;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted) return;
      try {
        await _checkInApi.checkOut();
        _checkoutNeedsRetry = false;
        return;
      } catch (_) {
        if (attempt < maxAttempts - 1) {
          await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        }
      }
    }
    // Leave _checkoutNeedsRetry true so location ticks can retry.
  }

  Future<void> _retryCheckoutIfNeeded() async {
    if (!_checkoutNeedsRetry || _isCheckedIn) return;
    await _finalizeCheckOutOnServer();
  }

  /// Starts continuous GPS updates for the lifetime of this map (logged-in shell).
  void _startLocationTracking() {
    if (_positionSub != null) return;

    _positionSub = LocationService.getPositionStream().listen(
      _onPositionUpdate,
      onError: (_) {},
    );
  }

  void _stopLocationTracking() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  void _startCheckInPolling() {
    _stopCheckInPolling();
    _checkInPollCount = 0;
    _checkInPollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _onCheckInPollTick(),
    );
  }

  void _stopCheckInPolling() {
    _checkInPollTimer?.cancel();
    _checkInPollTimer = null;
    _checkInPollCount = 0;
  }

  Future<void> _onCheckInPollTick() async {
    if (_checkoutNeedsRetry && !_isCheckedIn) {
      await _retryCheckoutIfNeeded();
      return;
    }
    if (!_isCheckedIn) return;

    _checkInPollCount++;
    await _loadCheckedInUsers();

    // Every Nth poll, confirm the server still considers us checked in.
    if (_checkInPollCount % _statusReconcileEveryNPolls == 0) {
      await _reconcileCheckInStatusWithServer();
    }
  }

  Future<void> _reconcileCheckInStatusWithServer() async {
    final epoch = _checkInEpoch;
    if (!_isCheckedIn) return;
    try {
      final status = await _checkInApi.getCheckInStatus();
      if (!mounted || epoch != _checkInEpoch || !_isCheckedIn) return;
      if (!status.checkedIn) {
        _checkInGraceUntil = null;
        _stopCheckInPolling();
        setState(() {
          _isCheckedIn = false;
          _checkInAnchor = null;
          _checkedInUsers = [];
        });
      }
    } catch (_) {
      // Keep local state on transient failures.
    }
  }

  bool _shouldSkipLocalAutoCheckout(Position position) {
    final graceUntil = _checkInGraceUntil;
    if (graceUntil != null && DateTime.now().isBefore(graceUntil)) {
      return true;
    }
    if (position.accuracy > _autoCheckoutMaxAccuracyMeters) {
      return true;
    }
    return false;
  }

  Future<void> _onPositionUpdate(Position position) async {
    final location = LatLng(position.latitude, position.longitude);

    if (mounted) {
      setState(() => _userLocation = location);
    }

    if (_checkoutNeedsRetry && !_isCheckedIn) {
      unawaited(_retryCheckoutIfNeeded());
    }

    // Check-in auto-checkout and live check-in location sharing.
    if (_isCheckedIn &&
        _checkInAnchor != null &&
        !_shouldSkipLocalAutoCheckout(position)) {
      final distanceKm =
          LocationService.distanceKm(_checkInAnchor!, location);

      if (distanceKm >= checkInAutoCheckoutRadiusKm) {
        _performCheckOut(autoCheckedOut: true);
        return;
      }
    }

    final now = DateTime.now();
    final shouldPush = _lastLocationPushAt == null ||
        now.difference(_lastLocationPushAt!) >= const Duration(seconds: 15) ||
        _lastPushedLocation == null ||
        LocationService.distanceKm(_lastPushedLocation!, location) >= 0.025;

    if (!shouldPush) return;

    _lastLocationPushAt = now;
    _lastPushedLocation = location;

    // Always share map location while logged in and tracking.
    try {
      await _mapApi.updateLocation(
        latitude: location.latitude,
        longitude: location.longitude,
      );
    } catch (_) {
      // Best-effort map location updates.
    }

    if (!_isCheckedIn) return;

    try {
      final result = await _checkInApi.updateCheckInLocation(
        latitude: location.latitude,
        longitude: location.longitude,
      );

      if (result.autoCheckedOut) {
        _performCheckOut(autoCheckedOut: true);
      }
    } catch (_) {
      // Best-effort live check-in updates.
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
      showSparkSnackBar(
        context,
        "Couldn't start the conversation. Try again.",
      );
    } finally {
      if (mounted) setState(() => _isStartingConversation = false);
    }
  }

  @override
  void dispose() {
    _statusMessageTimer?.cancel();
    _stopCheckInPolling();
    _stopLocationTracking();
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
              if (_isCheckedIn && _showIndividualMarkers)
                MarkerLayer(
                  markers: [
                    for (final user in _checkedInUsers)
                      Marker(
                        point: LatLng(user.latitude, user.longitude),
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        child: _NearbyUserMarker(
                          user: user,
                          onTap: () => _showUserDetails(user),
                          showLiveBadge: true,
                        ),
                      ),
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
          else if (_checkInMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _StatusPill(
                icon: _isCheckedIn
                    ? Icons.location_on
                    : Icons.location_off_outlined,
                label: _checkInMessage!,
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
                  icon: _isCheckedIn
                      ? Icons.location_on
                      : Icons.location_on_outlined,
                  isPrimary: _isCheckedIn,
                  onPressed: _toggleCheckIn,
                ),
                const SizedBox(height: 10),
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
  final VoidCallback? onPressed;
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
  const _NearbyUserMarker({
    required this.user,
    required this.onTap,
    this.showLiveBadge = false,
  });

  final MapUserModel user;
  final VoidCallback onTap;
  final bool showLiveBadge;

  @override
  Widget build(BuildContext context) {
    final heatColor = similarityHeatColor(user.similarity);
    final initial = user.name.trim().isNotEmpty
        ? user.name.trim()[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: showLiveBadge
            ? '${user.name} · checked in live'
            : '${user.name} · ${(user.similarity * 100).round()}% match',
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
                        (showLiveBadge ? SparkColors.accent : heatColor)
                            .withValues(alpha: 0.65),
                        (showLiveBadge ? SparkColors.accent : heatColor)
                            .withValues(alpha: 0.0),
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
                    border: Border.all(
                      color: showLiveBadge ? SparkColors.accent : heatColor,
                      width: 2.5,
                    ),
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
                if (showLiveBadge)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SparkColors.accent,
                        border: Border.all(color: Colors.white, width: 1.5),
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
