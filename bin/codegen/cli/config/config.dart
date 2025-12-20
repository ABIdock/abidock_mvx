class AbidockConfig {
  final int version;
  final ConfigDefaults defaults;
  final List<ContractConfig> contracts;
  final WatchConfig? watch;
  final ValidationConfig? validation;

  const AbidockConfig({
    required this.version,
    required this.defaults,
    required this.contracts,
    this.watch,
    this.validation,
  });
  factory AbidockConfig.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    if (version != 1) {
      throw ConfigException(
        'Unsupported config version: $version (only version 1 is supported)',
      );
    }

    final defaultsJson = json['defaults'] as Map<String, dynamic>? ?? {};
    final contractsJson = json['contracts'] as List? ?? [];
    final watchJson = json['watch'] as Map<String, dynamic>?;
    final validationJson = json['validation'] as Map<String, dynamic>?;

    return AbidockConfig(
      version: version,
      defaults: ConfigDefaults.fromJson(defaultsJson),
      contracts: contractsJson
          .map((e) => ContractConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      watch: watchJson != null ? WatchConfig.fromJson(watchJson) : null,
      validation: validationJson != null
          ? ValidationConfig.fromJson(validationJson)
          : null,
    );
  }
  Map<String, dynamic> toJson() => {
    'version': version,
    'defaults': defaults.toJson(),
    'contracts': contracts.map((e) => e.toJson()).toList(),
    if (watch != null) 'watch': watch!.toJson(),
    if (validation != null) 'validation': validation!.toJson(),
  };
}

class ConfigDefaults {
  final bool generateFull;
  final bool validateBeforeGen;

  const ConfigDefaults({
    this.generateFull = true,
    this.validateBeforeGen = true,
  });

  factory ConfigDefaults.fromJson(Map<String, dynamic> json) => ConfigDefaults(
    generateFull: json['generateFull'] as bool? ?? true,
    validateBeforeGen: json['validateBeforeGen'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'generateFull': generateFull,
    'validateBeforeGen': validateBeforeGen,
  };

  ConfigDefaults merge(ConfigOverrides? overrides) {
    if (overrides == null) return this;
    return ConfigDefaults(
      generateFull: overrides.generateFull ?? generateFull,
      validateBeforeGen: overrides.validateBeforeGen ?? validateBeforeGen,
    );
  }
}

class ConfigOverrides {
  final bool? generateFull;
  final bool? validateBeforeGen;

  const ConfigOverrides({this.generateFull, this.validateBeforeGen});

  factory ConfigOverrides.fromJson(Map<String, dynamic> json) =>
      ConfigOverrides(
        generateFull: json['generateFull'] as bool?,
        validateBeforeGen: json['validateBeforeGen'] as bool?,
      );

  Map<String, dynamic> toJson() => {
    if (generateFull != null) 'generateFull': generateFull,
    if (validateBeforeGen != null) 'validateBeforeGen': validateBeforeGen,
  };
}

class ContractConfig {
  final String name;
  final String abi;
  final String output;
  final ConfigOverrides? overrides;
  final Map<String, dynamic>? metadata;

  const ContractConfig({
    required this.name,
    required this.abi,
    required this.output,
    this.overrides,
    this.metadata,
  });

  factory ContractConfig.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    final abi = json['abi'] as String?;
    final output = json['output'] as String?;

    if (name == null || name.isEmpty) {
      throw const ConfigException('Contract name is required');
    }
    if (abi == null || abi.isEmpty) {
      throw const ConfigException('Contract ABI path is required');
    }
    if (output == null || output.isEmpty) {
      throw const ConfigException('Contract output path is required');
    }

    final overridesJson = json['overrides'] as Map<String, dynamic>?;
    final metadata = json['metadata'] as Map<String, dynamic>?;

    return ContractConfig(
      name: name,
      abi: abi,
      output: output,
      overrides: overridesJson != null
          ? ConfigOverrides.fromJson(overridesJson)
          : null,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'abi': abi,
    'output': output,
    if (overrides != null) 'overrides': overrides!.toJson(),
    if (metadata != null) 'metadata': metadata,
  };
}

class WatchConfig {
  final int debounceMs;
  final bool clearConsole;
  final bool verbose;
  final List<String>? includePatterns;
  final List<String>? excludePatterns;

  const WatchConfig({
    this.debounceMs = 500,
    this.clearConsole = true,
    this.verbose = false,
    this.includePatterns,
    this.excludePatterns,
  });

  factory WatchConfig.fromJson(Map<String, dynamic> json) => WatchConfig(
    debounceMs: json['debounceMs'] as int? ?? 500,
    clearConsole: json['clearConsole'] as bool? ?? true,
    verbose: json['verbose'] as bool? ?? false,
    includePatterns: (json['includePatterns'] as List?)?.cast<String>(),
    excludePatterns: (json['excludePatterns'] as List?)?.cast<String>(),
  );

  Map<String, dynamic> toJson() => {
    'debounceMs': debounceMs,
    'clearConsole': clearConsole,
    'verbose': verbose,
    if (includePatterns != null) 'includePatterns': includePatterns,
    if (excludePatterns != null) 'excludePatterns': excludePatterns,
  };
}

class ValidationConfig {
  final ValidationLevel level;
  final bool failOnWarnings;
  final List<String>? disabledRules;
  final Map<String, dynamic>? customRules;

  const ValidationConfig({
    this.level = ValidationLevel.standard,
    this.failOnWarnings = false,
    this.disabledRules,
    this.customRules,
  });

  factory ValidationConfig.fromJson(Map<String, dynamic> json) {
    final levelStr = json['level'] as String? ?? 'standard';
    final level = ValidationLevel.values.firstWhere(
      (e) => e.name == levelStr,
      orElse: () => ValidationLevel.standard,
    );

    return ValidationConfig(
      level: level,
      failOnWarnings: json['failOnWarnings'] as bool? ?? false,
      disabledRules: (json['disabledRules'] as List?)?.cast<String>(),
      customRules: json['customRules'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'level': level.name,
    'failOnWarnings': failOnWarnings,
    if (disabledRules != null) 'disabledRules': disabledRules,
    if (customRules != null) 'customRules': customRules,
  };
}

enum ValidationLevel { minimal, standard, strict }

class ConfigException implements Exception {
  final String message;
  const ConfigException(this.message);

  @override
  String toString() => 'ConfigException: $message';
}
