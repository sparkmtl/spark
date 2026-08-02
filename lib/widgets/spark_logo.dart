import 'package:flutter/material.dart';

import '../theme/spark_colors.dart';

/// Yellow chat-bubble mark with a black lightning bolt — matches the Spark brand icon.
class SparkLogo extends StatelessWidget {
  const SparkLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SparkLogoPainter()),
    );
  }
}

class _SparkLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bubble = Path()
      ..moveTo(w * 0.22, h * 0.08)
      ..cubicTo(w * 0.08, h * 0.08, w * 0.05, h * 0.22, w * 0.05, h * 0.36)
      ..cubicTo(w * 0.05, h * 0.58, w * 0.12, h * 0.72, w * 0.28, h * 0.78)
      ..lineTo(w * 0.14, h * 0.96)
      ..quadraticBezierTo(w * 0.34, h * 0.9, w * 0.42, h * 0.8)
      ..cubicTo(w * 0.72, h * 0.86, w * 0.95, h * 0.7, w * 0.95, h * 0.4)
      ..cubicTo(w * 0.95, h * 0.16, w * 0.78, h * 0.08, w * 0.55, h * 0.08)
      ..close();

    canvas.drawPath(
      bubble,
      Paint()
        ..color = SparkColors.accent
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    final bolt = Path()
      ..moveTo(w * 0.58, h * 0.18)
      ..lineTo(w * 0.36, h * 0.46)
      ..lineTo(w * 0.5, h * 0.46)
      ..lineTo(w * 0.4, h * 0.72)
      ..lineTo(w * 0.66, h * 0.4)
      ..lineTo(w * 0.52, h * 0.4)
      ..close();

    canvas.drawPath(
      bolt,
      Paint()
        ..color = SparkColors.onAccent
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
