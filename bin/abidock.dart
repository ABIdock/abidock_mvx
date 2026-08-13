#!/usr/bin/env dart

import 'dart:io';

import 'codegen/cli/commands/generate_command.dart';
import 'codegen/cli/commands/init_command.dart';
import 'codegen/cli/commands/validate_command.dart';
import 'codegen/cli/commands/watch_command.dart';
import 'codegen/cli/help.dart';
import 'codegen/main.dart' as legacy_codegen;

void main(List<String> args) async {
  if (isHelpInvocation(args)) {
    printHelp();
    exit(0);
  }

  if (!args[0].startsWith('-')) {
    final String command = args[0].toLowerCase();

    switch (command) {
      case 'init':
        await _handleInit(args.sublist(1));
        exit(0);

      case 'generate':
        await _handleGenerate(args.sublist(1));
        exit(0);

      case 'validate':
        await _handleValidate(args.sublist(1));
        exit(0);

      case 'watch':
        await _handleWatch(args.sublist(1));
        exit(0);

      default:
        break;
    }
  }

  await legacy_codegen.main(args);
}

Future<void> _handleInit(List<String> args) async {
  String? configPath;
  String? contractName;
  String? abiPath;
  String? outputPath;

  for (var i = 0; i < args.length; i++) {
    if ((args[i] == '--config' || args[i] == '-c') && i + 1 < args.length) {
      configPath = args[i + 1];
      i++;
    } else if (args[i] == '--name' && i + 1 < args.length) {
      contractName = args[i + 1];
      i++;
    } else if (args[i] == '--abi' && i + 1 < args.length) {
      abiPath = args[i + 1];
      i++;
    } else if (args[i] == '--output-dir' && i + 1 < args.length) {
      outputPath = args[i + 1];
      i++;
    }
  }

  final command = InitCommand();
  await command.execute(
    configPath: configPath,
    contractName: contractName,
    abiPath: abiPath,
    outputPath: outputPath,
  );
}

Future<void> _handleValidate(List<String> args) async {
  String? configPath;
  String? abiPath;
  String? contractName;
  var failOnWarnings = false;
  var verbose = false;
  var json = false;

  for (var i = 0; i < args.length; i++) {
    if ((args[i] == '--config' || args[i] == '-c') && i + 1 < args.length) {
      configPath = args[i + 1];
      i++;
    } else if (args[i] == '--abi' && i + 1 < args.length) {
      abiPath = args[i + 1];
      i++;
    } else if (args[i] == '--name' && i + 1 < args.length) {
      contractName = args[i + 1];
      i++;
    } else if (args[i] == '--fail-on-warnings') {
      failOnWarnings = true;
    } else if (args[i] == '--verbose' || args[i] == '-v') {
      verbose = true;
    } else if (args[i] == '--json') {
      json = true;
    }
  }

  final command = ValidateCommand();
  await command.execute(
    configPath: configPath,
    abiPath: abiPath,
    contractName: contractName,
    failOnWarnings: failOnWarnings,
    verbose: verbose,
    json: json,
  );
}

Future<void> _handleGenerate(List<String> args) async {
  String? configPath;
  var useLogger = false;
  var useAutoGas = false;
  var useTransfers = false;
  var useFull = false;

  for (var i = 0; i < args.length; i++) {
    if ((args[i] == '--config' || args[i] == '-c') && i + 1 < args.length) {
      configPath = args[i + 1];
      i++;
    } else if (args[i] == '--logger') {
      useLogger = true;
    } else if (args[i] == '--autogas') {
      useAutoGas = true;
    } else if (args[i] == '--transfers') {
      useTransfers = true;
    } else if (args[i] == '--full') {
      useFull = true;
    }
  }

  final positionalArgs = args.where((a) => !a.startsWith('-')).toList();

  if (positionalArgs.length >= 3) {
    final command = GenerateCommand();
    await command.execute(
      abiPath: positionalArgs[0],
      outputDir: positionalArgs[1],
      contractName: positionalArgs[2],
      useLogger: useLogger,
      useAutoGas: useAutoGas,
      useTransfers: useTransfers,
      useFull: useFull,
    );
    return;
  }

  final command = GenerateCommand();
  await command.execute(configPath: configPath);
}

Future<void> _handleWatch(List<String> args) async {
  String? configPath;
  var skipInitialGen = false;

  for (var i = 0; i < args.length; i++) {
    if ((args[i] == '--config' || args[i] == '-c') && i + 1 < args.length) {
      configPath = args[i + 1];
      i++;
    } else if (args[i] == '--skip-initial') {
      skipInitialGen = true;
    }
  }

  final command = WatchCommand();
  await command.execute(configPath: configPath, skipInitialGen: skipInitialGen);
}
