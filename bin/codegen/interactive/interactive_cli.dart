import 'dart:convert';
import 'dart:io';

import '../core/codegen_config.dart';

class InteractiveCLI {
  Future<CodegenConfig?> run() async {
    print('');
    print('🚀 Abidock CodeGen - Interactive Mode');
    print('═' * 60);
    print('');

    try {
      final abiPath = await _promptPath(
        'ABI File path',
        hint: 'Path to the smart contract ABI JSON file',
        defaultValue: 'assets/contract.abi.json',
        mustExist: true,
      );
      if (abiPath == null) return null;
      final outputDir = await _promptPath(
        'Output Directory',
        hint: 'Where to generate the Dart code',
        defaultValue: 'lib/generated/contract',
        mustExist: false,
      );
      if (outputDir == null) return null;
      final contractName = await _promptString(
        'Contract Name',
        hint: 'Used for naming the generated files',
        defaultValue: 'contract',
        validator: (value) {
          if (value.isEmpty) return 'Contract name cannot be empty';
          if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(value)) {
            return 'Must start with letter, only letters/numbers/underscore allowed';
          }
          return null;
        },
      );
      if (contractName == null) return null;

      print('');
      print('📋 Features Configuration');
      print('─' * 60);

      final features = await _promptFeatures();

      print('');
      print('📊 Configuration Preview');
      print('═' * 60);
      print('ABI File:        $abiPath');
      print('Output Dir:      $outputDir');
      print('Contract Name:   $contractName');
      print('');
      print('Features:');
      print('  Logger injection:     ${features['useLogger']! ? '✓' : '✗'}');
      print('  Transfer helpers:     ${features['useTransfers']! ? '✓' : '✗'}');
      print('  Auto gas estimation:  ${features['useAutoGas']! ? '✓' : '✗'}');
      print('');
      print('Note: Relayer and guardian parameters are always available.');
      print('');

      final estimate = await _estimateGeneration(abiPath);
      print('Estimated output:');
      print('  Files:     ~${estimate['files']}');
      print('  Time:      ~${estimate['time']}ms');
      print('');

      final proceed = await _promptYesNo(
        'Proceed with generation?',
        defaultValue: true,
      );

      if (!proceed) {
        print('');
        print('❌ Generation cancelled by user');
        return null;
      }

      return CodegenConfig(
        abiPath: abiPath,
        outputDir: outputDir,
        contractName: contractName,
        useLogger: features['useLogger']!,
        useTransfers: features['useTransfers']!,
        useAutoGas: features['useAutoGas']!,
      );
    } catch (e) {
      print('');
      print('❌ Error: $e');
      return null;
    }
  }

  Future<String?> _promptPath(
    String label, {
    required String hint,
    required String defaultValue,
    required bool mustExist,
  }) async {
    while (true) {
      print('');
      print('$label:');
      print('  $hint');
      stdout.write('  Path [$defaultValue]: ');

      final input = stdin.readLineSync()?.trim() ?? '';
      final path = input.isEmpty ? defaultValue : input;

      if (mustExist) {
        if (!File(path).existsSync() && !Directory(path).existsSync()) {
          print('  ❌ Path does not exist: $path');
          final retry = await _promptYesNo('Try again?', defaultValue: true);
          if (!retry) return null;
          continue;
        }
      }

      return path;
    }
  }

  Future<String?> _promptString(
    String label, {
    required String hint,
    required String defaultValue,
    String? Function(String)? validator,
  }) async {
    while (true) {
      print('');
      print('$label:');
      print('  $hint');
      stdout.write('  Value [$defaultValue]: ');

      final input = stdin.readLineSync()?.trim() ?? '';
      final value = input.isEmpty ? defaultValue : input;

      if (validator != null) {
        final error = validator(value);
        if (error != null) {
          print('  ❌ $error');
          final retry = await _promptYesNo('Try again?', defaultValue: true);
          if (!retry) return null;
          continue;
        }
      }

      return value;
    }
  }

  Future<bool> _promptYesNo(
    String question, {
    required bool defaultValue,
  }) async {
    final defaultStr = defaultValue ? 'Y/n' : 'y/N';
    stdout.write('$question ($defaultStr): ');

    final input = stdin.readLineSync()?.trim().toLowerCase() ?? '';

    if (input.isEmpty) return defaultValue;
    if (input == 'y' || input == 'yes') return true;
    if (input == 'n' || input == 'no') return false;

    return defaultValue;
  }

  Future<Map<String, bool>> _promptFeatures() async {
    final features = <String, bool>{
      'useLogger': false,
      'useTransfers': false,
      'useAutoGas': false,
    };

    final descriptions = {
      'useLogger': 'Inject ConsoleLogger for debugging',
      'useTransfers': 'Generate EGLD/ESDT transfer helpers',
      'useAutoGas': 'Generate auto gas estimation methods',
    };

    print('');
    print('Select features to enable/disable:');
    print('(Press Enter to use defaults, or type y/n for each)');
    print('');

    for (final entry in features.entries) {
      final key = entry.key;
      final defaultValue = entry.value;
      final description = descriptions[key]!;

      final currentValue = await _promptYesNo(
        '  $description',
        defaultValue: defaultValue,
      );

      features[key] = currentValue;
    }

    return features;
  }

  Future<Map<String, int>> _estimateGeneration(String abiPath) async {
    try {
      final abiFile = File(abiPath);
      if (!abiFile.existsSync()) {
        return {'files': 150, 'time': 800};
      }

      final abiJson = jsonDecode(await abiFile.readAsString());
      final endpoints = (abiJson['endpoints'] as List?)?.length ?? 0;
      final events = (abiJson['events'] as List?)?.length ?? 0;
      final types = (abiJson['types'] as Map?)?.length ?? 0;

      final callFiles = endpoints;
      final queryFiles = endpoints;
      final modelFiles = types;
      final eventFiles = events * 2;
      final eventModelFiles = events;
      const otherFiles = 10;

      final totalFiles =
          callFiles +
          queryFiles +
          modelFiles +
          eventFiles +
          eventModelFiles +
          otherFiles;
      final estimatedTime = (totalFiles * 5).clamp(100, 5000);

      return {'files': totalFiles, 'time': estimatedTime};
    } catch (e) {
      return {'files': 150, 'time': 800};
    }
  }

  Future<void> showSummary({
    required int filesGenerated,
    required int linesGenerated,
    required int timeMs,
    required String outputDir,
  }) async {
    print('');
    print('✅ Generation Complete!');
    print('═' * 60);
    print('Files:     $filesGenerated');
    print('Lines:     $linesGenerated');
    print('Time:      ${timeMs}ms');
    print('Output:    $outputDir');
    print('');

    final openInEditor = await _promptYesNo(
      'Open output directory in file explorer?',
      defaultValue: false,
    );

    if (openInEditor) {
      if (Platform.isWindows) {
        await Process.run('explorer', [outputDir]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [outputDir]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [outputDir]);
      }
    }

    print('');
    print('🎉 Happy coding!');
    print('');
  }
}
