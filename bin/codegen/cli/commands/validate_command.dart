import 'dart:convert';
import 'dart:io';

import '../config/config.dart';
import '../config/config_loader.dart';
import '../validation/abi_validator.dart';

class ValidateCommand {
  Future<void> execute({
    String? configPath,
    String? abiPath,
    String? contractName,
    bool failOnWarnings = false,
    bool verbose = false,
    bool json = false,
  }) async {
    try {
      if (abiPath != null && contractName != null) {
        await _validateSingle(
          abiPath: abiPath,
          contractName: contractName,
          failOnWarnings: failOnWarnings,
          verbose: verbose,
          json: json,
        );
      } else if (configPath != null || await _hasConfigFile()) {
        await _validateFromConfig(
          configPath: configPath,
          failOnWarnings: failOnWarnings,
          verbose: verbose,
          json: json,
        );
      } else {
        print('❌ Error: Either provide --config, or both --abi and --name');
        print('');
        print('Usage:');
        print('  abidock validate --config abidock.yaml');
        print('  abidock validate --abi assets/pair.abi.json --name Pair');
        exit(1);
      }
    } on ConfigException catch (e) {
      print('❌ Config error: ${e.message}');
      exit(1);
    } catch (e) {
      print('❌ Unexpected error: $e');
      exit(1);
    }
  }

  Future<void> _validateFromConfig({
    String? configPath,
    required bool failOnWarnings,
    required bool verbose,
    required bool json,
  }) async {
    print('📖 Loading configuration...');
    final config = await ConfigLoader.load(configPath: configPath);
    final resolvedPath = configPath ?? await _findConfigFile();
    final resolvedConfig = ConfigLoader.resolveRelativePaths(
      config,
      resolvedPath,
    );

    print('🔍 Validating ${resolvedConfig.contracts.length} contract(s)...');
    print('');

    final validator = AbiValidator(failOnWarnings: failOnWarnings);

    var hasErrors = false;
    final reports = <Map<String, dynamic>>[];

    for (final contract in resolvedConfig.contracts) {
      final report = await validator.validate(
        contractName: contract.name,
        abiPath: contract.abi,
      );

      if (json) {
        reports.add(report.toJson());
      } else {
        print(report.format(verbose: verbose));
        print('');
      }

      if (report.failed || (failOnWarnings && report.warnings.isNotEmpty)) {
        hasErrors = true;
      }
    }

    if (json) {
      print(
        jsonEncode({
          'contracts': resolvedConfig.contracts.length,
          'reports': reports,
        }),
      );
    }

    if (hasErrors) {
      exit(1);
    }
  }

  Future<void> _validateSingle({
    required String abiPath,
    required String contractName,
    required bool failOnWarnings,
    required bool verbose,
    required bool json,
  }) async {
    print('🔍 Validating $contractName...');
    print('');

    final validator = AbiValidator(failOnWarnings: failOnWarnings);

    final report = await validator.validate(
      contractName: contractName,
      abiPath: abiPath,
    );

    if (json) {
      print(jsonEncode(report.toJson()));
    } else {
      print(report.format(verbose: verbose));
    }

    if (report.failed || (failOnWarnings && report.warnings.isNotEmpty)) {
      exit(1);
    }
  }

  Future<bool> _hasConfigFile() async {
    for (final filename in ConfigLoader.defaultConfigFiles) {
      if (await File(filename).exists()) {
        return true;
      }
    }
    return false;
  }

  Future<String> _findConfigFile() async {
    for (final filename in ConfigLoader.defaultConfigFiles) {
      if (await File(filename).exists()) {
        return filename;
      }
    }
    throw const ConfigException('Config file not found');
  }
}
