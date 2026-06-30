import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/utils/logger.dart';

class WakeLockService {
  bool _isActive = false;
  final AppLogger _logger = AppLogger();

  bool get isActive => _isActive;

  Future<void> activate() async {
    if (_isActive) return;
    try {
      await WakelockPlus.enable();
      _isActive = true;
      _logger.info('Wake lock activated');
    } catch (e) {
      _logger.error('Failed to activate wake lock', e);
    }
  }

  Future<void> deactivate() async {
    if (!_isActive) return;
    try {
      await WakelockPlus.disable();
      _isActive = false;
      _logger.info('Wake lock deactivated');
    } catch (e) {
      _logger.error('Failed to deactivate wake lock', e);
    }
  }

  Future<void> toggle() async {
    if (_isActive) {
      await deactivate();
    } else {
      await activate();
    }
  }
}
