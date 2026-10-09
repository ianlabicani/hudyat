import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A white box with a dashed border. Dashed means optional, AI-written or
/// locked content, and nothing else (spec 5.4).
class DashedPanel extends StatelessWidget {
  const DashedPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedBorderPainter(),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      const Radius.circular(6),
    );
    canvas.drawRRect(box, Paint()..color = HudyatColors.surface);
    final stroke = Paint()
      ..color = HudyatColors.muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in (Path()..addRRect(box)).computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += _dash + _gap) {
        canvas.drawPath(metric.extractPath(at, at + _dash), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}
