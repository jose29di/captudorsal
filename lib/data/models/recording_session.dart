class SessionDorsal {
  final String dorsal;
  final DateTime timestamp;
  final int offsetMs;

  const SessionDorsal({
    required this.dorsal,
    required this.timestamp,
    required this.offsetMs,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get formattedOffset {
    final totalSec = offsetMs ~/ 1000;
    final min = (totalSec ~/ 60).toString().padLeft(2, '0');
    final sec = (totalSec % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Map<String, dynamic> toJson() => {
        'dorsal': dorsal,
        'timestamp': timestamp.toIso8601String(),
        'offsetMs': offsetMs,
      };

  factory SessionDorsal.fromJson(Map<String, dynamic> json) {
    return SessionDorsal(
      dorsal: json['dorsal'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      offsetMs: json['offsetMs'] as int,
    );
  }
}

class RecordingSession {
  final int id;
  final String videoPath;
  final DateTime startTime;
  final DateTime endTime;
  final List<SessionDorsal> dorsals;

  const RecordingSession({
    required this.id,
    required this.videoPath,
    required this.startTime,
    required this.endTime,
    required this.dorsals,
  });

  int get durationMs => endTime.difference(startTime).inMilliseconds;

  String get formattedDuration {
    final totalSec = durationMs ~/ 1000;
    final min = (totalSec ~/ 60).toString().padLeft(2, '0');
    final sec = (totalSec % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  String get formattedDate {
    final d = startTime.day.toString().padLeft(2, '0');
    final mo = startTime.month.toString().padLeft(2, '0');
    final y = startTime.year.toString();
    final h = startTime.hour.toString().padLeft(2, '0');
    final m = startTime.minute.toString().padLeft(2, '0');
    return '$d/$mo/$y $h:$m';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoPath': videoPath,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'dorsals': dorsals.map((d) => d.toJson()).toList(),
      };

  factory RecordingSession.fromJson(Map<String, dynamic> json) {
    return RecordingSession(
      id: json['id'] as int,
      videoPath: json['videoPath'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      dorsals: (json['dorsals'] as List<dynamic>)
          .map((d) => SessionDorsal.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}
