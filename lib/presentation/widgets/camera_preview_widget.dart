import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';

class CameraPreviewWidget extends StatefulWidget {
  const CameraPreviewWidget({super.key});

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  Offset? _focusPoint;
  double _currentZoom = 1.0;
  DateTime? _lastFocusTime;
  bool _isFocusing = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraProvider>(
      builder: (context, cameraProvider, child) {
        if (!cameraProvider.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.greenAccent),
          );
        }

        if (cameraProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  cameraProvider.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => cameraProvider.reconnect(),
                  child: const Text('Reconectar'),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            _buildCameraPreview(cameraProvider),
            _buildFocusIndicator(),
            Positioned(
              top: 8,
              right: 8,
              child: _buildCameraSwitchButton(cameraProvider),
            ),
            Positioned(
              right: 8,
              top: 50,
              bottom: 50,
              child: _buildZoomSlider(cameraProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCameraPreview(CameraProvider cameraProvider) {
    final controller = cameraProvider.cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return SizedBox.expand(child: Container(color: Colors.black));
    }

    final sensorW = controller.value.previewSize!.width;
    final sensorH = controller.value.previewSize!.height;

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final previewW = isLandscape ? sensorW : sensorH;
    final previewH = isLandscape ? sensorH : sensorW;

    return GestureDetector(
      onTapDown: (details) => _handleTap(context, details, cameraProvider),
      onScaleStart: (details) {},
      onScaleUpdate: (details) => _handleScaleUpdate(details, cameraProvider),
      child: Center(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewW,
            height: previewH,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraSwitchButton(CameraProvider cameraProvider) {
    if (!cameraProvider.hasMultipleCameras) return const SizedBox.shrink();

    final disabled = cameraProvider.isRecording || cameraProvider.isSwitching;

    return GestureDetector(
      onTap: disabled ? null : () => _switchCamera(cameraProvider),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.grey.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: cameraProvider.isSwitching
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Icon(
                cameraProvider.currentLensDirection == CameraLensDirection.front
                    ? Icons.camera_front
                    : Icons.camera_rear,
                color: disabled ? Colors.grey : Colors.white,
                size: 22,
              ),
      ),
    );
  }

  Future<void> _switchCamera(CameraProvider cameraProvider) async {
    await cameraProvider.switchCamera();
  }

  Widget _buildZoomSlider(CameraProvider cameraProvider) {
    if (cameraProvider.maxZoom <= cameraProvider.minZoom) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 40,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.zoom_in, color: Colors.white, size: 16),
          const SizedBox(height: 4),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: _currentZoom,
                min: cameraProvider.minZoom,
                max: cameraProvider.maxZoom,
                divisions: 20,
                onChanged: (value) {
                  setState(() => _currentZoom = value);
                  cameraProvider.setZoomLevel(value);
                },
                activeColor: Colors.greenAccent,
                inactiveColor: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Icon(Icons.zoom_out, color: Colors.white, size: 16),
          const SizedBox(height: 4),
          Text(
            '${_currentZoom.toStringAsFixed(1)}x',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusIndicator() {
    if (_focusPoint == null) return const SizedBox.shrink();

    return Positioned(
      left: _focusPoint!.dx - 30,
      top: _focusPoint!.dy - 30,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 0.0),
        duration: const Duration(milliseconds: 1200),
        onEnd: () {
          if (mounted) setState(() => _focusPoint = null);
        },
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleTap(
    BuildContext context,
    TapDownDetails details,
    CameraProvider cameraProvider,
  ) async {
    if (_isFocusing) return;
    final now = DateTime.now();
    if (_lastFocusTime != null && now.difference(_lastFocusTime!).inMilliseconds < 800) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPoint = box.globalToLocal(details.globalPosition);
    final widgetSize = box.size;

    final normalizedX = (localPoint.dx / widgetSize.width).clamp(0.0, 1.0);
    final normalizedY = (localPoint.dy / widgetSize.height).clamp(0.0, 1.0);

    setState(() => _focusPoint = localPoint);
    _lastFocusTime = now;
    _isFocusing = true;

    try {
      await cameraProvider.setFocusPoint(normalizedX, normalizedY);
    } catch (_) {} finally {
      _isFocusing = false;
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, CameraProvider cameraProvider) {
    if (details.scale == 1.0) return;

    final newZoom = details.scale.clamp(
      cameraProvider.minZoom,
      cameraProvider.maxZoom,
    );

    setState(() => _currentZoom = newZoom);
    cameraProvider.setZoomLevel(newZoom);
  }
}
