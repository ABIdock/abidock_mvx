import 'known_package_symbols.dart';

class ImportManager {
  final Set<String> _dartImports = {};
  final Set<String> _packageImports = {};
  final Map<String, String> _relativeImports = {};

  void addDartImport(String library) {
    if (library != 'dart:core') {
      _dartImports.add(library);
    }
  }

  void addPackageImport(String package) {
    _packageImports.add(package);
  }

  void addRelativeImport(String path, {String? alias}) {
    _relativeImports[path] = alias ?? '';
  }

  String generate() {
    final buffer = StringBuffer();

    final dartSorted = _dartImports.toList()..sort();
    for (final import in dartSorted) {
      buffer.writeln("import '$import';");
    }

    if (_dartImports.isNotEmpty && _packageImports.isNotEmpty) {
      buffer.writeln();
    }

    final localSymbols = <String>{};
    for (final path in _relativeImports.keys) {
      final filename = path.split('/').last.replaceAll('.dart', '');
      final symbolName = _toPascalCase(filename);
      localSymbols.add(symbolName);
    }

    final conflicts = localSymbols.intersection(knownPackageSymbols);

    final pkgSorted = _packageImports.toList()..sort();
    for (final import in pkgSorted) {
      if (conflicts.isNotEmpty &&
          import == 'package:abidock_mvx/abidock_mvx.dart') {
        final hideList = conflicts.toList()..sort();
        buffer.write("import '$import' hide ${hideList.join(', ')}");
        buffer.writeln(';');
      } else {
        buffer.writeln("import '$import';");
      }
    }

    if (_packageImports.isNotEmpty && _relativeImports.isNotEmpty) {
      buffer.writeln();
    }

    final relativeSorted = _relativeImports.keys.toList()..sort();
    for (final path in relativeSorted) {
      final alias = _relativeImports[path]!;
      if (alias.isEmpty) {
        buffer.writeln("import '$path';");
      } else {
        buffer.writeln("import '$path' as $alias;");
      }
    }

    return buffer.toString();
  }

  String _toPascalCase(String input) {
    if (input.isEmpty) return input;

    final words = input.split('_');
    return words
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join('');
  }

  void clear() {
    _dartImports.clear();
    _packageImports.clear();
    _relativeImports.clear();
  }
}
