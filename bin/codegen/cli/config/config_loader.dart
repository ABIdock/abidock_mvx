import 'dart:io';
import 'package:yaml/yaml.dart';
import 'config.dart';

class ConfigLoader {
  static const defaultConfigFiles = [
    'abidock.yaml',
    'abidock.yml',
    '.abidock.yaml',
  ];

  static Future<AbidockConfig> load({String? configPath}) async {
    final file = await _resolveConfigFile(configPath);
    final content = await file.readAsString();
    final substituted = _substituteEnvVars(content);

    try {
      final yaml = loadYaml(substituted) as Map;
      final json = _yamlToJson(yaml);
      return AbidockConfig.fromJson(json);
    } on YamlException catch (e) {
      throw ConfigException('Invalid YAML format: ${e.message}');
    } catch (e) {
      throw ConfigException('Failed to parse config: $e');
    }
  }

  static AbidockConfig resolveRelativePaths(
    AbidockConfig config,
    String configPath,
  ) {
    final configDir = File(configPath).parent.absolute.path;

    final resolvedContracts = config.contracts.map((contract) {
      return ContractConfig(
        name: contract.name,
        abi: _resolvePath(contract.abi, configDir),
        output: _resolvePath(contract.output, configDir),
        overrides: contract.overrides,
        metadata: contract.metadata,
      );
    }).toList();

    return AbidockConfig(
      version: config.version,
      defaults: config.defaults,
      contracts: resolvedContracts,
      watch: config.watch,
      validation: config.validation,
    );
  }

  static Future<File> _resolveConfigFile(String? configPath) async {
    if (configPath != null) {
      final file = File(configPath);
      if (!await file.exists()) {
        throw ConfigException('Config file not found: $configPath');
      }
      return file;
    }
    for (final filename in defaultConfigFiles) {
      final file = File(filename);
      if (await file.exists()) {
        return file;
      }
    }

    throw ConfigException(
      'Config file not found. Searched for: ${defaultConfigFiles.join(", ")}\n'
      'Create one with: abidock init',
    );
  }

  static String _substituteEnvVars(String content) {
    final envPattern = RegExp(r'\$\{([A-Z_][A-Z0-9_]*)\}');

    final lines = content.split('\n');
    final processedLines = lines.map((line) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('#')) {
        return line;
      }
      final commentIndex = line.indexOf('#');
      if (commentIndex == -1) {
        return line.replaceAllMapped(envPattern, (match) {
          final varName = match.group(1)!;
          final value = Platform.environment[varName];
          if (value == null) {
            throw ConfigException(
              'Environment variable not found: $varName\n'
              'Set it with: export $varName=value',
            );
          }
          return value;
        });
      } else {
        final codePart = line.substring(0, commentIndex);
        final commentPart = line.substring(commentIndex);
        final substitutedCode = codePart.replaceAllMapped(envPattern, (match) {
          final varName = match.group(1)!;
          final value = Platform.environment[varName];
          if (value == null) {
            throw ConfigException(
              'Environment variable not found: $varName\n'
              'Set it with: export $varName=value',
            );
          }
          return value;
        });
        return substitutedCode + commentPart;
      }
    });

    return processedLines.join('\n');
  }

  static String _resolvePath(String path, String configDir) {
    if (path.startsWith('/') ||
        path.startsWith(r'C:\') ||
        path.startsWith(r'\\') ||
        path.startsWith(r'${')) {
      return path;
    }

    return '$configDir${Platform.pathSeparator}$path';
  }

  static Map<String, dynamic> _yamlToJson(Map yaml) {
    final result = <String, dynamic>{};

    for (final entry in yaml.entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (value is Map) {
        result[key] = _yamlToJson(value);
      } else if (value is List) {
        result[key] = value.map((e) {
          if (e is Map) return _yamlToJson(e);
          return e;
        }).toList();
      } else {
        result[key] = value;
      }
    }

    return result;
  }

  static Future<void> createDefault({
    required String path,
    String? contractName,
    String? abiPath,
    String? outputPath,
  }) async {
    final file = File(path);
    if (await file.exists()) {
      throw ConfigException('Config file already exists: $path');
    }

    final defaultConfig = _generateDefaultConfig(
      contractName: contractName ?? 'MyContract',
      abiPath: abiPath ?? 'assets/contract.abi.json',
      outputPath: outputPath ?? 'lib/contracts/my_contract',
    );

    await file.writeAsString(defaultConfig);
  }

  static String _generateDefaultConfig({
    required String contractName,
    required String abiPath,
    required String outputPath,
  }) {
    return '''
# ═══════════════════════════════════════════════════════════════════════════════
# ABIdock Configuration File
# ═══════════════════════════════════════════════════════════════════════════════
#
# CLI Usage:
#   abidock generate              # Generate code for all contracts below
#   abidock generate --config <path>  # Use custom config file
#   abidock validate              # Validate ABIs before generation
#   abidock watch                 # Watch for ABI changes & auto-regenerate
#
# Installation (if not installed globally):
#   dart pub global activate abidock_mvx
#
# Or run via project dependency:
#   dart run abidock_mvx:abidock generate
#
# Documentation: https://github.com/ABIdock/abidock_mvx
# ═══════════════════════════════════════════════════════════════════════════════

version: 1

# Default settings applied to all contracts
defaults:
  generateFull: true        # Generate queries, calls, events, and transfers
  validateBeforeGen: true   # Validate ABI before code generation

# Contracts to process
contracts:
  - name: $contractName
    abi: $abiPath
    output: $outputPath
    # Optional: override defaults for this contract
    # overrides:
    #   generateFull: false

# Watch mode configuration (optional)
# watch:
#   debounceMs: 500        # Wait time before regenerating (ms)
#   clearConsole: true     # Clear console on each regeneration
#   verbose: false         # Show detailed output

# Validation configuration (optional)
# validation:
#   level: standard        # minimal, standard, or strict
#   failOnWarnings: false  # Treat warnings as errors
#   disabledRules: []      # Disable specific validation rules

# Environment variables can be used with \${VAR_NAME} syntax
# Example:
#   abi: \${PROJECT_ROOT}/assets/contract.abi.json
''';
  }
}
