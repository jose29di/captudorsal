import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';class OcrIsolateResult {
  final List<String> dorsals;
  final String? rawText;

  OcrIsolateResult({
    this.dorsals = const [],
    this.rawText,
  });
}

class OcrIsolate {
  static bool _isRunning = false;
  static bool _isProcessing = false;
  static TextRecognizer? _recognizer;

  static int _minDigits = 1;
  static int _maxDigits = 4;
  static int _throttleMs = 500;

  static double _roiLeftPercent = 0.25;
  static double _roiTopPercent = 0.35;
  static double _roiWidthPercent = 0.50;
  static double _roiHeightPercent = 0.30;

  static bool get isRunning => _isRunning;
  static bool get isProcessing => _isProcessing;
  static int get currentThrottleMs => _throttleMs;

  static final AppLogger _logger = AppLogger();

  static void updateDigitConfig({required int minDigits, required int maxDigits}) {
    _minDigits = minDigits;
    _maxDigits = maxDigits;
    _logger.info('OCR digit config updated: $minDigits-$maxDigits');
  }

  static void updateThrottle(double ms) {
    _throttleMs = ms.toInt().clamp(AppConstants.minThrottleMs, AppConstants.maxThrottleMs);
    _logger.info('Throttle updated: ${_throttleMs}ms');
  }

  static void updateRoi({
    required double leftPercent,
    required double topPercent,
    required double widthPercent,
    required double heightPercent,
  }) {
    _roiLeftPercent = leftPercent;
    _roiTopPercent = topPercent;
    _roiWidthPercent = widthPercent;
    _roiHeightPercent = heightPercent;
    _logger.info('ROI updated: ${widthPercent}x$heightPercent at ($leftPercent, $topPercent)');
  }

  static Future<void> start() async {
    if (_isRunning) return;

    try {
      _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      _isRunning = true;
      _logger.info('OCR engine started (Latin script)');
    } catch (e) {
      _logger.error('Failed to start OCR engine', e);
      _isRunning = false;
    }
  }

