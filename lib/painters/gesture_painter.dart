import 'package:flutter/material.dart';

class GesturePainter extends CustomPainter {
  final String emoji;
  final double x;
  final double y;
  final Color color;

  GesturePainter(this.emoji, this.x, this.y, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final TextStyle style = TextStyle(
      fontSize: 150,
      color: color,
      shadows: const [Shadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 8)],
    );
    final TextPainter tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(text: emoji, style: style);
    tp.layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GesturePainter old) => true;
}