class GestureThresholds {
  static const double okThumbIndexDist = 0.10;
  static const double okExtendedFingerDist = 0.15;
  static const double foldedFingerDist = 0.12;
  static const double minThumbLength = 0.15;
  static const double thumbsUpXDiff = 0.055;
  static const double thumbsDownXDiff = -0.055;
  static const double thumbsUpYDiff = -0.08;
  static const double thumbsDownYDiff = 0.08;
}

class AppConstants {
  static const int requiredStableFrames = 10;
  static const int frameSkipCount = 1;
  static const double gestureYOffset = -20.0;
  static const double emojiSize = 150.0;
  static const double landmarkDotRadius = 8.0;
}