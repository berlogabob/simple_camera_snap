import 'package:flutter/material.dart';

class DetectionControls extends StatelessWidget {
  final bool isDetecting;
  final VoidCallback onToggle;

  const DetectionControls({
    super.key,
    required this.isDetecting,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
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
    );
  }
}