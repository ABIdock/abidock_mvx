import 'log_level.dart';

/// Abstract logger interface for MultiversX SDK.
/// Defines logging contract with severity levels and structured context.
///
/// #### Example
/// ```dart
/// // Implement custom logger
/// class FileLogger extends Logger {
///   final File logFile;
///   FileLogger(this.logFile);
///
///   @override
///   void log(LogLevel level, String message, {
///     Map<String, dynamic>? context,
///     Object? error,
///     StackTrace? stackTrace,
///   }) {
///     final entry = '${DateTime.now()} [$level] $message';
///     logFile.writeAsStringSync('$entry\n', mode: FileMode.append);
///   }
/// }
///
/// // Use convenience methods
/// final logger = ConsoleLogger();
/// logger.debug('Debugging info');
/// logger.info('Operation completed');
/// logger.warning('Deprecated API used');
/// logger.error('Network error', error: exception, stackTrace: stack);
/// ```
abstract class Logger {
  /// Logs message with level and optional context.
  ///
  /// #### Parameters
  /// - `level` - Severity level
  /// - `message` - Log message text
  /// - `context` - Optional structured metadata
  /// - `error` - Optional error object
  /// - `stackTrace` - Optional stack trace
  ///
  /// #### Example
  /// ```dart
  /// logger.log(
  ///   LogLevel.info,
  ///   'Transaction broadcasted',
  ///   context: {'hash': '0x123...', 'nonce': 42},
  /// );
  /// ```
  void log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  });

  /// Logs debug message.
  void debug(String message, {Map<String, dynamic>? context}) {
    log(LogLevel.debug, message, context: context);
  }

  /// Logs info message.
  ///
  /// #### Parameters
  /// - `message` - Info message text
  /// - `context` - Optional metadata
  ///
  /// #### Example
  /// ```dart
  /// logger.info('Account synced', context: {
  ///   'address': 'erd1...',
  ///   'balance': '1000000000000000000',
  /// });
  /// ```
  void info(String message, {Map<String, dynamic>? context}) {
    log(LogLevel.info, message, context: context);
  }

  /// Logs warning message.
  ///
  /// #### Parameters
  /// - `message` - Warning message text
  /// - `context` - Optional metadata
  ///
  /// #### Example
  /// ```dart
  /// logger.warning('Using deprecated API endpoint', context: {
  ///   'endpoint': '/legacy/accounts',
  ///   'replacement': '/v1/accounts',
  /// });
  /// ```
  void warning(String message, {Map<String, dynamic>? context}) {
    log(LogLevel.warning, message, context: context);
  }

  /// Logs error message.
  ///
  /// #### Parameters
  /// - `message` - Error message text
  /// - `error` - Optional exception object
  /// - `stackTrace` - Optional stack trace
  /// - `context` - Optional metadata
  ///
  /// #### Example
  /// ```dart
  /// try {
  ///   await fetchAccount(address);
  /// } catch (e, stack) {
  ///   logger.error(
  ///     'Failed to fetch account',
  ///     error: e,
  ///     stackTrace: stack,
  ///     context: {'address': address},
  ///   );
  /// }
  /// ```
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    log(
      LogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Logs critical error message.
  ///
  /// #### Parameters
  /// - `message` - Critical error message text
  /// - `error` - Optional exception object
  /// - `stackTrace` - Optional stack trace
  /// - `context` - Optional metadata
  ///
  /// #### Example
  /// ```dart
  /// try {
  ///   await wallet.sign(transaction);
  /// } catch (e, stack) {
  ///   logger.critical(
  ///     'Private key access failed',
  ///     error: e,
  ///     stackTrace: stack,
  ///     context: {'walletPath': wallet.path},
  ///   );
  /// }
  /// ```
  void critical(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    log(
      LogLevel.critical,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }
}
