import 'package:flutter/material.dart';
import '../../core/config/state_persistence.dart';
import '../../core/utils/logger.dart';
import '../../platform/services/ocr_isolate.dart';

class DorsalConfig {
  final int minDigits;
  final int maxDigits;

  const DorsalConfig({
    required this.minDigits,
    required this.maxDigits,
  });

  DorsalConfig copyWith({int? minDigits, int? maxDigits}) {
    return DorsalConfig(
      minDigits: minDigits ?? this.minDigits,
      maxDigits: maxDigits ?? this.maxDigits,
    );
  }

  static const DorsalConfig defaultConfig = DorsalConfig(
    minDigits: 1,
    maxDigits: 4,
  );

  bool isValidDorsal(String dorsal) {
    final digitsOnly = dorsal.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return false;
    return digitsOnly.length >= minDigits && digitsOnly.length <= maxDigits;
  }

  String get description => '$minDigits-$maxDigits dígitos';
}

class DorsalProvider extends ChangeNotifier {
  final StatePersistence _statePersistence;
  final AppLogger _logger = AppLogger();

  DorsalConfig _config = DorsalConfig.defaultConfig;

  DorsalProvider({required StatePersistence statePersistence})
      : _statePersistence = statePersistence;

  DorsalConfig get config => _config;

  void initialize() {
    final saved = _statePersistence.loadDorsalConfig();
    _config = DorsalConfig(
      minDigits: saved.minDigits,
      maxDigits: saved.maxDigits,
    );
    OcrIsolate.updateDigitConfig(minDigits: _config.minDigits, maxDigits: _config.maxDigits);
    _logger.info('Dorsal config loaded: ${_config.description}');
    notifyListeners();
  }

  void updateMinDigits(int value) {
    _config = _config.copyWith(minDigits: value);
    if (_config.minDigits > _config.maxDigits) {
      _config = _config.copyWith(maxDigits: _config.minDigits);
    }
    OcrIsolate.updateDigitConfig(minDigits: _config.minDigits, maxDigits: _config.maxDigits);
    notifyListeners();
  }

  void updateMaxDigits(int value) {
    _config = _config.copyWith(maxDigits: value);
    if (_config.maxDigits < _config.minDigits) {
      _config = _config.copyWith(minDigits: _config.maxDigits);
    }
    OcrIsolate.updateDigitConfig(minDigits: _config.minDigits, maxDigits: _config.maxDigits);
    notifyListeners();
  }

  Future<void> save() async {
    await _statePersistence.saveDorsalConfig(
      minDigits: _config.minDigits,
      maxDigits: _config.maxDigits,
    );
    _logger.info('Dorsal config saved: ${_config.description}');
  }

  void reset() {
    _config = DorsalConfig.defaultConfig;
    OcrIsolate.updateDigitConfig(minDigits: _config.minDigits, maxDigits: _config.maxDigits);
    notifyListeners();
  }

  bool isValidDorsal(String text) => _config.isValidDorsal(text);
}
