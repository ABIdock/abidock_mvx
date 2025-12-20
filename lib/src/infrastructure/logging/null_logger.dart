import 'log_level.dart';
import 'logger.dart';

/// Null logger that silently discards all log messages.
class NullLogger extends Logger {
  /// Discards log message (no-op implementation).
  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {}
}
