import 'package:flutter/services.dart';
import '../../core/utils/logger.dart';

class BeepService {
  static const _channel = MethodChannel('com.codevnexus.captudorsal/sound');
  final AppLogger _logger = AppLogger();

  Future<void> initialize() async {
    _logger.info('BeepService initialized (native)');
  }

  Future<void> beep({double frequency = 1000, int durationMs = 150}) async {
    try {
      await _channel.invokeMethod('beep', {'duration': durationMs});
    } catch (e) {
      _logger.error('Beep error: $e');
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  Future<void> doubleBeep({double frequency = 1000, int durationMs = 120}) async {
    try {
      await _channel.invokeMethod('doubleBeep', {'duration': durationMs});
    } catch (e) {
      _logger.error('Double beep error: $e');
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  void dispose() {
    _logger.info('BeepService disposed');
  }
}
