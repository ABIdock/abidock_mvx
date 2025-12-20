import 'dart:io';
import '../models/file_output.dart';
import 'generator_base.dart';

class AbiGenerator extends GeneratorBase {
  final String abiPath;

  AbiGenerator({required this.abiPath});

  @override
  List<FileOutput> generate() {
    final abiContent = File(abiPath).readAsStringSync();

    final buffer = StringBuffer();
    buffer.writeln('import \'package:abidock_mvx/abidock_mvx.dart\';');
    buffer.writeln();
    buffer.writeln('const String abiJson = r\'\'\'');
    buffer.writeln(abiContent);
    buffer.writeln('\'\'\';');
    buffer.writeln();
    buffer.writeln('SmartContractAbi? _abi;');
    buffer.writeln();
    buffer.writeln('SmartContractAbi get abi {');
    buffer.writeln('  _abi ??= SmartContractAbi.fromJson(abiJson);');
    buffer.writeln('  return _abi!;');
    buffer.writeln('}');

    return [FileOutput(path: 'abi.dart', content: buffer.toString())];
  }
}
