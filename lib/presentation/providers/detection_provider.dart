import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/detection_record.dart';
import '../../data/models/recording_session.dart';
import '../../data/repositories/detection_repository.dart';
import '../../data/services/beep_service.dart';
import '../../core/config/state_persistence.dart';
import '../../platform/services/ocr_isolate.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';

class DetectionProvider extends ChangeNotifier {
  final DetectionRepository _detectionRepository;
  final BeepService _beepService;
  final StatePersistence _statePersistence;
  final AppLogger _logger = AppLogger();

  final List<DetectionRecord> _records = [];
  final Map<String, DateTime> _debounceMap = {};
  final List<SessionDorsal> _sessionDorsals = [];
  int? _currentSessionId;
  DateTime? _currentSessionStart;

  bool _isLoading = false;
  bool _isProcessingFrame = false;
  String? _lastDetectedDorsal;
  DateTime? _lastDetectionTime;
  String? _lastRawText;
  final bool _autoSaveEnabled = true;

  int _requiredReads = 2;
  bool _soundEnabled = true;
  final Map<String, int> _consecutiveReads = {};

  List<DetectionRecord> get records => List.unmodifiable(_records);
  int get totalDetections => _records.length;
  bool get isLoading => _isLoading;
  bool get isProcessingFrame => _isProcessingFrame;
  String? get lastDetectedDorsal => _lastDetectedDorsal;
  DateTime? get lastDetectionTime => _lastDetectionTime;
  String? get lastRawText => _lastRawText;
  int get requiredReads => _requiredReads;
  bool get soundEnabled => _soundEnabled;
  int? get currentSessionId => _currentSessionId;
  List<SessionDorsal> get sessionDorsals => List.unmodifiable(_sessionDorsals);

  DetectionProvider({
    required DetectionRepository detectionRepository,
    required BeepService beepService,
    required StatePersistence statePersistence,
  })  : _detectionRepository = detectionRepository,
        _beepService = beepService,
        _statePersistence = statePersistence;

  void _safeNotify() {
    if (_disposed) return;
    Timer(const Duration(milliseconds: 50), () {
      if (!_disposed) notifyListeners();
    });
  }

  bool _disposed = false;

