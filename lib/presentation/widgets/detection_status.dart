import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presentation/providers/detection_provider.dart';
import '../../platform/services/ocr_isolate.dart';

class DetectionStatus extends StatefulWidget {
  const DetectionStatus({super.key});

  @override
  State<DetectionStatus> createState() => _DetectionStatusState();
}

class _DetectionStatusState extends State<DetectionStatus> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DetectionProvider>(
      builder: (context, detectionProvider, child) {
        final lastDorsal = detectionProvider.lastDetectedDorsal;
        final lastTime = detectionProvider.lastDetectionTime;
        final rawText = detectionProvider.lastRawText;
        final isProcessing = OcrIsolate.isProcessing;

        final isRecentDetection = lastTime != null &&
            DateTime.now().difference(lastTime).inSeconds < 3;

        return Stack(
          children: [
            if (isProcessing)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(
                            alpha: 0.3 + (_pulseController.value * 0.4),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Leyendo...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (rawText != null && rawText.isNotEmpty && !isRecentDetection)
              Positioned(
                bottom: 45,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'OCR: $rawText',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            if (isRecentDetection && lastDorsal != null)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.black, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          lastDorsal,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'REGISTRADO',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
