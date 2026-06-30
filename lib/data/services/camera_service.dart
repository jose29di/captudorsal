import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/utils/logger.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isPaused = false;
  String? _error;
  int _reconnectAttempts = 0;
  bool _isReconnecting = false;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 2);
  Timer? _reconnectTimer;
  int _currentCameraIndex = 0;
  double _currentZoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  final AppLogger _logger = AppLogger();
  final StreamController<String> _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;
  void Function()? onStateChanged;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  String? get error => _error;
  bool get hasMultipleCameras => _cameras.length > 1;
  double get currentZoomLevel => _currentZoomLevel;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;

  CameraLensDirection get currentLensDirection =>
      _cameras.isNotEmpty ? _cameras[_currentCameraIndex].lensDirection : CameraLensDirection.back;

  Future<bool> initialize() async {
    try {
      _logger.info('Initializing camera...');

      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        _error = 'Permiso de cámara denegado';
        _logger.warning(_error!);
        _errorController.add(_error!);
        return false;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _error = 'No se encontraron cámaras';
        _logger.warning(_error!);
        _errorController.add(_error!);
        return false;
      }

      _currentCameraIndex = 0;
      for (int i = 0; i < _cameras.length; i++) {
        if (_cameras[i].lensDirection == CameraLensDirection.back) {
          _currentCameraIndex = i;
          break;
        }
      }

      await _initController(_cameras[_currentCameraIndex]);
      return true;
    } catch (e) {
      _error = 'Error al inicializar cámara: $e';
      _isInitialized = false;
      _logger.error(_error!, e);
      _errorController.add(_error!);
      onStateChanged?.call();
      return false;
    }
  }

  Future<void> _initController(CameraDescription camera) async {
    await _controller?.dispose();
    _controller = null;

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    _controller!.addListener(_onCameraError);

    try {
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _currentZoomLevel = _minZoom;
    } catch (e) {
      _minZoom = 1.0;
      _maxZoom = 1.0;
    }

    _isInitialized = true;
    _error = null;
    _reconnectAttempts = 0;
    _isReconnecting = false;
    _logger.info('Camera initialized: ${camera.lensDirection}');
    onStateChanged?.call();
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    if (_isRecording) return;

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;

    _logger.info('Switching to camera $_currentCameraIndex');
    await _initController(_cameras[_currentCameraIndex]);
  }

  Future<void> setFocusPoint(double x, double y) async {
    if (_controller == null || !_isInitialized) return;

    try {
      await _controller!.setFocusPoint(Offset(x, y));
      await _controller!.setFocusMode(FocusMode.auto);
      _logger.debug('Focus set at ($x, $y)');
    } catch (e) {
      _logger.warning('Failed to set focus point');
    }
  }

  Future<void> setZoomLevel(double zoom) async {
    if (_controller == null || !_isInitialized) return;

    final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
    try {
      await _controller!.setZoomLevel(clampedZoom);
      _currentZoomLevel = clampedZoom;
      _logger.debug('Zoom set to $clampedZoom');
    } catch (e) {
      _logger.warning('Failed to set zoom level');
    }
  }

  Future<void> setExposurePoint(double x, double y) async {
    if (_controller == null || !_isInitialized) return;

    try {
      await _controller!.setExposurePoint(Offset(x, y));
      _logger.debug('Exposure set at ($x, $y)');
    } catch (e) {
      _logger.warning('Failed to set exposure point');
    }
  }

  void _onCameraError() {
    if (_controller == null) return;

    final error = _controller!.value.errorDescription;
    if (error != null) {
      final lower = error.toLowerCase();
      if (lower.contains('imagecapture') ||
          lower.contains('not bound to a valid camera')) {
        _logger.warning('Transient ImageCapture error, skipping reconnect: $error');
        return;
      }
      _logger.error('Camera error: $error');
      _errorController.add(error);
      _handleCameraError();
    }
  }

  void _handleCameraError() {
    if (_isReconnecting) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _error = 'Máximo de intentos de reconexión alcanzado';
      _logger.error(_error!);
      _errorController.add(_error!);
      return;
    }

    _isReconnecting = true;
    _isInitialized = false;
    _reconnectAttempts++;

    _logger.info('Scheduling camera reconnect ($_reconnectAttempts/$_maxReconnectAttempts)');
    onStateChanged?.call();

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      _isReconnecting = false;
      reconnect();
    });
  }

  Future<void> reconnect() async {
    _logger.info('Attempting camera reconnect...');

    final savedIndex = _currentCameraIndex;

    try {
      await _controller?.dispose();
      _controller = null;

      final success = await _initializeWithCamera(savedIndex);

      if (!success && _reconnectAttempts < _maxReconnectAttempts) {
        _isReconnecting = false;
        _handleCameraError();
      } else {
        _isReconnecting = false;
      }
    } catch (e) {
      _logger.error('Error during camera reconnect', e);
      _isReconnecting = false;
      if (_reconnectAttempts < _maxReconnectAttempts) {
        _handleCameraError();
      }
    }
    onStateChanged?.call();
  }

  Future<bool> _initializeWithCamera(int cameraIndex) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _error = 'No se encontraron cámaras';
        _logger.warning(_error!);
        _errorController.add(_error!);
        return false;
      }

      _currentCameraIndex = cameraIndex;
      if (_currentCameraIndex >= _cameras.length) {
        _currentCameraIndex = 0;
      }

      await _initController(_cameras[_currentCameraIndex]);
      return true;
    } catch (e) {
      _error = 'Error al inicializar cámara: $e';
      _isInitialized = false;
      _logger.error(_error!, e);
      _errorController.add(_error!);
      onStateChanged?.call();
      return false;
    }
  }

  Future<void> startRecording() async {
    if (_controller == null || !_isInitialized) return;
    if (_isRecording) return;

    try {
      await _controller!.startVideoRecording();
      _isRecording = true;
      _isPaused = false;
      _logger.info('Recording started');
    } catch (e) {
      _error = 'Error al iniciar grabación: $e';
      _logger.error(_error!, e);
      _errorController.add(_error!);
    }
  }

  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) return;

    try {
      await _controller!.pauseVideoRecording();
      _isPaused = true;
      _logger.info('Recording paused');
    } catch (e) {
      _error = 'Error al pausar grabación: $e';
      _logger.error(_error!, e);
      _errorController.add(_error!);
    }
  }

  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;

    try {
      await _controller!.resumeVideoRecording();
      _isPaused = false;
      _logger.info('Recording resumed');
    } catch (e) {
      _error = 'Error al reanudar grabación: $e';
      _logger.error(_error!, e);
      _errorController.add(_error!);
    }
  }

  Future<XFile?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final file = await _controller!.stopVideoRecording();
      _isRecording = false;
      _isPaused = false;
      _logger.info('Recording stopped');
      return file;
    } catch (e) {
      _error = 'Error al detener grabación: $e';
      _logger.error(_error!, e);
      _errorController.add(_error!);
      return null;
    }
  }

  Future<void> toggleRecording() async {
    if (!_isRecording) {
      await startRecording();
    } else if (_isPaused) {
      await resumeRecording();
    } else {
      await pauseRecording();
    }
  }

  void clearError() {
    _error = null;
  }

  void onAppPaused() {
    _logger.info('App paused - camera continues running');
  }

  void onAppResumed() {
    if (_controller != null && !_controller!.value.isInitialized) {
      _logger.warning('Camera not initialized after resume, reconnecting...');
      reconnect();
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _controller?.removeListener(_onCameraError);
    _controller?.dispose();
    _errorController.close();
    _logger.info('Camera service disposed');
  }
}
