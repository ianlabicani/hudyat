import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Draws a Material icon as a PNG for the map, with a white edge so it stays
/// readable over roads and water. The map takes images, not icon fonts.
Future<Uint8List> renderMapIcon(
  IconData icon, {
  required Color color,
  required double size,
  required double pixelRatio,
}) async {
  const edge = 2.0;
  final side = size + edge * 2;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);

  void paintGlyph(Paint paint) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          height: 1,
          foreground: paint,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((side - painter.width) / 2, (side - painter.height) / 2),
    );
    painter.dispose();
  }

  paintGlyph(
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = edge * 2
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white,
  );
  paintGlyph(Paint()..color = color);

  final pixels = (side * pixelRatio).ceil();
  final picture = recorder.endRecording();
  final image = await picture.toImage(pixels, pixels);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return data!.buffer.asUint8List();
}
