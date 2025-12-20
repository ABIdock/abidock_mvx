import 'dart:convert';
import 'dart:io';
import 'validation_models.dart';

class AbiValidator {
  static const allRules = [
    'SCHEMA_VERSION',
    'MISSING_FIELD',
    'INVALID_TYPE',
    'UNKNOWN_TYPE',
    'CIRCULAR_DEPENDENCY',
    'DUPLICATE_ENDPOINT',
    'INVALID_MUTABILITY',
    'MISSING_PAYABLE',
    'GENERIC_TYPE_MISMATCH',
  ];

  final Set<String> enabledRules;
  final bool failOnWarnings;

  AbiValidator({Set<String>? enabledRules, this.failOnWarnings = false})
    : enabledRules = enabledRules ?? allRules.toSet();

  Future<ValidationReport> validate({
    required String contractName,
    required String abiPath,
  }) async {
    final startTime = DateTime.now();
    final issues = <ValidationIssue>[];

    try {
      final file = File(abiPath);
      if (!await file.exists()) {
        issues.add(
          ValidationIssue.error(
            rule: 'FILE_NOT_FOUND',
            message: 'ABI file not found',
            suggestion: 'Check that the file path is correct',
          ),
        );
        return _createReport(contractName, abiPath, issues, startTime);
      }

      final content = await file.readAsString();
      final Map<String, dynamic> abi;

      try {
        abi = jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        issues.add(
          ValidationIssue.error(
            rule: 'INVALID_JSON',
            message: 'Invalid JSON format: $e',
            suggestion: 'Validate JSON with a JSON linter',
          ),
        );
        return _createReport(contractName, abiPath, issues, startTime);
      }

      _validateSchema(abi, issues);
      _validateTypes(abi, issues);
      _validateEndpoints(abi, issues);
      _validateTypeDependencies(abi, issues);
    } catch (e) {
      issues.add(
        ValidationIssue.error(
          rule: 'VALIDATION_ERROR',
          message: 'Unexpected validation error: $e',
        ),
      );
    }

    return _createReport(contractName, abiPath, issues, startTime);
  }

  Future<List<ValidationReport>> validateBatch(
    List<({String name, String path})> contracts,
  ) async {
    final reports = <ValidationReport>[];

    for (final contract in contracts) {
      final report = await validate(
        contractName: contract.name,
        abiPath: contract.path,
      );
      reports.add(report);
    }

    return reports;
  }

  void _validateSchema(Map<String, dynamic> abi, List<ValidationIssue> issues) {
    if (!enabledRules.contains('SCHEMA_VERSION')) return;

    final buildInfoRaw = abi['buildInfo'];
    final buildInfo = buildInfoRaw is Map<String, dynamic>
        ? buildInfoRaw
        : null;

    if (buildInfo == null) {
      if (buildInfoRaw != null) {
        issues.add(
          ValidationIssue.warning(
            rule: 'INVALID_TYPE',
            message:
                'buildInfo should be an object, got ${buildInfoRaw.runtimeType}',
            location: 'root',
            suggestion:
                'buildInfo should be a JSON object, not a list or primitive',
          ),
        );
      } else {
        issues.add(
          ValidationIssue.warning(
            rule: 'MISSING_FIELD',
            message: 'Missing "buildInfo" field',
            location: 'root',
            suggestion:
                'Add buildInfo section with rustc version and framework info',
          ),
        );
      }
    } else {
      final abiVersion = buildInfo['abiVersion'] as String?;
      if (abiVersion == null) {
        issues.add(
          ValidationIssue.warning(
            rule: 'MISSING_FIELD',
            message: 'Missing "abiVersion" in buildInfo',
            location: 'buildInfo',
            suggestion: 'Add abiVersion field (e.g., "0.0.0")',
          ),
        );
      }
    }

    final name = abi['name'] as String?;
    if (name == null || name.isEmpty) {
      issues.add(
        ValidationIssue.error(
          rule: 'MISSING_FIELD',
          message: 'Missing or empty "name" field',
          location: 'root',
          suggestion: 'Add name field with contract name',
        ),
      );
    }

    final constructorRaw = abi['constructor'];
    if (constructorRaw is Map<String, dynamic>) {
      _validateEndpointStructure(constructorRaw, 'constructor', issues);
    } else if (constructorRaw != null) {
      issues.add(
        ValidationIssue.warning(
          rule: 'INVALID_TYPE',
          message:
              'constructor should be an object, got ${constructorRaw.runtimeType}',
          location: 'root',
        ),
      );
    }
  }

