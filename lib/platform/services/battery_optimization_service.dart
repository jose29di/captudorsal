import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/utils/logger.dart';

class BatteryOptimizationService {
  static const MethodChannel _channel = MethodChannel('com.codevnexus.captudorsal/battery');
  final AppLogger _logger = AppLogger();

  bool _isExempted = false;
  bool get isExempted => _isExempted;

  Future<bool> requestExemption() async {
    try {
      final result = await _channel.invokeMethod('requestBatteryOptimizationExemption');
      _isExempted = result == true;
      if (_isExempted) {
        _logger.info('Battery optimization exemption granted');
      } else {
        _logger.warning('Battery optimization exemption denied');
      }
      return _isExempted;
    } catch (e) {
      _logger.error('Failed to request battery optimization exemption', e);
      return false;
    }
  }

  Future<bool> isBatteryOptimizationEnabled() async {
    try {
      final result = await _channel.invokeMethod('isBatteryOptimizationEnabled');
      return result == true;
    } catch (e) {
      _logger.error('Failed to check battery optimization status', e);
      return false;
    }
  }
}
