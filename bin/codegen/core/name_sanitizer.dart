class NameSanitizer {
  // Dart reserved keywords and soft/contextual keywords that could cause
  // compilation errors if used as identifiers in generated code.
  // Reference: https://dart.dev/language/keywords
  static const _dartKeywords = {
    // Reserved keywords
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'covariant', // Added: soft keyword
    'default',
    'deferred', // Added: soft keyword (import)
    'do',
    'dynamic', // Added: built-in type
    'else',
    'enum',
    'export', // Added: library directive
    'extends',
    'extension', // Added: Dart 2.7+
    'external', // Added: soft keyword
    'factory', // Added: soft keyword
    'false',
    'final',
    'finally',
    'for',
    'function', // Added: built-in type (lowercase to match identifier comparison)
    'get', // Added: soft keyword (getter)
    'hide', // Added: soft keyword (import)
    'if',
    'implements',
    'import', // Added: library directive
    'in',
    'interface',
    'is',
    'late', // Added: Dart 2.12+ (null safety)
    'library', // Added: library directive
    'mixin',
    'new',
    'null',
    'on', // Added: soft keyword (mixin)
    'operator', // Added: soft keyword
    'part', // Added: library directive
    'required', // Added: Dart 2.12+ (null safety)
    'rethrow', // Added: control flow
    'return',
    'sealed', // Added: Dart 3+ (patterns)
    'set', // Added: soft keyword (setter)
    'show', // Added: soft keyword (import)
    'static', // Added: soft keyword
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'when', // Added: Dart 3+ (patterns)
    'while',
    'with',
    'yield',
  };

  static const _commonConflicts = {
    'sender',
    'nonce',
    'gasLimit',
    'value',
    'controller',
  };

  String sanitizeFieldName(String name) {
    if (name.isEmpty) return 'field';

    var result = toCamelCase(name);

    if (RegExp(r'^\d').hasMatch(result)) {
      result = 'field$result';
    }

    if (_dartKeywords.contains(result.toLowerCase())) {
      result = '${result}Value';
    }

    result = result.replaceAll(RegExp(r'[^\w]'), '_');
    result = result.replaceFirst(RegExp(r'^_+'), '');

    return result;
  }

  String sanitizeParamName(String name) {
    var result = sanitizeFieldName(name);

    if (_commonConflicts.contains(result)) {
      result = '${result}Param';
    }

    return result;
  }

  String makeUnique(String name, Set<String> existingNames) {
    if (!existingNames.contains(name)) return name;

    var counter = 2;
    while (existingNames.contains('$name$counter')) {
      counter++;
    }
    return '$name$counter';
  }

  String toCamelCase(String name) {
    if (name.isEmpty) return name;
    final normalized = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final parts = normalized.split('_').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'value';
    if (parts.length == 1) {
      return parts[0][0].toLowerCase() + parts[0].substring(1);
    }
    return parts[0].toLowerCase() +
        parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }

  String toPascalCase(String name) {
    if (name.isEmpty) return name;
    final normalized = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final parts = normalized.split('_').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'Value';
    return parts.map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }

  String toSnakeCase(String name) {
    final normalized = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return normalized
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)}_${match.group(2)}',
        )
        .toLowerCase()
        .replaceAll(RegExp(r'_+'), '_') // collapse multiple underscores
        .replaceAll(RegExp(r'^_|_$'), ''); // trim leading/trailing underscores
  }
}
