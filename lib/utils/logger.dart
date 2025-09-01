import 'dart:developer' as developer;

/// Centralized logging utility for the application
class AppLogger {
  static const String _defaultTag = 'VendorApp';
  
  /// Log an informational message
  static void info(String message, [Object? data]) {
    developer.log(
      message,
      name: _defaultTag,
      level: 800, // Info level
      error: data,
    );
  }
  
  /// Log a warning message
  static void warning(String message, [Object? data]) {
    developer.log(
      message,
      name: _defaultTag,
      level: 900, // Warning level
      error: data,
    );
  }
  
  /// Log an error message
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _defaultTag,
      level: 1000, // Error level
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  /// Log a debug message (only in debug mode)
  static void debug(String message, [Object? data]) {
    assert(() {
      developer.log(
        message,
        name: _defaultTag,
        level: 700, // Debug level
        error: data,
      );
      return true;
    }());
  }
  
  /// Log with custom tag and level
  static void custom({
    required String message,
    required String tag,
    int level = 800,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: tag,
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
