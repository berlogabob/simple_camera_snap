import 'package:hand_landmarker/hand_landmarker.dart';
import '../models/gesture_status.dart';
import 'constants.dart';

class GestureRecognizer {
  GestureStatus recognize(List<Landmark> landmarks, int transformMode) {
    if (landmarks.length < 21) return GestureStatus.warmup;

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

    // OK gesture – priority
    final thumbIndexDist = (thumbTip.x - indexTip.x).abs() + (thumbTip.y - indexTip.y).abs();
    final middleDist = (middleTip.y - middleMcp.y).abs() + (middleTip.x - middleMcp.x).abs();
    final ringDist = (ringTip.y - ringMcp.y).abs() + (ringTip.x - ringMcp.x).abs();
    final pinkyDist = (pinkyTip.y - pinkyMcp.y).abs() + (pinkyTip.x - pinkyMcp.x).abs();

    if (thumbIndexDist < GestureThresholds.okThumbIndexDist &&
        middleDist > GestureThresholds.okExtendedFingerDist &&
        ringDist > GestureThresholds.okExtendedFingerDist &&
        pinkyDist > GestureThresholds.okExtendedFingerDist) {
      return GestureStatus.ok;
    }

    // Check other 4 fingers are folded
    final tips = [8, 12, 16, 20];
    final mcps = [5, 9, 13, 17];
    bool folded = true;
    for (int i = 0; i < tips.length; i++) {
      final dist = (landmarks[tips[i]].y - landmarks[mcps[i]].y).abs() +
          (landmarks[tips[i]].x - landmarks[mcps[i]].x).abs();
      if (dist > GestureThresholds.foldedFingerDist) {
        folded = false;
        break;
      }
    }
    if (!folded) return GestureStatus.warmup;

    final thumbLength = (thumbTip.x - wrist.x).abs() + (thumbTip.y - wrist.y).abs();
    if (thumbLength < GestureThresholds.minThumbLength) return GestureStatus.warmup;

    GestureStatus detected;
    if (transformMode == 3) {
      final xDiff = thumbTip.x - indexMcp.x;
      if (xDiff > GestureThresholds.thumbsUpXDiff) {
        detected = GestureStatus.thumbsUp;
      } else if (xDiff < GestureThresholds.thumbsDownXDiff) {
        detected = GestureStatus.thumbsDown;
      } else {
        return GestureStatus.warmup;
      }
    } else {
      final yDiff = thumbTip.y - indexMcp.y;
      if (yDiff < GestureThresholds.thumbsUpYDiff) {
        detected = GestureStatus.thumbsUp;
      } else if (yDiff > GestureThresholds.thumbsDownYDiff) {
        detected = GestureStatus.thumbsDown;
      } else {
        return GestureStatus.warmup;
      }
    }

    if (transformMode == 1) {
      return detected == GestureStatus.thumbsUp ? GestureStatus.thumbsDown : GestureStatus.thumbsUp;
    }

    return detected;
  }
}