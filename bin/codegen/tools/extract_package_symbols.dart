/// Extracts public symbols from lib/ and generates known_package_symbols.dart
///
/// Usage: dart run bin/codegen/tools/extract_package_symbols.dart
library;

import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('Error: lib/ directory not found. Run from project root.');
    exit(1);
  }

  print('Scanning lib/ for public symbols...');

  final symbols = <String>{};
  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  for (final file in files) {
    _extractSymbolsFromFile(file, symbols);
  }

  final sortedSymbols = symbols.toList()..sort();

  print(
    'Found ${sortedSymbols.length} public symbols in ${files.length} files',
  );

  // Generate the output file
  final buffer = StringBuffer();
  buffer.writeln('/// Auto-generated list of known package symbols');
  buffer.writeln('/// Generated on: ${DateTime.now().toIso8601String()}');
  buffer.writeln('///');
  buffer.writeln(
    '/// Run: dart run bin/codegen/tools/extract_package_symbols.dart',
  );
  buffer.writeln();
  buffer.writeln('const knownPackageSymbols = <String>{');
  for (final symbol in sortedSymbols) {
    buffer.writeln("  '$symbol',");
  }
  buffer.writeln('};');

  final outputFile = File('bin/codegen/core/known_package_symbols.dart');
  outputFile.writeAsStringSync(buffer.toString());

  print('Output written to: bin/codegen/core/known_package_symbols.dart');
}

void _extractSymbolsFromFile(File file, Set<String> symbols) {
  final content = file.readAsStringSync();
  final lines = content.split('\n');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();

    if (line.startsWith('_')) continue;

    if (line.startsWith('//') ||
        line.startsWith('/*') ||
        line.startsWith('*')) {
      continue;
    }

    // Match: abstract, final, base, sealed, interface class
    final classMatch = RegExp(
      r'^(?:abstract\s+)?(?:final\s+)?(?:base\s+)?(?:sealed\s+)?(?:interface\s+)?class\s+(\w+)',
    ).firstMatch(line);
    if (classMatch != null) {
      final name = classMatch.group(1)!;
      if (!name.startsWith('_')) symbols.add(name);
      continue;
    }

    final enumMatch = RegExp(r'^enum\s+(\w+)').firstMatch(line);
    if (enumMatch != null) {
      final name = enumMatch.group(1)!;
      if (!name.startsWith('_')) symbols.add(name);
      continue;
    }

    final typedefMatch = RegExp(r'^typedef\s+(\w+)').firstMatch(line);
    if (typedefMatch != null) {
      final name = typedefMatch.group(1)!;
      if (!name.startsWith('_')) symbols.add(name);
      continue;
    }

    final mixinMatch = RegExp(r'^mixin\s+(\w+)').firstMatch(line);
    if (mixinMatch != null) {
      final name = mixinMatch.group(1)!;
      if (!name.startsWith('_')) symbols.add(name);
      continue;
    }

    final extensionMatch = RegExp(r'^extension\s+(\w+)').firstMatch(line);
    if (extensionMatch != null) {
      final name = extensionMatch.group(1)!;
      if (!name.startsWith('_')) symbols.add(name);
      continue;
    }
  }
}
