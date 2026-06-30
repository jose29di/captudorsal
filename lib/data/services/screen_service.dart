import 'package:flutter/services.dart';
import '../../core/utils/logger.dart';

class ScreenService {
  static const _channel = MethodChannel('com.codevnexus.captudorsal/screen');
  final AppLogger _logger = AppLogger();
  bool _isDimmed = false;

  bool get isDimmed => _isDimmed;

  Future<void> dimScreen() async {
    try {
      await _channel.invokeMethod('dimScreen');
      _isDimmed = true;
      _logger.info('Screen dimmed to minimum brightness');
    } catch (e) {
      _logger.error('Failed to dim screen', e);
    }
  }

  Future<void> restoreBrightness() async {
    try {
      await _channel.invokeMethod('restoreBrightness');
      _isDimmed = false;
      _logger.info('Screen brightness restored');
    } catch (e) {
      _logger.error('Failed to restore brightness', e);
    }
  }

  Future<void> toggle() async {
    if (_isDimmed) {
      await restoreBrightness();
    } else {
      await dimScreen();
    }
  }
}