  static Future<OcrIsolateResult> processImageFile(String imagePath) async {
    if (!_isRunning || _recognizer == null || _isProcessing) {
      debugPrint('[OCR] SKIP: running=$_isRunning, processing=$_isProcessing');
      return OcrIsolateResult();
    }

    _isProcessing = true;
    debugPrint('[OCR] processImageFile START');

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      debugPrint('[OCR] InputImage created, calling ML Kit...');
      final recognized = await _recognizer!.processImage(inputImage);
      debugPrint('[OCR] ML Kit done: ${recognized.blocks.length} blocks, text="${recognized.text.substring(0, recognized.text.length.clamp(0, 50))}"');

      final imageSize = await compute(_readJpegDimensionsSync, imagePath);
      debugPrint('[OCR] Image dimensions: ${imageSize.width.toInt()}x${imageSize.height.toInt()}');

      final dorsals = _extractAllDorsalsFromBlocks(
        recognized,
        imageSize.width.toInt(),
        imageSize.height.toInt(),
      );
      debugPrint('[OCR] Extracted dorsals: $dorsals');

      return OcrIsolateResult(
        dorsals: dorsals,
        rawText: recognized.text.trim(),
      );
    } catch (e, stack) {
      debugPrint('[OCR] ERROR: $e');
      debugPrint('[OCR] STACK: $stack');
      _logger.error('OCR file processing error: $e');
      return OcrIsolateResult();
    } finally {
      _isProcessing = false;
    }
  }

  static bool _isInsideRoi(double pointX, double pointY, int imageWidth, int imageHeight) {
    final roiLeft = _roiLeftPercent * imageWidth;
    final roiTop = _roiTopPercent * imageHeight;
    final roiRight = roiLeft + (_roiWidthPercent * imageWidth);
    final roiBottom = roiTop + (_roiHeightPercent * imageHeight);

    return pointX >= roiLeft && pointX <= roiRight && pointY >= roiTop && pointY <= roiBottom;
  }

  static List<String> _extractAllDorsalsFromBlocks(RecognizedText recognized, int imageWidth, int imageHeight) {
    final List<String> dorsals = [];
    final Set<String> seen = {};

    if (imageWidth > 0 && imageHeight > 0) {
      final roiLeft = _roiLeftPercent * imageWidth;
      final roiTop = _roiTopPercent * imageHeight;
      final roiRight = roiLeft + (_roiWidthPercent * imageWidth);
      final roiBottom = roiTop + (_roiHeightPercent * imageHeight);
      debugPrint('[OCR] ROI rect: ($roiLeft,$roiTop)-($roiRight,$roiBottom) in ${imageWidth}x$imageHeight');
    }

    for (final block in recognized.blocks) {
      if (imageWidth > 0 && imageHeight > 0) {
        final blockCenterX = block.boundingBox.center.dx;
        final blockCenterY = block.boundingBox.center.dy;
        final inside = _isInsideRoi(blockCenterX, blockCenterY, imageWidth, imageHeight);
        debugPrint('[OCR] block @($blockCenterX,$blockCenterY) text="${block.text.substring(0, block.text.length.clamp(0, 30))}" ${inside ? "INSIDE" : "OUTSIDE"}');
        if (!inside) {
          continue;
        }
      }

      for (final line in block.lines) {
        final lineText = line.text.trim();
        if (lineText.isEmpty) continue;

        final segments = lineText.split(RegExp(r'[^0-9]+'));
        bool foundAny = false;
        for (final seg in segments) {
          if (seg.isEmpty) continue;
          final cleaned = _validateAndCleanDorsal(seg);
          if (cleaned != null && !seen.contains(cleaned)) {
            seen.add(cleaned);
            dorsals.add(cleaned);
            foundAny = true;
            debugPrint('[OCR] dorsal found: $cleaned');
          }
        }

        if (!foundAny) {
          final lineDigits = lineText.replaceAll(RegExp(r'[^0-9]'), '');
          if (lineDigits.isNotEmpty) {
            final cleaned = _validateAndCleanDorsal(lineDigits);
            if (cleaned != null && !seen.contains(cleaned)) {
              seen.add(cleaned);
              dorsals.add(cleaned);
              debugPrint('[OCR] dorsal found (combined): $cleaned');
            }
          }
        }
      }
    }

    debugPrint('[OCR] total dorsals extracted: ${dorsals.length}');
    return dorsals;
  }

  static String? _validateAndCleanDorsal(String rawDigits) {
    if (rawDigits.isEmpty) return null;
    if (rawDigits.length < _minDigits || rawDigits.length > _maxDigits) return null;

    if (!RegExp(r'^\d+$').hasMatch(rawDigits)) return null;

    if (RegExp(r'^(\d)\1+$').hasMatch(rawDigits) && rawDigits.length > 2) {
      _logger.debug('Rejected repeated pattern: $rawDigits');
      return null;
    }

    if (rawDigits.length == 1) return null;

    return rawDigits;
  }

  static Size _readJpegDimensionsSync(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return Size.zero;
      final raf = file.openSync();
      final bytes = raf.readSync(65536);
      raf.closeSync();
      if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
        return Size.zero;
      }

      int? orientation;
      int? rawWidth;
      int? rawHeight;

      int i = 2;
      while (i + 1 < bytes.length) {
        if (bytes[i] != 0xFF) {
          i++;
          continue;
        }
        final marker = bytes[i + 1];
        i += 2;
        if (marker == 0xD8 || marker == 0xD9 ||
            (marker >= 0xD0 && marker <= 0xD7)) {
          continue;
        }
        if (i + 1 >= bytes.length) break;
        final length = (bytes[i] << 8) | bytes[i + 1];

        if (marker == 0xE1) {
          final parsed = _parseExifOrientation(bytes, i, length);
          if (parsed != null) orientation = parsed;
        }

        final isSof = (marker >= 0xC0 && marker <= 0xCF) &&
            marker != 0xC4 && marker != 0xC8 && marker != 0xCC;
        if (isSof) {
          if (i + 6 < bytes.length) {
            rawHeight = (bytes[i + 3] << 8) | bytes[i + 4];
            rawWidth = (bytes[i + 5] << 8) | bytes[i + 6];
          }
        }
        i += length;
      }

      if (rawWidth != null && rawHeight != null) {
        debugPrint('[OCR] JPEG raw: ${rawWidth}x$rawHeight, EXIF orientation: $orientation');
        if (orientation == 6 || orientation == 8) {
          debugPrint('[OCR] Applying EXIF rotation, swapping dimensions');
          return Size(rawHeight.toDouble(), rawWidth.toDouble());
        }
        return Size(rawWidth.toDouble(), rawHeight.toDouble());
      }
    } catch (e) {
      _logger.error('Failed to read JPEG dimensions: $e');
    }
    return Size.zero;
  }

  static int? _parseExifOrientation(List<int> bytes, int start, int length) {
    int pos = start + 2;
    if (pos + 6 > bytes.length) return null;
    const exifHeader = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00];
    for (int j = 0; j < 6; j++) {
      if (bytes[pos + j] != exifHeader[j]) return null;
    }
    pos += 6;

    if (pos + 8 > bytes.length) return null;
    final b0 = bytes[pos];
    final b1 = bytes[pos + 1];
    final bool le;
    if (b0 == 0x49 && b1 == 0x49) {
      le = true;
    } else if (b0 == 0x4D && b1 == 0x4D) {
      le = false;
    } else {
      return null;
    }
    final tiffStart = pos;
    pos += 8;

    final ifdOffset = _readU32(bytes, tiffStart + 4, le);
    int ifdPos = tiffStart + ifdOffset;
    if (ifdPos + 2 > bytes.length) return null;
    final entryCount = _readU16(bytes, ifdPos, le);
    ifdPos += 2;

    for (int e = 0; e < entryCount; e++) {
      if (ifdPos + 12 > bytes.length) return null;
      final tag = _readU16(bytes, ifdPos, le);
      if (tag == 0x0112) {
        return _readU16(bytes, ifdPos + 8, le);
      }
      ifdPos += 12;
    }
    return null;
  }

  static int _readU16(List<int> bytes, int pos, bool le) {
    if (pos + 1 >= bytes.length) return 0;
    return le
        ? bytes[pos] | (bytes[pos + 1] << 8)
        : (bytes[pos] << 8) | bytes[pos + 1];
  }

  static int _readU32(List<int> bytes, int pos, bool le) {
    if (pos + 3 >= bytes.length) return 0;
    return le
        ? bytes[pos] | (bytes[pos + 1] << 8) | (bytes[pos + 2] << 16) | (bytes[pos + 3] << 24)
        : (bytes[pos] << 24) | (bytes[pos + 1] << 16) | (bytes[pos + 2] << 8) | bytes[pos + 3];
  }

  static void stop() {
    _recognizer?.close();
    _recognizer = null;
    _isRunning = false;
    _logger.info('OCR engine stopped');
  }
}
