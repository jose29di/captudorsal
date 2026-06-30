import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';

class StatePersistence {
  static const String _keyRecords = 'detection_records';
  static const String _keyTotalDetections = 'total_detections';
  static const String _keyIsRecording = 'is_recording';
  static const String _keyLastSessionDate = 'last_session_date';

  SharedPreferences? _prefs;
  final AppLogger _logger = AppLogger();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _logger.info('StatePersistence initialized');
  }

  bool get isInitialized => _prefs != null;

  Future<void> saveDetectionRecords(List<Map<String, dynamic>> records) async {
    if (_prefs == null) return;
    try {
      final json = jsonEncode(records);
      await _prefs!.setString(_keyRecords, json);
      await _prefs!.setInt(_keyTotalDetections, records.length);
      await _prefs!.setString(_keyLastSessionDate, DateTime.now().toIso8601String());
    } catch (e) {
      _logger.error('Error saving records', e);
    }
  }

  List<Map<String, dynamic>> loadDetectionRecords() {
    if (_prefs == null) return [];
    try {
      final json = _prefs!.getString(_keyRecords);
      if (json == null) return [];
      final List<dynamic> decoded = jsonDecode(json);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      _logger.error('Error loading records', e);
      return [];
    }
  }

  Future<void> saveRecordingState(bool isRecording) async {
    if (_prefs == null) return;
    await _prefs!.setBool(_keyIsRecording, isRecording);
  }

  bool loadRecordingState() {
    if (_prefs == null) return false;
    return _prefs!.getBool(_keyIsRecording) ?? false;
  }

  int get totalDetections => _prefs?.getInt(_keyTotalDetections) ?? 0;

  String? get lastSessionDate => _prefs?.getString(_keyLastSessionDate);

  // ROI Configuration
  Future<void> saveRoiConfig({
    required double widthPercent,
    required double heightPercent,
    required double topPercent,
    required double leftPercent,
  }) async {
    if (_prefs == null) return;
    await _prefs!.setDouble(AppConstants.keyRoiWidthPercent, widthPercent);
    await _prefs!.setDouble(AppConstants.keyRoiHeightPercent, heightPercent);
    await _prefs!.setDouble(AppConstants.keyRoiTopPercent, topPercent);
    await _prefs!.setDouble(AppConstants.keyRoiLeftPercent, leftPercent);
    _logger.info('ROI config saved: ${widthPercent}x$heightPercent at ($leftPercent, $topPercent)');
  }

  ({double widthPercent, double heightPercent, double topPercent, double leftPercent}) loadRoiConfig() {
    if (_prefs == null) {
      return (
        widthPercent: AppConstants.roiWidthPercent,
        heightPercent: AppConstants.roiHeightPercent,
        topPercent: 0.40,
        leftPercent: 0.35,
      );
    }

    return (
      widthPercent: _prefs!.getDouble(AppConstants.keyRoiWidthPercent) ?? AppConstants.roiWidthPercent,
      heightPercent: _prefs!.getDouble(AppConstants.keyRoiHeightPercent) ?? AppConstants.roiHeightPercent,
      topPercent: _prefs!.getDouble(AppConstants.keyRoiTopPercent) ?? 0.40,
      leftPercent: _prefs!.getDouble(AppConstants.keyRoiLeftPercent) ?? 0.35,
    );
  }

  // Dorsal Configuration
  Future<void> saveDorsalConfig({
    required int minDigits,
    required int maxDigits,
  }) async {
    if (_prefs == null) return;
    await _prefs!.setInt(AppConstants.keyDorsalMinDigits, minDigits);
    await _prefs!.setInt(AppConstants.keyDorsalMaxDigits, maxDigits);
    _logger.info('Dorsal config saved: $minDigits-$maxDigits digits');
  }

  ({int minDigits, int maxDigits}) loadDorsalConfig() {
    if (_prefs == null) {
      return (minDigits: 1, maxDigits: 4);
    }

    return (
      minDigits: _prefs!.getInt(AppConstants.keyDorsalMinDigits) ?? 1,
      maxDigits: _prefs!.getInt(AppConstants.keyDorsalMaxDigits) ?? 4,
    );
  }

  // OCR Sensitivity Configuration
  Future<void> saveOcrSensitivity({
    required int throttleMs,
  }) async {
    if (_prefs == null) return;
    await _prefs!.setInt(AppConstants.keyThrottleMs, throttleMs);
    _logger.info('OCR sensitivity saved: throttle=${throttleMs}ms');
  }

  ({int throttleMs}) loadOcrSensitivity() {
    if (_prefs == null) {
      _logger.warning('SharedPreferences not initialized, returning defaults');
      return (throttleMs: AppConstants.baseThrottleMs);
    }

    try {
      final result = (
        throttleMs: _prefs!.getInt(AppConstants.keyThrottleMs) ?? AppConstants.baseThrottleMs,
      );
      _logger.info('OCR sensitivity loaded: throttle=${result.throttleMs}ms');
      return result;
    } catch (e) {
      _logger.error('Error loading OCR sensitivity', e);
      return (throttleMs: AppConstants.baseThrottleMs);
    }
  }

  Future<void> saveRequiredReads(int count) async {
    if (_prefs == null) return;
    await _prefs!.setInt(AppConstants.keyRequiredReads, count);
    _logger.info('Required reads saved: $count');
  }

  int loadRequiredReads() {
    if (_prefs == null) return AppConstants.defaultRequiredReads;
    try {
      return _prefs!.getInt(AppConstants.keyRequiredReads) ?? AppConstants.defaultRequiredReads;
    } catch (e) {
      return AppConstants.defaultRequiredReads;
    }
  }

  Future<void> clearAll() async {
    if (_prefs == null) return;
    await _prefs!.remove(_keyRecords);
    await _prefs!.remove(_keyTotalDetections);
    await _prefs!.remove(_keyIsRecording);
    await _prefs!.remove(_keyLastSessionDate);
    await _prefs!.remove(AppConstants.keyRoiWidthPercent);
    await _prefs!.remove(AppConstants.keyRoiHeightPercent);
    await _prefs!.remove(AppConstants.keyRoiTopPercent);
    await _prefs!.remove(AppConstants.keyRoiLeftPercent);
    await _prefs!.remove(AppConstants.keyDorsalMinDigits);
    await _prefs!.remove(AppConstants.keyDorsalMaxDigits);
    await _prefs!.remove(AppConstants.keyThrottleMs);
    await _prefs!.remove(AppConstants.keyRequiredReads);
    await _prefs!.remove(AppConstants.keySoundEnabled);
    _logger.info('State persistence cleared');
  }

  Future<void> saveSoundEnabled(bool enabled) async {
    if (_prefs == null) return;
    await _prefs!.setBool(AppConstants.keySoundEnabled, enabled);
    _logger.info('Sound enabled saved: $enabled');
  }

  bool loadSoundEnabled() {
    if (_prefs == null) return true;
    return _prefs!.getBool(AppConstants.keySoundEnabled) ?? true;
  }

  Future<void> saveKeepScreenOn(bool enabled) async {
    if (_prefs == null) return;
    await _prefs!.setBool(AppConstants.keyKeepScreenOn, enabled);
    _logger.info('Keep screen on saved: $enabled');
  }

  bool loadKeepScreenOn() {
    if (_prefs == null) return true;
    return _prefs!.getBool(AppConstants.keyKeepScreenOn) ?? true;
  }
}
