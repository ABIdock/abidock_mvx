class KeywordSanitizer {
  static const dartKeywords = {
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
    'while',
    'with',
    'yield',
  };

  String sanitizeEnumVariant(String name) {
    if (dartKeywords.contains(name.toLowerCase())) {
      return '${name}Value';
    }
    return name;
  }

  String sanitizeFieldName(String name) {
    if (dartKeywords.contains(name.toLowerCase())) {
      return '${name}_';
    }
    return name;
  }

  String sanitizeClassName(String name) {
    if (dartKeywords.contains(name.toLowerCase())) {
      return '${name}Model';
    }
    return name;
  }

  String sanitizeParameterName(String name) {
    if (dartKeywords.contains(name.toLowerCase())) {
      return '${name}Value';
    }
    return name;
  }

  bool isKeyword(String name) {
    return dartKeywords.contains(name.toLowerCase());
  }
}
