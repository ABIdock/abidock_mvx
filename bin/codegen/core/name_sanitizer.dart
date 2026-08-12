class NameSanitizer {
  /// Dart reserved keywords and soft/contextual keywords that could cause
  /// compilation errors if used as identifiers in generated code.
  ///
  /// Reference: https://dart.dev/language/keywords
  static const _dartKeywords = {
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
    'covariant',
    'default',
    'deferred',
    'do',
    'dynamic',
    'else',
    'enum',
    'export',
    'extends',
    'extension',
    'external',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'function',
    'get',
    'hide',
    'if',
    'implements',
    'import',
    'in',
    'interface',
    'is',
    'late',
    'library',
    'mixin',
    'new',
    'null',
    'on',
    'operator',
    'part',
    'required',
    'rethrow',
    'return',
    'sealed',
    'set',
    'show',
    'static',
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
    'when',
    'while',
    'with',
    'yield',
  };

  /// System-name conflicts injected by the call / controller scaffold.
  /// Inputs matching any of these get a `Param` suffix to disambiguate.
  static const _commonConflicts = {
    'sender',
    'nonce',
    'gasLimit',
    'value',
    'controller',
    'relayer',
    'guardian',
    'factory',
  };

  /// Public read-only view of the canonical keyword set.
  static Set<String> get dartKeywords => _dartKeywords;

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

  /// Sanitizes an enum variant identifier. Appends `Value` on keyword collision.
  String sanitizeEnumVariant(String name) {
    final variant = toCamelCase(name);
    if (_dartKeywords.contains(variant.toLowerCase())) {
      return '${variant}Value';
    }
    return variant;
  }

  /// Sanitizes a class/type identifier. Appends `Type` on keyword collision.
  String sanitizeClassName(String name) {
    final pascal = toPascalCase(name);
    if (_dartKeywords.contains(pascal.toLowerCase())) {
      return '${pascal}Type';
    }
    return pascal;
  }

  /// True if [name] is a Dart reserved/contextual keyword.
  bool isDartKeyword(String name) => _dartKeywords.contains(name.toLowerCase());

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

  /// Converts [name] to `snake_case`, collapsing runs of underscores and
  /// trimming any leading or trailing underscore.
  String toSnakeCase(String name) {
    final normalized = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return normalized
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)}_${match.group(2)}',
        )
        .toLowerCase()
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
