import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../presentation/providers/camera_provider.dart';
import '../../presentation/providers/detection_provider.dart';
import '../../presentation/screens/review_screen.dart';

class RecordingControls extends StatelessWidget {
  const RecordingControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraProvider>(
      builder: (context, cameraProvider, child) {
        final isRecording = cameraProvider.isRecording;
        final isPaused = cameraProvider.isPaused;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            border: Border(
              top: BorderSide(color: Colors.grey[800]!, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RecordButton(
                isRecording: isRecording,
                isPaused: isPaused,
                onPressed: () => cameraProvider.toggleRecording(),
              ),
              if (isRecording) ...[
                _StopButton(
                  onPressed: () => _stopRecording(context, cameraProvider),
                ),
              ],
              _StatusIndicator(
                isRecording: isRecording,
                isPaused: isPaused,
                recordingStartTime: cameraProvider.recordingStartTime,
              ),
              _ShareButton(
                onPressed: () => _shareCsv(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _stopRecording(BuildContext context, CameraProvider cameraProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Detener grabación', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Se guardará el video en la galería. ¿Continuar?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Detener', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final session = await cameraProvider.stopRecording();
      if (context.mounted) {
        if (session != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Grabación guardada: ${session.dorsals.length} dorsales',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Revisar',
                textColor: Colors.black,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewScreen(session: session),
                    ),
                  );
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Grabación detenida (no se pudo guardar)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _shareCsv(BuildContext context) async {
    try {
      final detectionProvider = context.read<DetectionProvider>();
      final csvPath = await detectionProvider.getCsvFilePath();
      final file = File(csvPath);

      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay datos para compartir'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      await Share.shareXFiles(
        [XFile(csvPath)],
        text: 'Dorsales capturados - CaptuDorsal',
        subject: 'Reporte de dorsales',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final bool isPaused;
  final VoidCallback onPressed;

  const _RecordButton({
    required this.isRecording,
    required this.isPaused,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _getButtonColor(),
          boxShadow: [
            if (isRecording && !isPaused)
              BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Icon(
          _getButtonIcon(),
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Color _getButtonColor() {
    if (!isRecording) return Colors.redAccent;
    if (isPaused) return Colors.amber;
    return Colors.red;
  }

  IconData _getButtonIcon() {
    if (!isRecording) return Icons.fiber_manual_record;
    if (isPaused) return Icons.play_arrow;
    return Icons.pause;
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _StopButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: const Icon(
          Icons.stop,
          color: Colors.red,
          size: 28,
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatefulWidget {
  final bool isRecording;
  final bool isPaused;
  final DateTime? recordingStartTime;

  const _StatusIndicator({
    required this.isRecording,
    required this.isPaused,
    this.recordingStartTime,
  });

  @override
  State<_StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<_StatusIndicator> {
  Timer? _timer;
  String _duration = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording ||
        widget.recordingStartTime != oldWidget.recordingStartTime) {
      _stopTimer();
      _startTimer();
    }
  }

  void _startTimer() {
    if (!widget.isRecording || widget.isPaused || widget.recordingStartTime == null) {
      setState(() => _duration = '');
      return;
    }

    _updateDuration();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateDuration());
  }

  void _updateDuration() {
    if (widget.recordingStartTime == null) return;
    final elapsed = DateTime.now().difference(widget.recordingStartTime!);
    final min = (elapsed.inMinutes).toString().padLeft(2, '0');
    final sec = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    setState(() => _duration = '$min:$sec');
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusColor(),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _getStatusText(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_duration.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            _duration,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ],
    );
  }

  Color _getStatusColor() {
    if (!widget.isRecording) return Colors.grey;
    if (widget.isPaused) return Colors.amber;
    return Colors.redAccent;
  }

  String _getStatusText() {
    if (!widget.isRecording) return 'LISTO';
    if (widget.isPaused) return 'PAUSADO';
    return 'GRABANDO';
  }
}

class _ShareButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ShareButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blueAccent,
        ),
        child: const Icon(
          Icons.share,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
