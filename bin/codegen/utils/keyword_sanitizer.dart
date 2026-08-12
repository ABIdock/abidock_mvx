import '../core/name_sanitizer.dart';

/// Thin facade over [NameSanitizer]. Kept for source-compatibility with
/// existing generators; do not add new logic here — extend [NameSanitizer]
/// instead so every generator sees the same keyword set, the same suffixes,
/// and the same system-name conflict resolution.
class KeywordSanitizer {
  KeywordSanitizer([NameSanitizer? sanitizer])
    : _sanitizer = sanitizer ?? NameSanitizer();

  final NameSanitizer _sanitizer;

  /// Canonical Dart keyword set (delegates to [NameSanitizer.dartKeywords]).
  static Set<String> get dartKeywords => NameSanitizer.dartKeywords;

  /// Sanitizes an enum variant identifier.
  String sanitizeEnumVariant(String name) =>
      _sanitizer.sanitizeEnumVariant(name);

  /// Sanitizes a struct/event field identifier.
  String sanitizeFieldName(String name) => _sanitizer.sanitizeFieldName(name);

  /// Sanitizes a class/type identifier.
  String sanitizeClassName(String name) => _sanitizer.sanitizeClassName(name);

  /// Sanitizes a parameter identifier (includes system-conflict resolution).
  String sanitizeParameterName(String name) =>
      _sanitizer.sanitizeParamName(name);

  /// True if [name] is a Dart reserved/contextual keyword.
  bool isKeyword(String name) => _sanitizer.isDartKeyword(name);
}
