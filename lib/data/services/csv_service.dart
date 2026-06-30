import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/logger.dart';
import '../models/detection_record.dart';

class CsvService {
  File? _currentFile;
  String? _currentDate;
  final List<DetectionRecord> _buffer = [];
  Timer? _flushTimer;
  Timer? _autoSaveTimer;
  final AppLogger _logger = AppLogger();

  int _totalRecordsWritten = 0;
  int _totalFlushes = 0;
  DateTime? _lastFlushTime;
  bool _isDisposed = false;

  // Getters for statistics
  int get totalRecordsWritten => _totalRecordsWritten;
  int get totalFlushes => _totalFlushes;
  DateTime? get lastFlushTime => _lastFlushTime;
  int get pendingRecords => _buffer.length;

  Future<String> get _directoryPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  String _getFileName(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return 'dorsales_$dateStr.csv';
  }

  Future<File> _getFile() async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);

    if (_currentFile != null && _currentDate == dateStr) {
      return _currentFile!;
    }

    final dirPath = await _directoryPath;
    final fileName = _getFileName(now);
    final filePath = '$dirPath/$fileName';

    _currentFile = File(filePath);
    _currentDate = dateStr;

    if (!await _currentFile!.exists()) {
      await _currentFile!.writeAsString('${DetectionRecord.csvHeader}\n');
      _logger.info('Created new CSV file: $fileName');
    } else {
      // Validate existing file integrity
      await _validateFileIntegrity(_currentFile!);
    }

    return _currentFile!;
  }

  Future<void> _validateFileIntegrity(File file) async {
    try {
      final content = await file.readAsString();
      final lines = content.split('\n');

      // Check if file has header
      if (lines.isEmpty || !lines.first.contains('Dorsal,Hora_Paso')) {
        _logger.warning('CSV file missing header, adding it');
        final tempContent = content;
        await file.writeAsString('${DetectionRecord.csvHeader}\n');
        await file.writeAsString(tempContent, mode: FileMode.append);
      }

      // Check for truncated lines
      int truncatedCount = 0;
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          final parts = line.split(',');
          if (parts.length < 2) {
            truncatedCount++;
          }
        }
      }

      if (truncatedCount > 0) {
        _logger.warning('Found $truncatedCount truncated lines in CSV');
      }
    } catch (e) {
      _logger.error('Error validating CSV integrity', e);
    }
  }

  Future<void> appendRecord(DetectionRecord record) async {
    if (_isDisposed) return;

    _buffer.add(record);
    _totalRecordsWritten++;

    // Smart flush: either by count or by timer
    if (_buffer.length >= AppConstants.csvFlushCount) {
      await flush();
    } else {
      // Reset timer on each new record
      _flushTimer?.cancel();
      _flushTimer = Timer(
        Duration(seconds: AppConstants.csvFlushIntervalSeconds),
        () => flush(),
      );
    }
  }

  Future<void> forceAppendRecord(DetectionRecord record) async {
    // Immediately write to disk without buffering
    try {
      final file = await _getFile();
      final line = '${record.toCsvLine()}\n';
      await file.writeAsString(line, mode: FileMode.append);
      _totalRecordsWritten++;
      _lastFlushTime = DateTime.now();
      _logger.debug('Force-appended record: ${record.dorsal}');
    } catch (e) {
      _logger.error('Error force-appending record', e);
      throw StorageException('Error al escribir registro', e);
    }
  }

  Future<void> rewriteAll(List<DetectionRecord> records) async {
    if (_isDisposed) return;
    try {
      final snapshot = List<DetectionRecord>.from(records);
      final file = await _getFile();
      final buf = StringBuffer('${DetectionRecord.csvHeader}\n');
      for (final record in snapshot) {
        buf.writeln(record.toCsvLine());
      }
      await file.writeAsString(buf.toString());
      _buffer.clear();
      _totalRecordsWritten = snapshot.length;
      _lastFlushTime = DateTime.now();
      _logger.info('CSV rewritten with ${snapshot.length} records');
    } catch (e) {
      _logger.error('Error rewriting CSV', e);
      throw StorageException('Error al reescribir CSV', e);
    }
  }

  Future<void> clearAll() async {
    await rewriteAll([]);
  }

  Future<void> flush() async {
    if (_buffer.isEmpty || _isDisposed) return;

    try {
      final file = await _getFile();
      final lines = _buffer.map((r) => r.toCsvLine()).join('\n');
      await file.writeAsString('$lines\n', mode: FileMode.append);

      _totalFlushes++;
      _lastFlushTime = DateTime.now();

      _logger.debug('Flushed ${_buffer.length} records to CSV (total: $_totalRecordsWritten)');
      _buffer.clear();
    } catch (e) {
      _logger.error('Error flushing CSV', e);
      throw StorageException('Error al escribir en CSV', e);
    }
  }

  Future<List<DetectionRecord>> loadExisting() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

      if (lines.length <= 1) return [];

      final records = <DetectionRecord>[];
      int skippedLines = 0;

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = line.split(',');
        if (parts.length < 2) {
          skippedLines++;
          continue;
        }

        final dorsal = parts[0].trim();
        final timeStr = parts[1].trim();

        // Validate dorsal format
        if (!RegExp(r'^\d{1,4}$').hasMatch(dorsal)) {
          skippedLines++;
          continue;
        }

        try {
          DateTime timestamp;

          if (timeStr.contains('-') && timeStr.contains(',')) {
            final dtParts = timeStr.split(',');
            if (dtParts.length != 2) {
              skippedLines++;
              continue;
            }
            final dateStr = dtParts[0].trim();
            final hourStr = dtParts[1].trim();
            final dateParts = dateStr.split('-');
            if (dateParts.length != 3) {
              skippedLines++;
              continue;
            }
            final year = int.parse(dateParts[0]);
            final month = int.parse(dateParts[1]);
            final day = int.parse(dateParts[2]);
            final timeParts = hourStr.split(':');
            if (timeParts.length != 3) {
              skippedLines++;
              continue;
            }
            final h = int.parse(timeParts[0]);
            final m = int.parse(timeParts[1]);
            final sParts = timeParts[2].split('.');
            final s = int.parse(sParts[0]);
            final ms = sParts.length > 1 ? int.parse(sParts[1]) : 0;
            timestamp = DateTime(year, month, day, h, m, s, ms);
          } else {
            final now = DateTime.now();
            final timeParts = timeStr.split(':');
            if (timeParts.length == 3) {
              final h = int.parse(timeParts[0]);
              final m = int.parse(timeParts[1]);
              final sParts = timeParts[2].split('.');
              final s = int.parse(sParts[0]);
              final ms = sParts.length > 1 ? int.parse(sParts[1]) : 0;
              timestamp = DateTime(now.year, now.month, now.day, h, m, s, ms);
            } else {
              skippedLines++;
              continue;
            }
          }

          records.add(DetectionRecord(dorsal: dorsal, timestamp: timestamp));
        } catch (_) {
          skippedLines++;
          continue;
        }
      }

      if (skippedLines > 0) {
        _logger.warning('Skipped $skippedLines invalid lines while loading CSV');
      }

      _totalRecordsWritten = records.length;
      _logger.info('Loaded ${records.length} existing records from CSV');
      return records;
    } catch (e) {
      _logger.error('Error loading existing CSV', e);
      return [];
    }
  }

  Future<String> getCurrentFilePath() async {
    final file = await _getFile();
    return file.path;
  }

  Future<Map<String, dynamic>> getStatistics() async {
    final file = await _getCurrentFileIfExists();
    int fileLines = 0;

    if (file != null && await file.exists()) {
      final content = await file.readAsString();
      fileLines = content.split('\n').where((l) => l.trim().isNotEmpty).length - 1; // -1 for header
    }

    return {
      'totalRecordsWritten': _totalRecordsWritten,
      'totalFlushes': _totalFlushes,
      'lastFlushTime': _lastFlushTime?.toIso8601String(),
      'pendingRecords': _buffer.length,
      'fileRecords': fileLines,
      'currentFile': _currentFile?.path,
    };
  }

  Future<File?> _getCurrentFileIfExists() async {
    if (_currentFile != null) return _currentFile;

    try {
      final now = DateTime.now();
      final dirPath = await _directoryPath;
      final fileName = _getFileName(now);
      final filePath = '$dirPath/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        _currentFile = file;
        _currentDate = DateFormat('yyyy-MM-dd').format(now);
        return file;
      }
    } catch (_) {}

    return null;
  }

  void startAutoSave({Duration interval = const Duration(seconds: 10)}) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(interval, (_) {
      if (_buffer.isNotEmpty) {
        flush();
      }
    });
    _logger.info('Auto-save started with interval: ${interval.inSeconds}s');
  }

  void stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _logger.info('Auto-save stopped');
  }

  void dispose() {
    _isDisposed = true;
    _flushTimer?.cancel();
    _autoSaveTimer?.cancel();

    // Final flush
    if (_buffer.isNotEmpty) {
      flush();
    }

    _logger.info('CSV service disposed. Stats: $_totalRecordsWritten records, $_totalFlushes flushes');
  }
}
