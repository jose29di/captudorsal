import 'package:flutter_test/flutter_test.dart';
import 'package:captudorsal/data/models/detection_record.dart';

void main() {
  group('DetectionRecord', () {
    test('should create a record with dorsal and timestamp', () {
      final now = DateTime(2024, 1, 15, 10, 30, 45, 123);
      final record = DetectionRecord(dorsal: '742', timestamp: now);

      expect(record.dorsal, '742');
      expect(record.timestamp, now);
    });

    test('should format time correctly', () {
      final now = DateTime(2024, 1, 15, 9, 14, 22, 105);
      final record = DetectionRecord(dorsal: '742', timestamp: now);

      expect(record.formattedTime, '09:14:22.105');
    });

    test('should convert to CSV line correctly', () {
      final now = DateTime(2024, 1, 15, 9, 14, 22, 105);
      final record = DetectionRecord(dorsal: '742', timestamp: now);

      expect(record.toCsvLine(), '742,2024-01-15,09:14:22.105');
    });

    test('should return correct CSV header', () {
      expect(DetectionRecord.csvHeader, 'Dorsal,Fecha_Hora');
    });

    test('should serialize to JSON correctly', () {
      final now = DateTime(2024, 1, 15, 10, 30, 45, 123);
      final record = DetectionRecord(dorsal: '742', timestamp: now);
      final json = record.toJson();

      expect(json['dorsal'], '742');
      expect(json['timestamp'], now.toIso8601String());
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'dorsal': '742',
        'timestamp': '2024-01-15T10:30:45.123',
      };
      final record = DetectionRecord.fromJson(json);

      expect(record.dorsal, '742');
      expect(record.timestamp, DateTime(2024, 1, 15, 10, 30, 45, 123));
    });

    test('should be equal when dorsal and timestamp are equal', () {
      final now = DateTime(2024, 1, 15, 10, 30, 45, 123);
      final record1 = DetectionRecord(dorsal: '742', timestamp: now);
      final record2 = DetectionRecord(dorsal: '742', timestamp: now);

      expect(record1, equals(record2));
      expect(record1.hashCode, equals(record2.hashCode));
    });

    test('should not be equal when dorsals are different', () {
      final now = DateTime(2024, 1, 15, 10, 30, 45, 123);
      final record1 = DetectionRecord(dorsal: '742', timestamp: now);
      final record2 = DetectionRecord(dorsal: '1024', timestamp: now);

      expect(record1, isNot(equals(record2)));
    });

    test('should have correct string representation', () {
      final now = DateTime(2024, 1, 15, 9, 14, 22, 105);
      final record = DetectionRecord(dorsal: '742', timestamp: now);

      expect(record.toString(), '[742] → 09:14:22.105');
    });
  });
}
