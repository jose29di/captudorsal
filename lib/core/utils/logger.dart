import 'package:logger/logger.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;

  late final Logger _logger;

  AppLogger._internal() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 5,
        lineLength: 80,
        colors: true,
        printEmojis: true,
      ),
    );
  }

  void info(String message) => _logger.i(message);
  void warning(String message) => _logger.w(message);
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
  void debug(String message) => _logger.d(message);
}
