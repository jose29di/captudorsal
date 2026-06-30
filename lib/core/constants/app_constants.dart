class AppConstants {
  static const String appName = 'CaptuDorsal';
  static const String appVersion = '1.0.0';
  static const String packageName = 'com.codevnexus.captudorsal';

  static const int maxDorsalDigits = 6;
  static const int debounceTimeoutSeconds = 10;
  static const int maxOcrTextLength = 10;
  static const int csvFlushCount = 5;
  static const int csvFlushIntervalSeconds = 5;

  static const int baseThrottleMs = 500;
  static const int minThrottleMs = 100;
  static const int maxThrottleMs = 1500;
  static const int burstThrottleMs = 150;
  static const int burstCooldownMs = 2000;

  static const double roiWidthPercent = 0.50;
  static const double roiHeightPercent = 0.30;

  static const double minRoiWidthPercent = 0.10;
  static const double maxRoiWidthPercent = 0.90;
  static const double minRoiHeightPercent = 0.05;
  static const double maxRoiHeightPercent = 0.80;

  static const String keyRoiWidthPercent = 'roi_width_percent';
  static const String keyRoiHeightPercent = 'roi_height_percent';
  static const String keyRoiTopPercent = 'roi_top_percent';
  static const String keyRoiLeftPercent = 'roi_left_percent';

  static const String keyDorsalMinDigits = 'dorsal_min_digits';
  static const String keyDorsalMaxDigits = 'dorsal_max_digits';

  static const String keyThrottleMs = 'throttle_ms';
  static const String keyImageRotation = 'image_rotation';
  static const String keyRequiredReads = 'required_reads';
  static const int defaultRequiredReads = 2;
  static const String keySoundEnabled = 'sound_enabled';
  static const String keyKeepScreenOn = 'keep_screen_on';
}
