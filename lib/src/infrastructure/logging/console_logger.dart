import 'dart:convert';

import 'log_level.dart';
import 'logger.dart';

/// Console logger with formatted, colorized output and optional borders.
/// Supports ANSI colors, pretty-printed JSON context, timestamps, and error formatting.
///
/// #### Example
/// ```dart
/// // Basic logger
/// final logger = ConsoleLogger();
/// logger.info('Transaction sent', context: {'txHash': '0xabc...'});
///
/// // Fancy logger with borders and timestamps
/// final fancyLogger = ConsoleLogger(
///   includeTimestamp: true,
///   prettyPrintContext: true,
///   showBorders: true,
/// );
/// fancyLogger.error('Failed to fetch account', error: exception);
///
/// // Production logger (errors only, no colors)
/// final prodLogger = ConsoleLogger(
///   minLevel: LogLevel.error,
///   useColors: false,
/// );
/// ```
class ConsoleLogger extends Logger {
  /// Creates console logger.
  ConsoleLogger({
    this.minLevel = LogLevel.debug,
    this.includeTimestamp = false,
    this.prettyPrintContext = false,
    this.showBorders = false,
    this.useColors = true,
  });

  /// Min log level to output.
  final LogLevel minLevel;

  /// Include timestamps.
  final bool includeTimestamp;

  /// Pretty-print context objects.
  final bool prettyPrintContext;

  /// Show decorative borders.
  final bool showBorders;

  /// Use ANSI colors.
  final bool useColors;

  static const String _reset = '\x1B[0m';
  static const String _grey = '\x1B[90m';
  static const String _lightBlue = '\x1B[38;2;156;220;254m';
  static const String _yellow = '\x1B[33m';
  static const String _orange = '\x1B[38;2;206;145;120m';
  static const String _red = '\x1B[31m';
  static const String _brightRed = '\x1B[91m';
  static const String _green = '\x1B[32m';

  /// Logs message to console with formatting.
  ///
  /// #### Parameters
  /// - `level` - Log severity level
  /// - `message` - Log message text
  /// - `context` - Optional structured context data
  /// - `error` - Optional error object to display
  /// - `stackTrace` - Optional stack trace to display
  ///
  /// #### Example
  /// ```dart
  /// final logger = ConsoleLogger(
  ///   minLevel: LogLevel.debug,
  ///   prettyPrintContext: true,
  ///   showBorders: true,
  /// );
  ///
  /// logger.log(
  ///   LogLevel.info,
  ///   'Account loaded',
  ///   context: {'address': 'erd1...', 'balance': '1000000000000000000'},
  /// );
  ///
  /// try {
  ///   // operation
  /// } catch (e, stack) {
  ///   logger.log(
  ///     LogLevel.error,
  ///     'Operation failed',
  ///     error: e,
  ///     stackTrace: stack,
  ///   );
  /// }
  /// ```
  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level < minLevel) return;

    final String color = useColors ? _getColorForLevel(level) : '';
    final String resetColor = useColors ? _reset : '';
    final String borderColor = useColors ? _getBorderColorForLevel(level) : '';
    final String contextColor = useColors ? _grey : '';

    if (showBorders) {
      print('$borderColor┌${'─' * 78}┐$resetColor');
    }

    final StringBuffer buffer = StringBuffer();

    if (showBorders) {
      buffer.write('$borderColor│$resetColor ');
    }

    if (includeTimestamp) {
      buffer.write(
        '$contextColor[${DateTime.now().toIso8601String()}]$resetColor ',
      );
    }

    buffer.write('$color${_getLevelPrefix(level)}$resetColor: ');

    buffer.write(message);

    if (context != null && context.isNotEmpty) {
      if (prettyPrintContext) {
        buffer.write('\n');
        if (showBorders) buffer.write('$borderColor│$resetColor ');
        buffer.write('$contextColor  Context:$resetColor');

        final String jsonStr = const JsonEncoder.withIndent('  ')
            .convert(context);

        final String colorizedJson = useColors
            ? _colorizeJson(jsonStr)
            : jsonStr;

        final List<String> lines = colorizedJson.split('\n');
        for (final String line in lines) {
          buffer.write('\n');
          if (showBorders) buffer.write('$borderColor│$resetColor ');
          buffer.write('  $line');
        }
      } else {
        buffer.write(' $context');
      }
    }

    print(buffer.toString());

    if (error != null) {
      if (showBorders) {
        print('$borderColor│$resetColor ');
        print('$borderColor│$resetColor   ${_red}Error: $error$resetColor');
      } else {
        print('  ${_red}Error: $error$resetColor');
      }
    }

    if (stackTrace != null) {
      if (showBorders) {
        print('$borderColor│$resetColor ');
        print('$borderColor│$resetColor   ${_grey}Stack trace:$resetColor');
        final List<String> stackLines = stackTrace.toString().split('\n');
        for (final String line in stackLines) {
          if (line.isNotEmpty) {
            print('$borderColor│$resetColor   $contextColor$line$resetColor');
          }
        }
      } else {
        print(
          '  ${_grey}Stack trace:$resetColor\n$contextColor$stackTrace$resetColor',
        );
      }
    }

    if (showBorders) {
      print('$borderColor└${'─' * 78}┘$resetColor');
    }
  }

  /// Gets color for log level.
  String _getColorForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return _grey;
      case LogLevel.info:
        return _green;
      case LogLevel.warning:
        return _yellow;
      case LogLevel.error:
        return _red;
      case LogLevel.critical:
        return _brightRed;
    }
  }

  /// Gets border color for log level.
  String _getBorderColorForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return _reset;
      case LogLevel.info:
        return _green;
      case LogLevel.warning:
        return _yellow;
      case LogLevel.error:
        return _red;
      case LogLevel.critical:
        return _brightRed;
    }
  }

  /// Colorizes JSON with different colors for keys and values.
  String _colorizeJson(String jsonStr) {
    final StringBuffer result = StringBuffer();
    final RegExp keyValuePattern = RegExp(
      r'"([^"]+)":\s*("(?:[^"\\]|\\.)*"|\d+|true|false|null)',
    );

    int lastIndex = 0;
    for (final Match match in keyValuePattern.allMatches(jsonStr)) {
      if (match.start > lastIndex) {
        result.write(
          '$_grey${jsonStr.substring(lastIndex, match.start)}$_reset',
        );
      }

      result.write('$_lightBlue"${match.group(1)}"$_reset');
      result.write('$_grey: $_reset');

      final String? value = match.group(2);
      result.write('$_orange$value$_reset');

      lastIndex = match.end;
    }

    if (lastIndex < jsonStr.length) {
      result.write('$_grey${jsonStr.substring(lastIndex)}$_reset');
    }

    return result.toString();
  }

  /// Gets level prefix for output.
  String _getLevelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.critical:
        return 'CRITICAL';
    }
  }
}
