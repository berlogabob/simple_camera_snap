import 'package:hand_landmarker/hand_landmarker.dart';

enum GestureStatus { empty, warmup, thumbsUp, thumbsDown }

class GestureRecognizer {
  static const int requiredStableFrames = 10;

  GestureStatus recognize(List<Landmark> landmarks) {
    if (landmarks.length < 21) {
      return GestureStatus.warmup;
    }

    final Landmark thumbTip = landmarks[4];
    final Landmark indexTip = landmarks[8];
    final Landmark wrist = landmarks[0];

    // Расстояние от кончика большого пальца до запястья (в нормированных координатах)
    final double thumbToWrist = (thumbTip.x - wrist.x).abs() + (thumbTip.y - wrist.y).abs();

    // Если большой палец близко к запястью — считаем, что жест неопределённый (кулак или просто рука)
    if (thumbToWrist < 0.1) {
      return GestureStatus.warmup;
    }

    // Сравниваем высоту кончика большого и указательного пальцев
    final double yDiff = thumbTip.y - indexTip.y;

    if (yDiff > 0.05) {
      return GestureStatus.thumbsUp;
    } else if (yDiff < -0.05) {
      return GestureStatus.thumbsDown;
    } else {
      return GestureStatus.warmup;
    }
  }

  /// Возвращает текущий стабильный жест и координаты (для эмодзи)
  /// candidateX/Y — координаты указательного пальца (index tip)
  GestureStatus updateStableGesture({
    required GestureStatus candidate,
    required GestureStatus current,
    required int stableCount,
    required double candidateX,
    required double candidateY,
    required List<Landmark> candidateLandmarks,
    required Function(GestureStatus status, double x, double y, List<Landmark> landmarks) onStable,
  }) {
    int newStableCount = candidate == current ? stableCount + 1 : 1;

    if (newStableCount >= requiredStableFrames) {
      onStable(candidate, candidateX, candidateY, candidateLandmarks);
      return candidate;
    }

    return current;
  }
}