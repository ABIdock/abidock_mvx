class ImportsFormatter {
  static String sortImports(List<String> imports) {
    final dartImports = <String>[];
    final packageImports = <String>[];
    final relativeImports = <String>[];

    for (final import in imports) {
      final trimmed = import.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('import \'dart:') ||
          trimmed.startsWith('import "dart:')) {
        dartImports.add(trimmed);
      } else if (trimmed.startsWith('import \'package:') ||
          trimmed.startsWith('import "package:')) {
        packageImports.add(trimmed);
      } else {
        relativeImports.add(trimmed);
      }
    }

    dartImports.sort();
    packageImports.sort();
    relativeImports.sort();

    final result = StringBuffer();

    if (dartImports.isNotEmpty) {
      for (final import in dartImports) {
        result.writeln(import);
      }
      if (packageImports.isNotEmpty || relativeImports.isNotEmpty) {
        result.writeln();
      }
    }

    if (packageImports.isNotEmpty) {
      for (final import in packageImports) {
        result.writeln(import);
      }
      if (relativeImports.isNotEmpty) {
        result.writeln();
      }
    }

    if (relativeImports.isNotEmpty) {
      for (final import in relativeImports) {
        result.writeln(import);
      }
    }

    return result.toString();
  }

  static String toSnakeCase(String camelCase) {
    return camelCase
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), '');
  }
}
