import 'package:hand_landmarker/hand_landmarker.dart';

enum GestureStatus { empty, warmup, thumbsUp, thumbsDown }

class GestureRecognizer {
  static const int requiredStableFrames = 10;

  GestureStatus recognize(List<Landmark> landmarks, int transformMode) {
    if (landmarks.length < 21) {
      return GestureStatus.warmup;
    }

    final Landmark thumbTip = landmarks[4];
    final Landmark indexMcp = landmarks[5];
    final Landmark middleMcp = landmarks[9];
    final Landmark ringMcp = landmarks[13];
    final Landmark pinkyMcp = landmarks[17];
    final Landmark wrist = landmarks[0];

    // Проверка, что остальные пальцы сложены
    bool areOtherFingersFolded = true;
    final List<int> tips = [8, 12, 16, 20];
    final List<int> mcps = [5, 9, 13, 17];

    for (int i = 0; i < tips.length; i++) {
      final double dist = (landmarks[tips[i]].y - landmarks[mcps[i]].y).abs() +
                          (landmarks[tips[i]].x - landmarks[mcps[i]].x).abs();
      if (dist > 0.15) {
        areOtherFingersFolded = false;
        break;
      }
    }

    if (!areOtherFingersFolded) {
      return GestureStatus.warmup;
    }

    final double thumbLength = (thumbTip.x - wrist.x).abs() + (thumbTip.y - wrist.y).abs();
    if (thumbLength < 0.15) {
      return GestureStatus.warmup;
    }

    GestureStatus detected;

    if (transformMode == 3) {
      // Portrait up — используем xDiff (из-за поворота осей камерой)
      final double xDiff = thumbTip.x - indexMcp.x;
      if (xDiff > 0.06) { // большой вправо = thumbsUp (вверх)
        detected = GestureStatus.thumbsUp;
      } else if (xDiff < -0.05) { // большой влево = thumbsDown (вниз)
        detected = GestureStatus.thumbsDown;
      } else {
        return GestureStatus.warmup;
      }
    } else {
      // Для landscape — стандартная проверка по yDiff
      final double yDiff = thumbTip.y - indexMcp.y;
      if (yDiff < -0.08) {
        detected = GestureStatus.thumbsUp;
      } else if (yDiff > 0.08) {
        detected = GestureStatus.thumbsDown;
      } else {
        return GestureStatus.warmup;
      }
    }

    // Инверсия только для Mode 1 (landscape right)
    if (transformMode == 1) {
      return detected == GestureStatus.thumbsUp
          ? GestureStatus.thumbsDown
          : GestureStatus.thumbsUp;
    }

    return detected;
  }
}