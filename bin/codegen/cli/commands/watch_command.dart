import 'dart:io';

import '../../codegen.dart';
import '../../models/generation_config.dart';
import '../config/config.dart';
import '../config/config_loader.dart';
import '../validation/abi_validator.dart';
import '../watcher/abi_watcher.dart';

class WatchCommand {
  AbiWatcher? _watcher;
  bool _isRunning = false;

  Future<void> execute({
    String? configPath,
    bool skipInitialGen = false,
  }) async {
    try {
      print('📖 Loading configuration...');
      final config = await ConfigLoader.load(configPath: configPath);
      final resolvedPath = configPath ?? await _findConfigFile();
      final resolvedConfig = ConfigLoader.resolveRelativePaths(
        config,
        resolvedPath,
      );

      if (resolvedConfig.contracts.isEmpty) {
        print('❌ No contracts configured');
        exit(1);
      }

      final watchConfig = resolvedConfig.watch ?? const WatchConfig();

      print(
        '👁️  Watch mode enabled for ${resolvedConfig.contracts.length} contract(s)',
      );
      print('');

      if (!skipInitialGen) {
        print('🔨 Initial generation...');
        for (final contract in resolvedConfig.contracts) {
          await _generateContract(resolvedConfig, contract);
        }
        print('');
      }

      print(
        '👁️  Watching ${resolvedConfig.contracts.length} contract(s) for changes...',
      );
      print('   Press Ctrl+C to stop');
      print('');

      _isRunning = true;

      _watcher = AbiWatcher(
        contracts: resolvedConfig.contracts,
        config: watchConfig,
        onFileChanged: (contractName, abiPath) async {
          if (!_isRunning) return;

          final contract = resolvedConfig.contracts.firstWhere(
            (c) => c.name == contractName,
          );

          if (watchConfig.clearConsole) {
            _clearConsole();
          }

          final timestamp = _getTimestamp();
          print('$timestamp | 📄 Change detected: $contractName');

          await _generateContract(resolvedConfig, contract);
        },
        onError: (error) {
          print('❌ Watch error: $error');
        },
      );

      await _watcher!.start();

      await _waitForInterrupt();
    } on ConfigException catch (e) {
      print('❌ Config error: ${e.message}');
      exit(1);
    } catch (e, stackTrace) {
      print('❌ Error: $e');
      if (e.toString().contains('address already in use')) {
        print('');
        print('Suggestion: Another watch process might be running');
      }
      print('');
      print('Stack trace:');
      print(stackTrace);
      exit(1);
    } finally {
      await _cleanup();
    }
  }

  Future<void> _generateContract(
    AbidockConfig config,
    ContractConfig contract,
  ) async {
    final settings = config.defaults.merge(contract.overrides);
    final timestamp = _getTimestamp();

    if (settings.validateBeforeGen) {
      print('$timestamp | 🔍 Validating...');

      final validator = AbiValidator();
      final report = await validator.validate(
        contractName: contract.name,
        abiPath: contract.abi,
      );

      if (report.failed) {
        print('$timestamp | ❌ Validation failed');
        for (final error in report.errors) {
          print('   ${error.message}');
          if (error.location != null) {
            print('   Location: ${error.location}');
          }
        }
        return;
      }

      if (report.warnings.isNotEmpty && config.watch?.verbose == true) {
        print('$timestamp | ⚠️  ${report.warnings.length} warning(s)');
      } else if (report.warnings.isEmpty) {
        print('$timestamp | ✅ Validation passed');
      }
    }

    print('$timestamp | 🔨 Generating: ${contract.name}');

    final startTime = DateTime.now();

    try {
      final genConfig = GenerationConfig(
        abiPath: contract.abi,
        outputDir: contract.output,
        contractName: contract.name,
        useLogger: settings.generateFull,
        useTransfers: settings.generateFull,
        useAutoGas: settings.generateFull,
      );

      final codegen = Codegen(genConfig);
      await codegen.generate();

      final duration = DateTime.now().difference(startTime);
      print(
        '$timestamp | ✅ Generated successfully (${duration.inMilliseconds}ms)',
      );
    } catch (e) {
      print('$timestamp | ❌ Generation failed: $e');
      if (config.watch?.verbose == true) {
        print(e);
      }
    }
  }

  Future<String> _findConfigFile() async {
    for (final filename in ConfigLoader.defaultConfigFiles) {
      if (await File(filename).exists()) {
        return filename;
      }
    }
    throw const ConfigException('Config file not found');
  }

  String _getTimestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  void _clearConsole() {
    if (Platform.isWindows) {
      print('\n' * 50);
    } else {
      print('\x1B[2J\x1B[0;0H');
    }
  }

  Future<void> _waitForInterrupt() async {
    final completer = ProcessSignal.sigint.watch().first;
    await completer;
    print('');
    print('🛑 Stopping watch mode...');
  }

  Future<void> _cleanup() async {
    _isRunning = false;
    if (_watcher != null) {
      await _watcher!.stop();
      _watcher = null;
    }
  }
}
