import 'package:flutter/material.dart';
import '../models/gesture_status.dart';

class StatusOverlay extends StatelessWidget {
  final GestureStatus status;

  const StatusOverlay(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case GestureStatus.empty:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.panorama_fish_eye, size: 100, color: Colors.grey),
            SizedBox(height: 20),
            Text('Show your hand', style: TextStyle(fontSize: 24, color: Colors.white)),
          ],
        );
      case GestureStatus.warmup:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.panorama_fish_eye, size: 100, color: Colors.yellow),
            SizedBox(height: 20),
            Text('Hand detected', style: TextStyle(fontSize: 24, color: Colors.white)),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}