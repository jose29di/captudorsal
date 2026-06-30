import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../../core/utils/logger.dart';
import '../../platform/services/ocr_isolate.dart';

class FrameProcessor {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _disposed = false;
  Timer? _timer;
  int _currentIntervalMs = 500;
  DateTime? _readyAt;
  final AppLogger _logger = AppLogger();

  final Future<void> Function(String imagePath) _onPicture;

  FrameProcessor({
    required Future<void> Function(String imagePath) onPicture,
  }) : _onPicture = onPicture;

  bool get isProcessing => _isProcessing;

  void attachCamera(CameraController controller) {
    _controller = controller;
    _startTimer();
  }

  void detachCamera() {
    _stopTimer();
    _controller = null;
  }

  void pause() {
    _stopTimer();
    debugPrint('[FrameProcessor] paused');
  }

  void resume() {
    if (_disposed || _controller == null) return;
    _readyAt = DateTime.now().add(const Duration(milliseconds: 1500));
    _startTimer();
    debugPrint('[FrameProcessor] resumed');
  }

  void switchToStreamMode() {
    debugPrint('[FrameProcessor] recording started, takePicture continues');
  }

  void switchToTimerMode() {
    debugPrint('[FrameProcessor] recording stopped, takePicture continues');
  }

  void refreshInterval() {
    final newInterval = OcrIsolate.currentThrottleMs;
    if (newInterval != _currentIntervalMs) {
      _logger.info('FrameProcessor interval changed: $_currentIntervalMs -> $newInterval ms');
      _currentIntervalMs = newInterval;
      _startTimer();
    }
  }

  void _startTimer() {
    _stopTimer();
    if (_disposed || _controller == null) return;
    if (!_controller!.value.isInitialized) return;

    _currentIntervalMs = OcrIsolate.currentThrottleMs;
    _readyAt = DateTime.now().add(const Duration(milliseconds: 1500));
    _timer = Timer.periodic(Duration(milliseconds: _currentIntervalMs), (_) => _capture());
    debugPrint('[FrameProcessor] timer started: ${_currentIntervalMs}ms (warmup 1.5s)');
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _capture() async {
    if (_isProcessing || _disposed) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_readyAt != null && DateTime.now().isBefore(_readyAt!)) return;

    _isProcessing = true;
    final isRec = _controller!.value.isRecordingVideo;
    debugPrint('[FrameProcessor] START capture${isRec ? ' (during recording)' : ''}');

    try {
      final file = await _controller!.takePicture().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[FrameProcessor] takePicture TIMEOUT');
          throw TimeoutException('takePicture timeout');
        },
      );
      debugPrint('[FrameProcessor] picture taken: ${file.path}');
      if (!_disposed) {
        await _onPicture(file.path);
      }
    } on CameraException catch (e) {
      debugPrint('[FrameProcessor] CameraException: ${e.code} - ${e.description}');
      final msg = '${e.code} ${e.description}'.toLowerCase();
      if (msg.contains('disposed')) {
        _logger.warning('Controller disposed, stopping capture timer');
        _stopTimer();
        _controller = null;
      } else if (msg.contains('imagecapture') ||
          msg.contains('not bound to a valid camera')) {
        _logger.warning('ImageCapture not ready, will retry next tick');
      } else if (msg.contains('recording') || msg.contains('video')) {
        _logger.warning('takePicture during recording not supported on this device');
      }
    } catch (e) {
      debugPrint('[FrameProcessor] ERROR: $e');
      _logger.warning('Frame capture error: $e');
    } finally {
      _isProcessing = false;
      debugPrint('[FrameProcessor] END capture');
    }
  }

  void dispose() {
    _disposed = true;
    _stopTimer();
  }
}
