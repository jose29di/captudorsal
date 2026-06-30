import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../data/models/recording_session.dart';
import '../../data/services/camera_service.dart';
import '../../domain/usecases/manage_recording_usecase.dart';
import '../../core/utils/logger.dart';

class CameraProvider extends ChangeNotifier {
  final CameraService _cameraService;
  final ManageRecordingUseCase _manageRecordingUseCase;
  final AppLogger _logger = AppLogger();

  RecordingSession? _lastSession;
  DateTime? _recordingStartTime;
  bool _isSwitching = false;
  bool _disposed = false;

  RecordingSession? get lastSession => _lastSession;
  DateTime? get recordingStartTime => _recordingStartTime;
  bool get isSwitching => _isSwitching;

  CameraProvider({
    required CameraService cameraService,
    required ManageRecordingUseCase manageRecordingUseCase,
  })  : _cameraService = cameraService,
        _manageRecordingUseCase = manageRecordingUseCase {
    _cameraService.onStateChanged = () {
      if (!_disposed) notifyListeners();
    };
  }

  CameraService get cameraService => _cameraService;
  bool get isInitialized => _cameraService.isInitialized;
  bool get isRecording => _cameraService.isRecording;
  bool get isPaused => _cameraService.isPaused;
  String? get error => _cameraService.error;
  bool get hasMultipleCameras => _cameraService.hasMultipleCameras;
  double get currentZoomLevel => _cameraService.currentZoomLevel;
  double get minZoom => _cameraService.minZoom;
  double get maxZoom => _cameraService.maxZoom;
  CameraLensDirection get currentLensDirection => _cameraService.currentLensDirection;

  Future<bool> initializeCamera() async {
    notifyListeners();
    final success = await _cameraService.initialize();
    notifyListeners();
    return success;
  }

  Future<void> switchCamera() async {
    if (_isSwitching || !hasMultipleCameras || isRecording) return;

    _isSwitching = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    try {
      await _cameraService.switchCamera();
    } catch (e) {
      _logger.error('Error switching camera', e);
    } finally {
      _isSwitching = false;
      notifyListeners();
    }
  }

  Future<void> setFocusPoint(double x, double y) async {
    await _cameraService.setFocusPoint(x, y);
  }

  Future<void> setZoomLevel(double zoom) async {
    await _cameraService.setZoomLevel(zoom);
    notifyListeners();
  }

  Future<void> setExposurePoint(double x, double y) async {
    await _cameraService.setExposurePoint(x, y);
  }

  Future<void> toggleRecording() async {
    await _manageRecordingUseCase.toggleRecording();
    notifyListeners();
  }

  Future<void> startRecording() async {
    await _manageRecordingUseCase.startRecording();
    _recordingStartTime = DateTime.now();
    notifyListeners();
  }

  Future<void> pauseRecording() async {
    await _manageRecordingUseCase.pauseRecording();
    notifyListeners();
  }

  Future<void> resumeRecording() async {
    await _manageRecordingUseCase.resumeRecording();
    notifyListeners();
  }

  Future<RecordingSession?> stopRecording() async {
    final session = await _manageRecordingUseCase.stopRecording();
    _lastSession = session;
    _recordingStartTime = null;
    notifyListeners();
    return session;
  }

  Future<void> reconnect() async {
    await _cameraService.reconnect();
    notifyListeners();
  }

  void clearError() {
    _cameraService.clearError();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cameraService.onStateChanged = null;
    _logger.info('CameraProvider disposed');
    super.dispose();
  }
}
