import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:pub_semver/pub_semver.dart';

/// Writes generated sources to disk.
///
/// Dart output is formatted before it is written, so generated code satisfies
/// `dart format --set-exit-if-changed` in the projects that consume it. A
/// project whose CI enforces formatting would otherwise fail on its own
/// generated sources.
class FileWriter {
  /// Creates a file writer.
  FileWriter() : _formatter = DartFormatter(languageVersion: _targetVersion());

  /// Language version to format for.
  ///
  /// Formatting follows the language version of the SDK running the generator,
  /// because that is the same SDK whose `dart format` will later check the
  /// output. Formatting for a newer version than that SDK understands produces
  /// a layout its formatter would rewrite, which is exactly the mismatch this
  /// method avoids. The result is capped at the newest version the bundled
  /// formatter supports, so a future SDK still formats successfully.
  ///
  /// #### Returns
  /// `Version` - Language version used for formatting.
  static Version _targetVersion() {
    final Match? match = RegExp(
      r'^(\d+)\.(\d+)\.',
    ).firstMatch(Platform.version);
    if (match == null) {
      return DartFormatter.latestLanguageVersion;
    }
    final Version running = Version(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      0,
    );
    return running < DartFormatter.latestLanguageVersion
        ? running
        : DartFormatter.latestLanguageVersion;
  }

  final DartFormatter _formatter;

  /// Formats [content] when [path] is a Dart source file.
  ///
  /// Content that cannot be parsed is returned unchanged so that generation
  /// still produces a file: the analyzer then reports the real syntax error at
  /// the offending line instead of the run failing with a formatter message.
  ///
  /// #### Parameters
  /// - `path` - Destination path, used to decide whether to format
  /// - `content` - Source text to format
  ///
  /// #### Returns
  /// `String` - Formatted source, or `content` unchanged.
  String _formatIfDart(String path, String content) {
    if (!path.endsWith('.dart')) {
      return content;
    }
    try {
      return _formatter.format(content);
    } on FormatterException {
      return content;
    }
  }

  /// Writes [content] to [path], creating parent directories as needed.
  ///
  /// #### Parameters
  /// - `path` - Destination path
  /// - `content` - File contents
  Future<void> writeFile(String path, String content) async {
    final File file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(_formatIfDart(path, content));
  }

  /// Synchronous counterpart of [writeFile].
  ///
  /// #### Parameters
  /// - `path` - Destination path
  /// - `content` - File contents
  void writeFileSync(String path, String content) {
    final File file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(_formatIfDart(path, content));
  }
}
