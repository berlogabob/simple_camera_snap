import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import '../utils/transform_utils.dart';
import '../utils/constants.dart';

class LandmarkPainter extends CustomPainter {
  final List<Landmark> landmarks;
  final Size screenSize;
  final int sensorOrientation;
  final int transformMode;

  LandmarkPainter(this.landmarks, this.screenSize, this.sensorOrientation, this.transformMode);

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()..style = PaintingStyle.fill;

    final connections = [
      [0, 1], [1, 2], [2, 3], [3, 4],
      [0, 5], [5, 6], [6, 7], [7, 8],
      [0, 9], [9, 10], [10, 11], [11, 12],
      [0, 13], [13, 14], [14, 15], [15, 16],
      [0, 17], [17, 18], [18, 19], [19, 20],
      [5, 9], [9, 13], [13, 17],
    ];

    for (final conn in connections) {
      final p1 = landmarks[conn[0]];
      final p2 = landmarks[conn[1]];
      canvas.drawLine(
        transformLandmark(x: p1.x, y: p1.y, sensorOrientation: sensorOrientation, transformMode: transformMode, screenSize: screenSize),
        transformLandmark(x: p2.x, y: p2.y, sensorOrientation: sensorOrientation, transformMode: transformMode, screenSize: screenSize),
        linePaint,
      );
    }

    for (int i = 0; i < landmarks.length; i++) {
      final lm = landmarks[i];
      final pos = transformLandmark(x: lm.x, y: lm.y, sensorOrientation: sensorOrientation, transformMode: transformMode, screenSize: screenSize);

      if (i == 4) {
        dotPaint.color = Colors.cyanAccent;
        canvas.drawCircle(pos, 12, dotPaint);
      } else if (i == 8) {
        dotPaint.color = Colors.pinkAccent;
        canvas.drawCircle(pos, 12, dotPaint);
      } else {
        dotPaint.color = Colors.white;
        canvas.drawCircle(pos, AppConstants.landmarkDotRadius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LandmarkPainter old) => true;
}