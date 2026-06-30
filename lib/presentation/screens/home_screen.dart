import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presentation/providers/camera_provider.dart';
import '../../presentation/providers/detection_provider.dart';
import '../../presentation/providers/roi_provider.dart';
import '../../presentation/widgets/camera_preview_widget.dart';
import '../../presentation/widgets/roi_overlay.dart';
import '../../presentation/widgets/recording_controls.dart';
import '../../presentation/widgets/history_panel.dart';
import '../../presentation/widgets/detection_status.dart';
import '../../presentation/screens/settings_screen.dart';
import '../../presentation/screens/sessions_screen.dart';
import '../../platform/services/frame_processor.dart';
import '../../platform/services/ocr_isolate.dart';
import '../../core/di/dependency_container.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  FrameProcessor? _frameProcessor;
  bool _batteryExemptionRequested = false;
  VoidCallback? _roiListener;
  CameraController? _attachedController;
  bool _wasRecording = false;
  bool _isCapturing = true;
  bool _isScreenDimmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isScreenDimmed) {
      DependencyContainer().screenService.restoreBrightness();
    }
    final cameraProvider = context.read<CameraProvider>();
    final roiProvider = context.read<RoiProvider>();
    cameraProvider.removeListener(_onCameraChanged);
    if (_roiListener != null) {
      roiProvider.removeListener(_roiListener!);
    }
    _frameProcessor?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraProvider = context.read<CameraProvider>();

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _saveState();
        cameraProvider.cameraService.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        _restoreState();
        cameraProvider.cameraService.onAppResumed();
        reinitializeFrameProcessor();
        break;
      case AppLifecycleState.detached:
        _cleanup();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _initializeApp() async {
    final cameraProvider = context.read<CameraProvider>();
    final detectionProvider = context.read<DetectionProvider>();
    final roiProvider = context.read<RoiProvider>();

    _syncRoiToOcr(roiProvider);

    _roiListener = () => _syncRoiToOcr(roiProvider);
    roiProvider.addListener(_roiListener!);

    await detectionProvider.initialize();

    final container = DependencyContainer();
    if (container.statePersistence.loadKeepScreenOn()) {
      await container.wakeLockService.activate();
    }

    final success = await cameraProvider.initializeCamera();

    if (success && mounted) {
      _setupFrameProcessor(cameraProvider, detectionProvider);
    }

    if (!_batteryExemptionRequested) {
      _requestBatteryExemption();
    }

    cameraProvider.addListener(_onCameraChanged);
  }

  void _syncRoiToOcr(RoiProvider roiProvider) {
    final config = roiProvider.config;
    OcrIsolate.updateRoi(
      leftPercent: config.leftPercent,
      topPercent: config.topPercent,
      widthPercent: config.widthPercent,
      heightPercent: config.heightPercent,
    );
  }

  void _onCameraChanged() {
    if (!mounted) return;
    final cameraProvider = context.read<CameraProvider>();

    if (cameraProvider.isSwitching) {
      _frameProcessor?.detachCamera();
      _attachedController = null;
      return;
    }

    final isRec = cameraProvider.isRecording;
    if (isRec != _wasRecording) {
      _wasRecording = isRec;
      if (isRec) {
        _frameProcessor?.switchToStreamMode();
      } else {
        _frameProcessor?.switchToTimerMode();
      }
      return;
    }

    if (!cameraProvider.isInitialized) {
      if (_attachedController != null) {
        _frameProcessor?.detachCamera();
        _attachedController = null;
      }
      return;
    }

    final controller = cameraProvider.cameraService.controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (identical(controller, _attachedController)) return;
    _attachedController = controller;
    final detectionProvider = context.read<DetectionProvider>();
    _restartImageStream(cameraProvider, detectionProvider);
    if (!_isCapturing) {
      _frameProcessor?.pause();
    }
  }

  Future<void> _requestBatteryExemption() async {
    try {
      final container = DependencyContainer();
      await container.batteryOptimizationService.requestExemption();
      _batteryExemptionRequested = true;
    } catch (_) {}
  }

  void _setupFrameProcessor(
    CameraProvider cameraProvider,
    DetectionProvider detectionProvider,
  ) {
    _frameProcessor?.detachCamera();
    _frameProcessor?.dispose();

    _frameProcessor = FrameProcessor(
      onPicture: (String imagePath) async {
        if (mounted) {
          await detectionProvider.processImageFile(imagePath);
        }
      },
    );

    final controller = cameraProvider.cameraService.controller;
    if (controller != null && controller.value.isInitialized) {
      _attachedController = controller;
      _wasRecording = cameraProvider.isRecording;
      _frameProcessor!.attachCamera(controller);
    } else {
      _attachedController = null;
    }
  }

  void _restartImageStream(
    CameraProvider cameraProvider,
    DetectionProvider detectionProvider,
  ) {
    final controller = cameraProvider.cameraService.controller;
    if (controller == null || !controller.value.isInitialized) return;

    _frameProcessor?.detachCamera();
    _frameProcessor?.dispose();

    _frameProcessor = FrameProcessor(
      onPicture: (String imagePath) async {
        if (mounted) {
          await detectionProvider.processImageFile(imagePath);
        }
      },
    );

    _attachedController = controller;
    _wasRecording = cameraProvider.isRecording;
    _frameProcessor!.attachCamera(controller);
  }

  void reinitializeFrameProcessor() {
    final cameraProvider = context.read<CameraProvider>();
    final detectionProvider = context.read<DetectionProvider>();

    if (cameraProvider.cameraService.controller != null) {
      _setupFrameProcessor(cameraProvider, detectionProvider);
      if (!_isCapturing) {
        _frameProcessor?.pause();
      }
    }
  }

  Future<void> _saveState() async {
    final detectionProvider = context.read<DetectionProvider>();
    await detectionProvider.flushCsv();
  }

  Future<void> _restoreState() async {
    setState(() {});
  }

  Future<void> _cleanup() async {
    final detectionProvider = context.read<DetectionProvider>();
    await detectionProvider.flushCsv();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.landscape) {
              return _buildLandscapeLayout();
            }
            return _buildPortraitLayout();
          },
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              flex: 55,
              child: Stack(
                children: [
                  const RepaintBoundary(child: CameraPreviewWidget()),
                  const RoiOverlay(),
                  const DetectionStatus(),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildBottomLeftControls(context),
                  ),
                  const Positioned(
                    top: 8,
                    right: 56,
                    child: _ClockWidget(),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 15,
              child: const RecordingControls(),
            ),
            Expanded(
              flex: 30,
              child: const HistoryPanel(),
            ),
          ],
        ),
        if (_isScreenDimmed) _buildDimOverlay(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              flex: 55,
              child: Stack(
                children: [
                  const RepaintBoundary(child: CameraPreviewWidget()),
                  const RoiOverlay(),
                  const DetectionStatus(),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildBottomLeftControls(context),
                  ),
                  const Positioned(
                    top: 8,
                    right: 56,
                    child: _ClockWidget(),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: const RecordingControls(),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 45,
              child: const HistoryPanel(),
            ),
          ],
        ),
        if (_isScreenDimmed) _buildDimOverlay(),
      ],
    );
  }

  Widget _buildDimOverlay() {
    return GestureDetector(
      onTap: () {
        setState(() => _isScreenDimmed = false);
        DependencyContainer().screenService.restoreBrightness();
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.brightness_low, color: Colors.amber, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Modo Ahorro Activado',
                style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Detección y grabación continúan\nToca la pantalla para restaurar',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomLeftControls(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isCapturing = !_isCapturing;
                  if (_isCapturing) {
                    _frameProcessor?.resume();
                    DependencyContainer().beepService.doubleBeep(frequency: 1000, durationMs: 120);
                  } else {
                    _frameProcessor?.pause();
                  }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isCapturing
                  ? Colors.greenAccent.withValues(alpha: 0.9)
                  : Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _isCapturing ? Icons.pause : Icons.play_arrow,
              color: _isCapturing ? Colors.black : Colors.white,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SessionsScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.video_library,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            setState(() => _isScreenDimmed = !_isScreenDimmed);
            final screenService = DependencyContainer().screenService;
            if (_isScreenDimmed) {
              screenService.dimScreen();
            } else {
              screenService.restoreBrightness();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isScreenDimmed
                  ? Colors.amber.withValues(alpha: 0.9)
                  : Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _isScreenDimmed ? Icons.brightness_low : Icons.brightness_high,
              color: _isScreenDimmed ? Colors.black : Colors.white,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            final roiProvider = context.read<RoiProvider>();
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
            if (mounted) {
              _frameProcessor?.refreshInterval();
              _syncRoiToOcr(roiProvider);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.settings,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClockWidget extends StatefulWidget {
  const _ClockWidget();

  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  late Timer _timer;
  String _timeStr = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    if (mounted) setState(() => _timeStr = '$h:$m:$s');
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _timeStr,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