  void _validateTypes(Map<String, dynamic> abi, List<ValidationIssue> issues) {
    if (!enabledRules.contains('INVALID_TYPE')) return;

    final typesRaw = abi['types'];
    if (typesRaw == null) {
      return;
    }

    // Handle types as Map (standard format)
    if (typesRaw is Map<String, dynamic>) {
      _validateTypesMap(typesRaw, issues);
      return;
    }

    // Handle types as List (alternative format used by some ABIs)
    if (typesRaw is List) {
      _validateTypesList(typesRaw, issues);
      return;
    }

    // Unknown format
    issues.add(
      ValidationIssue.warning(
        rule: 'INVALID_TYPE',
        message:
            'types should be an object or array, got ${typesRaw.runtimeType}',
        location: 'types',
        suggestion:
            'types should be a JSON object or array of type definitions',
      ),
    );
  }

  void _validateTypesMap(
    Map<String, dynamic> types,
    List<ValidationIssue> issues,
  ) {
    for (final entry in types.entries) {
      final typeName = entry.key;
      final typeValue = entry.value;

      if (typeValue is! Map<String, dynamic>) {
        issues.add(
          ValidationIssue.error(
            rule: 'INVALID_TYPE',
            message: 'Type definition must be an object',
            location: 'types.$typeName',
          ),
        );
        continue;
      }

      _validateTypeDefinition(typeName, typeValue, 'types.$typeName', issues);
    }
  }

  void _validateTypesList(List types, List<ValidationIssue> issues) {
    for (var i = 0; i < types.length; i++) {
      final typeEntry = types[i];

      if (typeEntry is! Map<String, dynamic>) {
        issues.add(
          ValidationIssue.error(
            rule: 'INVALID_TYPE',
            message: 'Type definition must be an object',
            location: 'types[$i]',
          ),
        );
        continue;
      }

      final typeName = typeEntry['name'] as String? ?? 'unknown';
      _validateTypeDefinition(typeName, typeEntry, 'types[$i]', issues);
    }
  }

  void _validateTypeDefinition(
    String typeName,
    Map<String, dynamic> typeObj,
    String location,
    List<ValidationIssue> issues,
  ) {
    final typeType = typeObj['type'] as String?;

    if (typeType == null) {
      issues.add(
        ValidationIssue.error(
          rule: 'MISSING_FIELD',
          message: 'Missing "type" field in type definition',
          location: location,
          suggestion: 'Add type field (e.g., "struct", "enum")',
        ),
      );
      return;
    }

    switch (typeType) {
      case 'struct':
        _validateStructType(typeName, typeObj, issues);
        break;
      case 'enum':
        _validateEnumType(typeName, typeObj, issues);
        break;
      case 'explicit-enum':
        // explicit-enum is valid, no extra validation needed
        break;
      default:
        issues.add(
          ValidationIssue.info(
            rule: 'UNKNOWN_TYPE',
            message: 'Unknown type kind: $typeType',
            location: location,
          ),
        );
    }
  }

  void _validateStructType(
    String typeName,
    Map<String, dynamic> typeObj,
    List<ValidationIssue> issues,
  ) {
    final fields = typeObj['fields'] as List?;

    if (fields == null || fields.isEmpty) {
      issues.add(
        ValidationIssue.warning(
          rule: 'MISSING_FIELD',
          message: 'Struct has no fields',
          location: 'types.$typeName',
          suggestion: 'Add at least one field or use a different type',
        ),
      );
      return;
    }

    for (var i = 0; i < fields.length; i++) {
      final field = fields[i];

      if (field is! Map<String, dynamic>) {
        issues.add(
          ValidationIssue.error(
            rule: 'INVALID_TYPE',
            message: 'Field must be an object',
            location: 'types.$typeName.fields[$i]',
          ),
        );
        continue;
      }

      final fieldMap = field;
      final fieldName = fieldMap['name'] as String?;
      final fieldType = fieldMap['type'] as String?;

      if (fieldName == null || fieldName.isEmpty) {
        issues.add(
          ValidationIssue.error(
            rule: 'MISSING_FIELD',
            message: 'Field missing "name"',
            location: 'types.$typeName.fields[$i]',
          ),
        );
      }

      if (fieldType == null || fieldType.isEmpty) {
        issues.add(
          ValidationIssue.error(
            rule: 'MISSING_FIELD',
            message: 'Field missing "type"',
            location: 'types.$typeName.fields[$i]',
          ),
        );
      }
    }
  }

