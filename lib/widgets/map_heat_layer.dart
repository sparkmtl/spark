import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_user_model.dart';

/// Snap Map-style heat: screen-space glows that stay small when zoomed out.
/// Red is a tiny core on dense clusters only — zooming out never inflates it
/// into a continent-sized disc.
class MapHeatLayer extends StatelessWidget {
  const MapHeatLayer({super.key, required this.users});

  final List<MapUserModel> users;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    if (users.isEmpty || !camera.size.width.isFinite || camera.size.width <= 0) {
      return const SizedBox.shrink();
    }

    final glowRadius = _glowRadiusForZoom(camera.zoom);
    final pad = glowRadius * 2;
    final points = <Offset>[];
    for (final user in users) {
      final offset = camera.getOffsetFromOrigin(
        LatLng(user.latitude, user.longitude),
      );
      if (offset.dx < -pad ||
          offset.dy < -pad ||
          offset.dx > camera.size.width + pad ||
          offset.dy > camera.size.height + pad) {
        continue;
      }
      points.add(offset);
    }

    return MobileLayerTransformer(
      child: CustomPaint(
        size: camera.size,
        isComplex: true,
        painter: _HeatPainter(
          points: points,
          zoom: camera.zoom,
          glowRadius: glowRadius,
        ),
      ),
    );
  }
}

/// Screen pixels. Shrinks as you zoom out so a city stays a spec, not a blob.
double _glowRadiusForZoom(double zoom) {
  if (zoom <= 3) return 8;
  if (zoom <= 4) return 9;
  if (zoom <= 5) return 10;
  if (zoom <= 7) return 12;
  if (zoom <= 9) return 14;
  if (zoom <= 11) return 17;
  if (zoom <= 13) return 20;
  return 24;
}

class _HeatSpot {
  const _HeatSpot({required this.center, required this.count});
  final Offset center;
  final int count;
}

class _HeatPainter extends CustomPainter {
  _HeatPainter({
    required this.points,
    required this.zoom,
    required this.glowRadius,
  });

  final List<Offset> points;
  final double zoom;
  final double glowRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final cell = math.max(6.0, glowRadius * 0.55);
    for (final spot in _cluster(points, cell)) {
      _paintSpot(canvas, spot);
    }

    canvas.restore();
  }

  List<_HeatSpot> _cluster(List<Offset> pts, double cell) {
    final buckets = <(int, int), List<Offset>>{};
    for (final p in pts) {
      final key = ((p.dx / cell).floor(), (p.dy / cell).floor());
      buckets.putIfAbsent(key, () => []).add(p);
    }
    return [
      for (final group in buckets.values)
        _HeatSpot(
          center: Offset(
            group.fold<double>(0, (s, p) => s + p.dx) / group.length,
            group.fold<double>(0, (s, p) => s + p.dy) / group.length,
          ),
          count: group.length,
        ),
    ];
  }

  /// 1 person → faint cyan. Several in the same cell → hotter. Red only at
  /// the top of the ramp, and the core radius is capped when zoomed out.
  double _intensity(int count) {
    if (count <= 1) return 0.22;
    if (count == 2) return 0.40;
    if (count <= 4) return 0.62;
    if (count <= 7) return 0.82;
    return 1.0;
  }

  void _paintSpot(Canvas canvas, _HeatSpot spot) {
    final t = _intensity(spot.count);
    final center = spot.center;

    // Soft cyan (→ yellow) halo. Size is the glow radius, not geographic.
    _radial(
      canvas,
      center,
      glowRadius,
      Color.lerp(const Color(0x6626C6DA), const Color(0x88FFD54F), t)!,
      const Color(0x0026C6DA),
    );

    if (t >= 0.40) {
      _radial(
        canvas,
        center,
        glowRadius * 0.48,
        Color.lerp(const Color(0xAAFFD54F), const Color(0xCCFF9100), (t - 0.40) / 0.60)!,
        const Color(0x00FFD54F),
      );
    }

    if (t >= 0.82) {
      final coreCap = zoom <= 5 ? 3.5 : zoom <= 8 ? 5.0 : 8.0;
      final coreR = math.min(glowRadius * (zoom <= 5 ? 0.16 : 0.24), coreCap);
      _radial(
        canvas,
        center,
        coreR,
        const Color(0xF0FF2D2D),
        const Color(0x00FF2D2D),
      );
    }
  }

  void _radial(Canvas canvas, Offset center, double radius, Color inner, Color outer) {
    if (radius <= 0) return;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [inner, outer],
        const [0.0, 1.0],
      );
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _HeatPainter oldDelegate) {
    return oldDelegate.zoom != zoom ||
        oldDelegate.glowRadius != glowRadius ||
        oldDelegate.points.length != points.length ||
        !_samePoints(oldDelegate.points, points);
  }

  bool _samePoints(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).distanceSquared > 0.25) return false;
    }
    return true;
  }
}
