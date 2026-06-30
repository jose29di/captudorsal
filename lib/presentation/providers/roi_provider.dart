import 'package:flutter/material.dart';
import '../../core/config/state_persistence.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';

class RoiConfig {
  final double widthPercent;
  final double heightPercent;
  final double topPercent;
  final double leftPercent;

  const RoiConfig({
    required this.widthPercent,
    required this.heightPercent,
    required this.topPercent,
    required this.leftPercent,
  });

  RoiConfig copyWith({
    double? widthPercent,
    double? heightPercent,
    double? topPercent,
    double? leftPercent,
  }) {
    return RoiConfig(
      widthPercent: widthPercent ?? this.widthPercent,
      heightPercent: heightPercent ?? this.heightPercent,
      topPercent: topPercent ?? this.topPercent,
      leftPercent: leftPercent ?? this.leftPercent,
    );
  }

  static const RoiConfig defaultConfig = RoiConfig(
    widthPercent: AppConstants.roiWidthPercent,
    heightPercent: AppConstants.roiHeightPercent,
    topPercent: 0.40,
    leftPercent: 0.35,
  );
}

class RoiProvider extends ChangeNotifier {
  final StatePersistence _statePersistence;
  final AppLogger _logger = AppLogger();

  RoiConfig _config = RoiConfig.defaultConfig;
  bool _isEditing = false;
  DateTime? _lastGestureUpdate;

  RoiProvider({required StatePersistence statePersistence})
      : _statePersistence = statePersistence;

  RoiConfig get config => _config;
  bool get isEditing => _isEditing;

  void initialize() {
    final saved = _statePersistence.loadRoiConfig();
    _config = RoiConfig(
      widthPercent: saved.widthPercent,
      heightPercent: saved.heightPercent,
      topPercent: saved.topPercent,
      leftPercent: saved.leftPercent,
    );
    _logger.info('ROI config loaded: ${_config.widthPercent}x${_config.heightPercent}');
    notifyListeners();
  }

  void setEditing(bool editing) {
    debugPrint('[RoiProvider] setEditing: $editing');
    _isEditing = editing;
    notifyListeners();
    debugPrint('[RoiProvider] setEditing done, notifyListeners called');
  }

  void updateWidth(double percent) {
    _config = _config.copyWith(
      widthPercent: percent.clamp(AppConstants.minRoiWidthPercent, AppConstants.maxRoiWidthPercent),
    );
    notifyListeners();
  }

  void updateHeight(double percent) {
    _config = _config.copyWith(
      heightPercent: percent.clamp(AppConstants.minRoiHeightPercent, AppConstants.maxRoiHeightPercent),
    );
    notifyListeners();
  }

  void updatePosition({double? topPercent, double? leftPercent}) {
    _config = _config.copyWith(
      topPercent: topPercent?.clamp(0.0, 0.9),
      leftPercent: leftPercent?.clamp(0.0, 0.9),
    );
    notifyListeners();
  }

  void updateFromGesture(DragUpdateDetails details, Size screenSize) {
    final dx = details.delta.dx / screenSize.width;
    final dy = details.delta.dy / screenSize.height;

    _config = _config.copyWith(
      leftPercent: (_config.leftPercent + dx).clamp(0.0, 0.9 - _config.widthPercent),
      topPercent: (_config.topPercent + dy).clamp(0.0, 0.9 - _config.heightPercent),
    );

    final now = DateTime.now();
    if (_lastGestureUpdate == null || now.difference(_lastGestureUpdate!).inMilliseconds >= 16) {
      _lastGestureUpdate = now;
      notifyListeners();
    }
  }

  Future<void> save() async {
    await _statePersistence.saveRoiConfig(
      widthPercent: _config.widthPercent,
      heightPercent: _config.heightPercent,
      topPercent: _config.topPercent,
      leftPercent: _config.leftPercent,
    );
    _isEditing = false;
    notifyListeners();
    _logger.info('ROI config saved');
  }

  void reset() {
    _config = RoiConfig.defaultConfig;
    notifyListeners();
  }
}
