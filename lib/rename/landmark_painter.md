import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

class LandmarkPainter extends CustomPainter {
  final List<Landmark> landmarks;
  final Size screenSize;
  final int sensorOrientation;
  final int debugMode;

  LandmarkPainter(this.landmarks, this.screenSize, this.sensorOrientation, this.debugMode);

  Offset _transform(double x, double y) {
    double tx = x;
    double ty = y;

    if (sensorOrientation == 270) {
      tx = y;
      ty = x;
    } else if (sensorOrientation == 90) {
      tx = 1.0 - y;
      ty = x;
    }

    switch (debugMode) {
      case 0:
        break;
      case 1:
        final double temp = tx;
        tx = ty;
        ty = 1.0 - temp;
        break;
      case 2:
        final double temp = tx;
        tx = 1.0 - ty;
        ty = temp;
        break;
      case 3:
        tx = 1.0 - tx;
        ty = 1.0 - ty;
        break;
    }

    return Offset(tx * screenSize.width, ty * screenSize.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.grey.withAlpha(153)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final connections = [
      [0, 1], [1, 2], [2, 3], [3, 4],
      [0, 5], [5, 6], [6, 7], [7, 8],
      [0, 9], [9, 10], [10, 11], [11, 12],
      [0, 13], [13, 14], [14, 15], [15, 16],
      [0, 17], [17, 18], [18, 19], [19, 20],
      [5, 9], [9, 13], [13, 17]
    ];

    for (final conn in connections) {
      final p1 = landmarks[conn[0]];
      final p2 = landmarks[conn[1]];
      canvas.drawLine(_transform(p1.x, p1.y), _transform(p2.x, p2.y), linePaint);
    }

    for (int i = 0; i < landmarks.length; i++) {
      final lm = landmarks[i];
      final Offset tp = _transform(lm.x, lm.y);
      dotPaint.color = (i == 4) ? Colors.blue : (i == 8) ? Colors.red : Colors.grey;
      canvas.drawCircle(tp, 8, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LandmarkPainter old) => true;
}