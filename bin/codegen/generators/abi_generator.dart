import 'dart:convert';
import 'dart:io';

import '../models/file_output.dart';
import 'generator_base.dart';

/// Embeds the source ABI JSON into a generated `abi.dart` file and exposes
/// a lazily-decoded [SmartContractAbi] singleton.
///
/// The original JSON is canonicalised through `jsonEncode(jsonDecode(...))`
/// before being written as a Dart string literal:
/// - removes any user whitespace / triple-quotes that could escape the
///   Dart string delimiter (real-world ABIs occasionally contain `'''`
///   in `docs` arrays);
/// - keeps the wire format byte-stable across regenerations regardless of
///   the source file's formatting;
/// - means the embedded literal can stay a regular Dart string with the
///   three meaningful escapes (`\`, `$`, `'`) applied explicitly.
///
/// The accessor uses `late final` so concurrent first-access from multiple
/// futures in the same isolate decode the ABI exactly once.
class AbiGenerator extends GeneratorBase {
  AbiGenerator({required this.abiPath});

  final String abiPath;

  @override
  List<FileOutput> generate() {
    final raw = File(abiPath).readAsStringSync();
    final canonical = jsonEncode(jsonDecode(raw));
    final escaped = canonical
        .replaceAll(r'\', r'\\')
        .replaceAll(r'$', r'\$')
        .replaceAll("'", r"\'");

    final buffer = StringBuffer();
    buffer.writeln(getGeneratedFileHeader());
    buffer.writeln("import 'package:abidock_mvx/abidock_mvx.dart';");
    buffer.writeln();
    buffer.writeln("const String abiJson = '$escaped';");
    buffer.writeln();
    buffer.writeln(
      'final SmartContractAbi abi = '
      'SmartContractAbi.fromJson(abiJson);',
    );

    return [FileOutput(path: 'abi.dart', content: buffer.toString())];
  }
}
