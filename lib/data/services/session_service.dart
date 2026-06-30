import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/logger.dart';
import '../models/recording_session.dart';

class SessionService {
  static const String _keySessions = 'recording_sessions';
  final AppLogger _logger = AppLogger();
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _logger.info('SessionService initialized');
  }

  Future<Directory> _getVideosDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/videos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> getVideoPathForSession(int sessionId) async {
    final dir = await _getVideosDir();
    return '${dir.path}/session_$sessionId.mp4';
  }

  Future<void> saveSession(RecordingSession session) async {
    _prefs ??= await SharedPreferences.getInstance();
    try {
      final sessions = loadSessions();
      sessions.insert(0, session);
      final json = jsonEncode(sessions.map((s) => s.toJson()).toList());
      await _prefs!.setString(_keySessions, json);
      _logger.info('Session ${session.id} saved (${session.dorsals.length} dorsals)');
    } catch (e) {
      _logger.error('Error saving session', e);
    }
  }

  List<RecordingSession> loadSessions() {
    if (_prefs == null) return [];
    try {
      final json = _prefs!.getString(_keySessions);
      if (json == null) return [];
      final List<dynamic> decoded = jsonDecode(json);
      return decoded
          .map((s) => RecordingSession.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.error('Error loading sessions', e);
      return [];
    }
  }

  RecordingSession? getSession(int id) {
    final sessions = loadSessions();
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> deleteSession(int id) async {
    try {
      final session = getSession(id);
      if (session != null) {
        final file = File(session.videoPath);
        if (await file.exists()) {
          await file.delete();
          _logger.info('Video file deleted: ${session.videoPath}');
        }
      }
      _prefs ??= await SharedPreferences.getInstance();
      final sessions = loadSessions();
      sessions.removeWhere((s) => s.id == id);
      final json = jsonEncode(sessions.map((s) => s.toJson()).toList());
      await _prefs!.setString(_keySessions, json);
      _logger.info('Session $id deleted');
    } catch (e) {
      _logger.error('Error deleting session', e);
    }
  }

  Future<void> copyVideoToSessionDir(String sourcePath, int sessionId) async {
    try {
      final destPath = await getVideoPathForSession(sessionId);
      final source = File(sourcePath);
      final dest = File(destPath);
      await source.copy(destPath);
      _logger.info('Video copied to: $destPath (${await dest.length()} bytes)');
    } catch (e) {
      _logger.error('Error copying video', e);
    }
  }
}
