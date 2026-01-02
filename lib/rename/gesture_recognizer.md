import 'package:hand_landmarker/hand_landmarker.dart';

enum GestureStatus { empty, warmup, thumbsUp, thumbsDown, ok }

class GestureRecognizer {
  static const int requiredStableFrames = 10;

  GestureStatus recognize(List<Landmark> landmarks, int transformMode) {
    if (landmarks.length < 21) {
      return GestureStatus.warmup;
    }

    final thumbTip = landmarks[4];
    final indexTip = landmarks[8];
    final indexMcp = landmarks[5];
    final middleTip = landmarks[12];
    final ringTip = landmarks[16];
    final pinkyTip = landmarks[20];
    final middleMcp = landmarks[9];
    final ringMcp = landmarks[13];
    final pinkyMcp = landmarks[17];
    final wrist = landmarks[0];

    // === OK 👌 — проверка в первую очередь (большой и указательный близко, остальные вытянуты) ===
    final thumbIndexDist = (thumbTip.x - indexTip.x).abs() + (thumbTip.y - indexTip.y).abs();
    final middleDist = (middleTip.y - middleMcp.y).abs() + (middleTip.x - middleMcp.x).abs();
    final ringDist = (ringTip.y - ringMcp.y).abs() + (ringTip.x - ringMcp.x).abs();
    final pinkyDist = (pinkyTip.y - pinkyMcp.y).abs() + (pinkyTip.x - pinkyMcp.x).abs();

    if (thumbIndexDist < 0.1 && middleDist > 0.15 && ringDist > 0.15 && pinkyDist > 0.15) {
      return GestureStatus.ok;
    }

    // === Thumbs 👍 / 👎 — только если OK не сработал ===
    // Проверка, что остальные 4 пальца сложены в кулак
    bool areOtherFingersFolded = true;
    final tips = [8, 12, 16, 20];
    final mcps = [5, 9, 13, 17];

    for (int i = 0; i < tips.length; i++) {
      final dist = (landmarks[tips[i]].y - landmarks[mcps[i]].y).abs() +
                   (landmarks[tips[i]].x - landmarks[mcps[i]].x).abs();
      if (dist > 0.12) {
        areOtherFingersFolded = false;
        break;
      }
    }

    if (!areOtherFingersFolded) {
      return GestureStatus.warmup;
    }

    final thumbLength = (thumbTip.x - wrist.x).abs() + (thumbTip.y - wrist.y).abs();
    if (thumbLength < 0.15) {
      return GestureStatus.warmup;
    }

    GestureStatus detected;

    if (transformMode == 3) {
      final xDiff = thumbTip.x - indexMcp.x;
      if (xDiff > 0.06) {
        detected = GestureStatus.thumbsUp;
      } else if (xDiff < -0.05) {
        detected = GestureStatus.thumbsDown;
      } else {
        return GestureStatus.warmup;
      }
    } else {
      final yDiff = thumbTip.y - indexMcp.y;
      if (yDiff < -0.08) {
        detected = GestureStatus.thumbsUp;
      } else if (yDiff > 0.08) {
        detected = GestureStatus.thumbsDown;
      } else {
        return GestureStatus.warmup;
      }
    }

    if (transformMode == 1) {
      return detected == GestureStatus.thumbsUp
          ? GestureStatus.thumbsDown
          : GestureStatus.thumbsUp;
    }

    return detected;
  }
}