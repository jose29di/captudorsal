import 'dart:io';
import 'package:saver_gallery/saver_gallery.dart';
import '../../data/models/recording_session.dart';
import '../../data/services/camera_service.dart';
import '../../data/services/session_service.dart';
import '../../data/services/wake_lock_service.dart';
import '../../core/utils/logger.dart';

class ManageRecordingUseCase {
  final CameraService _cameraService;
  final WakeLockService _wakeLockService;
  final SessionService _sessionService;
  final AppLogger _logger = AppLogger();

  DateTime? _recordingStartTime;
  int? _currentSessionId;
  List<SessionDorsal> Function()? _collectSessionDorsals;
  void Function(int sessionId)? _onSessionStart;

  ManageRecordingUseCase({
    required CameraService cameraService,
    required WakeLockService wakeLockService,
    required SessionService sessionService,
  })  : _cameraService = cameraService,
        _wakeLockService = wakeLockService,
        _sessionService = sessionService;

  void setSessionCallbacks({
    required List<SessionDorsal> Function() collectDorsals,
    required void Function(int sessionId) onSessionStart,
  }) {
    _collectSessionDorsals = collectDorsals;
    _onSessionStart = onSessionStart;
  }

  Future<bool> startRecording() async {
    try {
      await _cameraService.startRecording();
      await _wakeLockService.activate();
      _recordingStartTime = DateTime.now();
      _currentSessionId = _recordingStartTime!.millisecondsSinceEpoch;
      _onSessionStart?.call(_currentSessionId!);
      _logger.info('Recording started, session $_currentSessionId at $_recordingStartTime');
      return true;
    } catch (e) {
      _logger.error('Failed to start recording', e);
      return false;
    }
  }

  Future<bool> pauseRecording() async {
    try {
      await _cameraService.pauseRecording();
      _logger.info('Recording paused via use case');
      return true;
    } catch (e) {
      _logger.error('Failed to pause recording', e);
      return false;
    }
  }

  Future<bool> resumeRecording() async {
    try {
      await _cameraService.resumeRecording();
      _logger.info('Recording resumed via use case');
      return true;
    } catch (e) {
      _logger.error('Failed to resume recording', e);
      return false;
    }
  }

  Future<RecordingSession?> stopRecording() async {
    try {
      final file = await _cameraService.stopRecording();
      await _wakeLockService.deactivate();

      final endTime = DateTime.now();

      if (file != null) {
        await _saveToGallery(file.path);

        if (_currentSessionId != null && _recordingStartTime != null) {
          final videoPath = await _sessionService.getVideoPathForSession(_currentSessionId!);
          await _sessionService.copyVideoToSessionDir(file.path, _currentSessionId!);

          final dorsals = _collectSessionDorsals?.call() ?? [];

          final session = RecordingSession(
            id: _currentSessionId!,
            videoPath: videoPath,
            startTime: _recordingStartTime!,
            endTime: endTime,
            dorsals: dorsals,
          );

          await _sessionService.saveSession(session);
          _logger.info('Session ${session.id} saved: ${dorsals.length} dorsals, video at $videoPath');

          _currentSessionId = null;
          _recordingStartTime = null;
          return session;
        }
      }

      _currentSessionId = null;
      _recordingStartTime = null;
      _logger.info('Recording stopped (no file or no session)');
      return null;
    } catch (e) {
      _logger.error('Failed to stop recording', e);
      _currentSessionId = null;
      _recordingStartTime = null;
      return null;
    }
  }

  Future<String?> _saveToGallery(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _logger.error('Video file not found: $filePath');
        return null;
      }

      final fileName = 'CaptuDorsal_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final result = await SaverGallery.saveFile(
        filePath: filePath,
        fileName: fileName,
        skipIfExists: false,
      );

      if (result.isSuccess) {
        _logger.info('Video saved to gallery: $fileName');
        return fileName;
      } else {
        _logger.error('Failed to save to gallery: ${result.errorMessage}');
        return null;
      }
    } catch (e) {
      _logger.error('Error saving to gallery', e);
      return null;
    }
  }

  Future<void> toggleRecording() async {
    if (!_cameraService.isRecording) {
      await startRecording();
    } else if (_cameraService.isPaused) {
      await resumeRecording();
    } else {
      await pauseRecording();
    }
  }

  bool get isRecording => _cameraService.isRecording;
  bool get isPaused => _cameraService.isPaused;
}
