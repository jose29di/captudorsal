import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/roi_provider.dart';

class RoiOverlay extends StatelessWidget {
  const RoiOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return IgnorePointer(
          child: Consumer<RoiProvider>(
            builder: (context, roiProvider, _) {
              final config = roiProvider.config;
              final roiLeft = constraints.maxWidth * config.leftPercent;
              final roiTop = constraints.maxHeight * config.topPercent;
              final roiWidth = constraints.maxWidth * config.widthPercent;
              final roiHeight = constraints.maxHeight * config.heightPercent;

              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _RoiPainter(
                  roiRect: Rect.fromLTWH(roiLeft, roiTop, roiWidth, roiHeight),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _RoiPainter extends CustomPainter {
  final Rect roiRect;

  _RoiPainter({required this.roiRect});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(roiRect, const Radius.circular(8)),
      borderPaint,
    );

    final cornerPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    const cornerLen = 16.0;
    final rRect = RRect.fromRectAndRadius(roiRect, const Radius.circular(8));
    final rect = rRect.outerRect;

    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cornerLen), cornerPaint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cornerLen), cornerPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -cornerLen), cornerPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _RoiPainter oldDelegate) =>
      oldDelegate.roiRect != roiRect;
}