  void _validateEnumType(
    String typeName,
    Map<String, dynamic> typeObj,
    List<ValidationIssue> issues,
  ) {
    final variants = typeObj['variants'] as List?;

    if (variants == null || variants.isEmpty) {
      issues.add(
        ValidationIssue.error(
          rule: 'MISSING_FIELD',
          message: 'Enum has no variants',
          location: 'types.$typeName',
          suggestion: 'Add at least one variant',
        ),
      );
      return;
    }

    final variantNames = <String>{};

    for (var i = 0; i < variants.length; i++) {
      final variant = variants[i];

      if (variant is! Map<String, dynamic>) {
        issues.add(
          ValidationIssue.error(
            rule: 'INVALID_TYPE',
            message: 'Variant must be an object',
            location: 'types.$typeName.variants[$i]',
          ),
        );
        continue;
      }

      final variantMap = variant;
      final variantName = variantMap['name'] as String?;

      if (variantName == null || variantName.isEmpty) {
        issues.add(
          ValidationIssue.error(
            rule: 'MISSING_FIELD',
            message: 'Variant missing "name"',
            location: 'types.$typeName.variants[$i]',
          ),
        );
        continue;
      }

      if (variantNames.contains(variantName)) {
        issues.add(
          ValidationIssue.error(
            rule: 'DUPLICATE_VARIANT',
            message: 'Duplicate variant name: $variantName',
            location: 'types.$typeName.variants[$i]',
          ),
        );
      }
      variantNames.add(variantName);
    }
  }

  void _validateEndpoints(
    Map<String, dynamic> abi,
    List<ValidationIssue> issues,
  ) {
    if (!enabledRules.contains('DUPLICATE_ENDPOINT')) return;

    final endpoints = abi['endpoints'] as List?;
    if (endpoints == null || endpoints.isEmpty) {
      issues.add(
        ValidationIssue.info(
          rule: 'NO_ENDPOINTS',
          message: 'Contract has no endpoints',
          location: 'endpoints',
          suggestion:
              'This is unusual - most contracts have at least one endpoint',
        ),
      );
      return;
    }

    final endpointNames = <String>{};

    for (var i = 0; i < endpoints.length; i++) {
      final endpoint = endpoints[i];

      if (endpoint is! Map<String, dynamic>) {
        issues.add(
          ValidationIssue.error(
            rule: 'INVALID_TYPE',
            message: 'Endpoint must be an object',
            location: 'endpoints[$i]',
          ),
        );
        continue;
      }

      final endpointMap = endpoint;
      final endpointName = endpointMap['name'] as String?;

      if (endpointName == null || endpointName.isEmpty) {
        issues.add(
          ValidationIssue.error(
            rule: 'MISSING_FIELD',
            message: 'Endpoint missing "name"',
            location: 'endpoints[$i]',
          ),
        );
        continue;
      }

      if (endpointNames.contains(endpointName)) {
        issues.add(
          ValidationIssue.error(
            rule: 'DUPLICATE_ENDPOINT',
            message: 'Duplicate endpoint name: $endpointName',
            location: 'endpoints[$i]',
            suggestion: 'Each endpoint must have a unique name',
          ),
        );
      }
      endpointNames.add(endpointName);
      _validateEndpointStructure(endpointMap, 'endpoints[$i]', issues);
    }
  }

