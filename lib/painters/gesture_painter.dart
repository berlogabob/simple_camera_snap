import 'package:flutter/material.dart';
import '../utils/constants.dart';

class GesturePainter extends CustomPainter {
  final String emoji;
  final double x;
  final double y;
  final Color color;

  GesturePainter(this.emoji, this.x, this.y, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      fontSize: AppConstants.emojiSize,
      color: color,
      shadows: const [
        Shadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 8),
      ],
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(text: emoji, style: textStyle);
    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant GesturePainter oldDelegate) {
    return oldDelegate.emoji != emoji ||
        oldDelegate.x != x ||
        oldDelegate.y != y ||
        oldDelegate.color != color;
  }
}