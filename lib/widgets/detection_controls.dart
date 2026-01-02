import 'package:flutter/material.dart';

class DetectionControls extends StatelessWidget {
  final bool isDetecting;
  final VoidCallback onToggle;
  final VoidCallback onCycleTransform;
  final VoidCallback onCycleDebug;
  final int transformMode;
  final int debugMode;

  const DetectionControls({
    super.key,
    required this.isDetecting,
    required this.onToggle,
    required this.onCycleTransform,
    required this.onCycleDebug,
    required this.transformMode,
    required this.debugMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onCycleTransform,
          child: Container(
            color: Colors.black.withAlpha(153),
            padding: const EdgeInsets.symmetric(vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            child: Text(
              'Mode: $transformMode (auto • tap to override)',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onCycleDebug,
          child: Container(
            color: Colors.black.withAlpha(153),
            padding: const EdgeInsets.symmetric(vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            child: Text(
              debugMode == 0
                  ? 'Gesture: AUTO'
                  : debugMode == 1
                      ? 'Gesture: FORCE 👍'
                      : debugMode == 2
                          ? 'Gesture: FORCE 👎'
                          : 'Gesture: FORCE WARMUP',
              style: const TextStyle(color: Colors.orange, fontSize: 16),
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(30.0),
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: onToggle,
              child: Text(
                isDetecting ? 'Stop Detecting' : 'Start Detecting',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}