  void _validateEndpointStructure(
    Map<String, dynamic> endpoint,
    String location,
    List<ValidationIssue> issues,
  ) {
    if (enabledRules.contains('INVALID_MUTABILITY')) {
      final mutability = endpoint['mutability'] as String?;
      const validMutabilities = ['mutable', 'readonly', 'pure'];

      if (mutability != null && !validMutabilities.contains(mutability)) {
        issues.add(
          ValidationIssue.error(
            rule: 'INVALID_MUTABILITY',
            message: 'Invalid mutability: $mutability',
            location: location,
            suggestion: 'Use one of: ${validMutabilities.join(", ")}',
          ),
        );
      }
    }

    final inputs = endpoint['inputs'] as List?;
    if (inputs != null) {
      for (var i = 0; i < inputs.length; i++) {
        final input = inputs[i];
        if (input is! Map<String, dynamic>) continue;

        final inputMap = input;
        final inputType = inputMap['type'] as String?;

        if (inputType == null || inputType.isEmpty) {
          issues.add(
            ValidationIssue.error(
              rule: 'MISSING_FIELD',
              message: 'Input missing "type" field',
              location: '$location.inputs[$i]',
              suggestion: 'Add type field for input parameter',
            ),
          );
        }
      }
    }

    final outputs = endpoint['outputs'] as List?;
    if (outputs != null) {
      for (var i = 0; i < outputs.length; i++) {
        final output = outputs[i];
        if (output is! Map<String, dynamic>) continue;

        final outputMap = output;
        final outputType = outputMap['type'] as String?;

        if (outputType == null || outputType.isEmpty) {
          issues.add(
            ValidationIssue.error(
              rule: 'MISSING_FIELD',
              message: 'Output missing "type" field',
              location: '$location.outputs[$i]',
              suggestion: 'Add type field for output parameter',
            ),
          );
        }
      }
    }

    if (enabledRules.contains('MISSING_PAYABLE')) {
      final payableInTokens = endpoint['payableInTokens'] as List?;
      final mutability = endpoint['mutability'] as String?;

      if (payableInTokens != null &&
          payableInTokens.isNotEmpty &&
          mutability == 'readonly') {
        issues.add(
          ValidationIssue.warning(
            rule: 'MISSING_PAYABLE',
            message: 'Readonly endpoint marked as payable',
            location: location,
            suggestion: 'Readonly endpoints cannot receive payments',
          ),
        );
      }
    }
  }

  void _validateTypeDependencies(
    Map<String, dynamic> abi,
    List<ValidationIssue> issues,
  ) {
    if (!enabledRules.contains('CIRCULAR_DEPENDENCY')) return;

    final typesRaw = abi['types'];
    if (typesRaw == null || typesRaw is! Map<String, dynamic>) return;

    final types = typesRaw;
    final dependencies = <String, Set<String>>{};

    for (final entry in types.entries) {
      final typeName = entry.key;
      final typeValue = entry.value;

      if (typeValue is! Map<String, dynamic>) continue;

      dependencies[typeName] = _extractTypeDependencies(typeValue);
    }

    for (final typeName in dependencies.keys) {
      final visited = <String>{};
      final stack = <String>{};

      if (_hasCycle(typeName, dependencies, visited, stack)) {
        issues.add(
          ValidationIssue.error(
            rule: 'CIRCULAR_DEPENDENCY',
            message: 'Circular type dependency detected involving: $typeName',
            location: 'types.$typeName',
            suggestion:
                'Break circular dependency by using Option or MultiResultVec',
          ),
        );
      }
    }
  }

  Set<String> _extractTypeDependencies(Map<String, dynamic> typeObj) {
    final deps = <String>{};

    final fields = typeObj['fields'] as List?;
    if (fields != null) {
      for (final field in fields) {
        if (field is! Map<String, dynamic>) continue;
        final fieldType = field['type'] as String?;
        if (fieldType != null) {
          deps.add(_extractBaseType(fieldType));
        }
      }
    }

    final variants = typeObj['variants'] as List?;
    if (variants != null) {
      for (final variant in variants) {
        if (variant is! Map<String, dynamic>) continue;
        final fields = variant['fields'] as List?;
        if (fields != null) {
          for (final field in fields) {
            if (field is! Map<String, dynamic>) continue;
            final fieldType = field['type'] as String?;
            if (fieldType != null) {
              deps.add(_extractBaseType(fieldType));
            }
          }
        }
      }
    }

    return deps;
  }

  String _extractBaseType(String typeExpr) {
    final match = RegExp(r'([A-Z][a-zA-Z0-9_]*)').firstMatch(typeExpr);
    return match?.group(1) ?? typeExpr;
  }

  bool _hasCycle(
    String typeName,
    Map<String, Set<String>> dependencies,
    Set<String> visited,
    Set<String> stack,
  ) {
    visited.add(typeName);
    stack.add(typeName);

    final deps = dependencies[typeName] ?? {};
    for (final dep in deps) {
      if (!visited.contains(dep)) {
        if (_hasCycle(dep, dependencies, visited, stack)) {
          return true;
        }
      } else if (stack.contains(dep)) {
        return true;
      }
    }

    stack.remove(typeName);
    return false;
  }

  ValidationReport _createReport(
    String contractName,
    String abiPath,
    List<ValidationIssue> issues,
    DateTime startTime,
  ) {
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inMilliseconds;

    return ValidationReport(
      contractName: contractName,
      abiPath: abiPath,
      issues: issues,
      timestamp: endTime,
      durationMs: duration,
    );
  }
}
