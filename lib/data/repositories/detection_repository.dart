import '../models/detection_record.dart';
import '../services/csv_service.dart';
import '../../core/utils/logger.dart';

class DetectionRepository {
  final CsvService _csvService;
  final AppLogger _logger = AppLogger();

  DetectionRepository({
    required CsvService csvService,
  }) : _csvService = csvService;

  Future<void> saveRecord(DetectionRecord record) async {
    await _csvService.appendRecord(record);
  }

  Future<void> forceSaveRecord(DetectionRecord record) async {
    await _csvService.forceAppendRecord(record);
  }

  Future<void> saveRecords(List<DetectionRecord> records) async {
    for (final record in records) {
      await _csvService.appendRecord(record);
    }
  }

  Future<void> rewriteAll(List<DetectionRecord> records) async {
    await _csvService.rewriteAll(records);
  }

  Future<void> clearAll() async {
    await _csvService.clearAll();
  }

  Future<List<DetectionRecord>> loadRecords() async {
    final csvRecords = await _csvService.loadExisting();
    _logger.info('Loaded ${csvRecords.length} records from repository');
    return csvRecords;
  }

  Future<void> flush() async {
    await _csvService.flush();
  }

  Future<String> getCsvFilePath() async {
    return await _csvService.getCurrentFilePath();
  }

  Future<Map<String, dynamic>> getStatistics() async {
    return await _csvService.getStatistics();
  }

  void startAutoSave({Duration interval = const Duration(seconds: 10)}) {
    _csvService.startAutoSave(interval: interval);
  }

  void stopAutoSave() {
    _csvService.stopAutoSave();
  }
}
