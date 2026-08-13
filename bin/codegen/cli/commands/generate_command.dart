import 'dart:io';

import '../../codegen.dart';
import '../../models/generation_config.dart';
import '../config/config.dart';
import '../config/config_loader.dart';
import '../validation/abi_validator.dart';

class GenerateCommand {
  Future<void> execute({
    String? configPath,
    String? abiPath,
    String? outputDir,
    String? contractName,
    bool useLogger = false,
    bool useAutoGas = false,
    bool useTransfers = false,
    bool useFull = false,
  }) async {
    try {
      final bool hasPositionalTarget =
          abiPath != null && outputDir != null && contractName != null;

      if (configPath != null) {
        await _generateFromConfig(configPath: configPath);
      } else if (hasPositionalTarget) {
        await _generateSingle(
          abiPath: abiPath,
          outputDir: outputDir,
          contractName: contractName,
          useLogger: useFull || useLogger,
          useAutoGas: useFull || useAutoGas,
          useTransfers: useFull || useTransfers,
        );
      } else if (await _hasConfigFile()) {
        await _generateFromConfig(configPath: configPath);
      } else {
        print('❌ Error: Either provide --config, or <abi> <output> <name>');
        print('');
        print('Usage:');
        print('  abidock generate --config abidock.yaml');
        print(
          '  abidock generate <abi_file> <output_dir> <contract_name> [flags]',
        );
        exit(1);
      }
    } on ConfigException catch (e) {
      print('❌ Config error: ${e.message}');
      exit(1);
    } catch (e, stackTrace) {
      print('❌ Error: $e');
      print('');
      print('Stack trace:');
      print(stackTrace);
      exit(1);
    }
  }

  Future<void> _generateFromConfig({String? configPath}) async {
    print('📖 Loading configuration...');
    final config = await ConfigLoader.load(configPath: configPath);
    final resolvedPath = configPath ?? await _findConfigFile();
    final resolvedConfig = ConfigLoader.resolveRelativePaths(
      config,
      resolvedPath,
    );

    print('🔨 Generating ${resolvedConfig.contracts.length} contract(s)...');
    print('');

    for (final contract in resolvedConfig.contracts) {
      final settings = resolvedConfig.defaults.merge(contract.overrides);

      if (settings.validateBeforeGen) {
        print('🔍 Validating: ${contract.name}...');
        final validator = AbiValidator();
        final report = await validator.validate(
          contractName: contract.name,
          abiPath: contract.abi,
        );

        if (report.failed) {
          print(report.format());
          print('❌ Validation failed for ${contract.name}');
          print('   Fix errors or disable validation in config');
          exit(1);
        }

        if (report.warnings.isNotEmpty) {
          print('⚠️  ${report.warnings.length} warning(s) found');
        }
      }
      print('🔨 Generating: ${contract.name}...');
      final startTime = DateTime.now();

      await _generateContract(
        abiPath: contract.abi,
        outputDir: contract.output,
        contractName: contract.name,
        generateFull: settings.generateFull,
      );

      final duration = DateTime.now().difference(startTime);
      print('✅ Generated ${contract.name} (${duration.inMilliseconds}ms)');
      print('');
    }

    print('🎉 All contracts generated successfully!');
  }

  Future<void> _generateSingle({
    required String abiPath,
    required String outputDir,
    required String contractName,
    bool useLogger = false,
    bool useAutoGas = false,
    bool useTransfers = false,
  }) async {
    final config = GenerationConfig(
      abiPath: abiPath,
      outputDir: outputDir,
      contractName: contractName,
      useLogger: useLogger,
      useAutoGas: useAutoGas,
      useTransfers: useTransfers,
    );

    final codegen = Codegen(config);
    await codegen.generate();
  }

  Future<void> _generateContract({
    required String abiPath,
    required String outputDir,
    required String contractName,
    required bool generateFull,
  }) async {
    final config = GenerationConfig(
      abiPath: abiPath,
      outputDir: outputDir,
      contractName: contractName,
      useLogger: generateFull,
      useAutoGas: generateFull,
      useTransfers: generateFull,
    );

    final codegen = Codegen(config);
    await codegen.generate();
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
