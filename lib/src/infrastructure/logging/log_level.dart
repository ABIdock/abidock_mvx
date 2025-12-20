/// Log level enum for categorizing log messages by severity.
/// Levels from least to most severe: debug, info, warning, error, critical.
///
/// #### Example
/// ```dart
/// // Compare severity
/// if (LogLevel.error > LogLevel.warning) {
///   print('Error is more severe');
/// }
///
/// // Use in logger
/// final logger = ConsoleLogger(minLevel: LogLevel.warning);
/// logger.log(LogLevel.debug, 'Hidden');
/// logger.log(LogLevel.error, 'Visible');
///
/// // Access severity
/// print('Error severity: ${LogLevel.error.severity}');
/// ```
enum LogLevel {
  /// Debug-level diagnostic messages.
  debug(0),

  /// Informational messages about normal operations.
  info(1),

  /// Warning messages for potentially problematic situations.
  warning(2),

  /// Error messages for failures that allow continued execution.
  error(3),

  /// Critical errors requiring immediate attention.
  critical(4);

  /// Severity level (higher = more severe).
  final int severity;

  const LogLevel(this.severity);

  /// Checks if this level is more severe than another.
  bool operator >(LogLevel other) => severity > other.severity;

  /// Checks if this level is more severe or equal to another.
  bool operator >=(LogLevel other) => severity >= other.severity;

  /// Checks if this level is less severe than another.
  bool operator <(LogLevel other) => severity < other.severity;

  /// Checks if this level is less severe or equal to another.
  bool operator <=(LogLevel other) => severity <= other.severity;
}