  Future<void> initialize() async {
    _isLoading = true;

    try {
      await OcrIsolate.start();

      _soundEnabled = _statePersistence.loadSoundEnabled();

      final existingRecords = await _detectionRepository.loadRecords();
      _records.addAll(existingRecords);

      if (_autoSaveEnabled) {
        _detectionRepository.startAutoSave();
      }

      _logger.info('DetectionProvider initialized with ${_records.length} records');
    } catch (e) {
      _logger.error('Error initializing DetectionProvider', e);
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  void updateDigitConfig({required int minDigits, required int maxDigits}) {
    OcrIsolate.updateDigitConfig(minDigits: minDigits, maxDigits: maxDigits);
    _logger.info('Digit config updated: $minDigits-$maxDigits');
  }

  void setRequiredReads(int count) {
    _requiredReads = count.clamp(1, 10);
    _consecutiveReads.clear();
    _logger.info('Required reads updated: $_requiredReads');
    _safeNotify();
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    _logger.info('Sound enabled: $enabled');
    _safeNotify();
  }

  void startSession(int sessionId) {
    _currentSessionId = sessionId;
    _currentSessionStart = DateTime.now();
    _sessionDorsals.clear();
    _logger.info('Session $sessionId started at $_currentSessionStart');
  }

  List<SessionDorsal> endSession() {
    _logger.info('Session $_currentSessionId ended with ${_sessionDorsals.length} dorsals');
    _currentSessionId = null;
    _currentSessionStart = null;
    return List.from(_sessionDorsals);
  }

  Future<void> processImageFile(String imagePath) async {
    if (_isProcessingFrame) {
      debugPrint('[Detection] SKIP: already processing');
      return;
    }

    _isProcessingFrame = true;
    debugPrint('[Detection] processImageFile: $imagePath');

    try {
      final result = await OcrIsolate.processImageFile(imagePath);
      debugPrint('[Detection] OCR result: ${result.dorsals.length} dorsals=${result.dorsals}');

      for (final dorsal in result.dorsals) {
        _handleDetection(dorsal);
      }

      if (result.rawText != null) {
        _lastRawText = result.rawText;
      }
    } catch (e, stack) {
      debugPrint('[Detection] ERROR: $e');
      debugPrint('[Detection] STACK: $stack');
      _logger.error('Error processing image file', e);
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _handleDetection(String dorsal) {
    if (_isDebounced(dorsal)) return;

    _consecutiveReads[dorsal] = (_consecutiveReads[dorsal] ?? 0) + 1;
    _logger.debug('Dorsal "$dorsal" read ${_consecutiveReads[dorsal]}/$_requiredReads times');

    if (_consecutiveReads[dorsal]! < _requiredReads) {
      _lastRawText = dorsal;
      _safeNotify();
      return;
    }

    _consecutiveReads.remove(dorsal);

    final record = DetectionRecord(
      dorsal: dorsal,
      timestamp: DateTime.now(),
    );

    _records.insert(0, record);
    _lastDetectedDorsal = dorsal;
    _lastDetectionTime = DateTime.now();

    _addToDebounce(dorsal);
    _detectionRepository.saveRecord(record);

    if (_currentSessionId != null && _currentSessionStart != null) {
      _sessionDorsals.add(SessionDorsal(
        dorsal: dorsal,
        timestamp: record.timestamp,
        offsetMs: record.timestamp.difference(_currentSessionStart!).inMilliseconds,
      ));
    }

    _logger.info('Detection recorded ($_requiredReads confirmations): ${record.toString()}');
    _safeNotify();
    if (_soundEnabled) {
      debugPrint('[Detection] beep for dorsal $dorsal');
      _beepService.beep(frequency: 1200, durationMs: 150);
    } else {
      debugPrint('[Detection] sound disabled');
    }
  }

  bool _isDebounced(String dorsal) {
    final lastSeen = _debounceMap[dorsal];
    if (lastSeen == null) return false;
    final now = DateTime.now();
    return now.difference(lastSeen).inSeconds < AppConstants.debounceTimeoutSeconds;
  }

  void _addToDebounce(String dorsal) {
    _debounceMap[dorsal] = DateTime.now();
  }

  void cleanDebounceMap() {
    final now = DateTime.now();
    _debounceMap.removeWhere((key, timestamp) {
      return now.difference(timestamp).inSeconds > AppConstants.debounceTimeoutSeconds;
    });
  }

  Future<void> flushCsv() async {
    await _detectionRepository.flush();
  }

  Future<String> getCsvFilePath() async {
    return await _detectionRepository.getCsvFilePath();
  }

  Future<Map<String, dynamic>> getCsvStatistics() async {
    return await _detectionRepository.getStatistics();
  }

  Future<void> deleteRecord(int index) async {
    if (index < 0 || index >= _records.length) return;
    _records.removeAt(index);
    await _detectionRepository.rewriteAll(_records);
    _safeNotify();
    _logger.info('Record deleted at index $index');
  }

  Future<void> updateRecord(int index, String newDorsal) async {
    if (index < 0 || index >= _records.length) return;
    final old = _records[index];
    _records[index] = DetectionRecord(dorsal: newDorsal, timestamp: old.timestamp);
    await _detectionRepository.rewriteAll(_records);
    _safeNotify();
    _logger.info('Record updated at index $index: ${old.dorsal} -> $newDorsal');
  }

  Future<void> clearAllRecords() async {
    _records.clear();
    await _detectionRepository.clearAll();
    _safeNotify();
    _logger.info('All records cleared');
  }

  @override
  void dispose() {
    _disposed = true;
    _detectionRepository.stopAutoSave();
    OcrIsolate.stop();
    _logger.info('DetectionProvider disposed');
    super.dispose();
  }
}
