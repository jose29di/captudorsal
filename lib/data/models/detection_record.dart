class DetectionRecord {
  final String dorsal;
  final DateTime timestamp;

  const DetectionRecord({
    required this.dorsal,
    required this.timestamp,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String get formattedDateTime {
    final d = timestamp.year.toString().padLeft(4, '0');
    final mo = timestamp.month.toString().padLeft(2, '0');
    final da = timestamp.day.toString().padLeft(2, '0');
    return '$d-$mo-$da,$formattedTime';
  }

  String toCsvLine() => '$dorsal,$formattedDateTime';
  static String get csvHeader => 'Dorsal,Fecha_Hora';

  Map<String, dynamic> toJson() => {
        'dorsal': dorsal,
        'timestamp': timestamp.toIso8601String(),
      };

  factory DetectionRecord.fromJson(Map<String, dynamic> json) {
    return DetectionRecord(
      dorsal: json['dorsal'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() => '[$dorsal] → $formattedTime';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectionRecord &&
          runtimeType == other.runtimeType &&
          dorsal == other.dorsal &&
          timestamp == other.timestamp;

  @override
  int get hashCode => dorsal.hashCode ^ timestamp.hashCode;
}
