enum ValidationSeverity { error, warning, info }

class ValidationIssue {
  final ValidationSeverity severity;
  final String rule;
  final String message;
  final String? location;
  final String? suggestion;
  final Map<String, dynamic>? context;

  const ValidationIssue({
    required this.severity,
    required this.rule,
    required this.message,
    this.location,
    this.suggestion,
    this.context,
  });

  factory ValidationIssue.error({
    required String rule,
    required String message,
    String? location,
    String? suggestion,
    Map<String, dynamic>? context,
  }) => ValidationIssue(
    severity: ValidationSeverity.error,
    rule: rule,
    message: message,
    location: location,
    suggestion: suggestion,
    context: context,
  );

  factory ValidationIssue.warning({
    required String rule,
    required String message,
    String? location,
    String? suggestion,
    Map<String, dynamic>? context,
  }) => ValidationIssue(
    severity: ValidationSeverity.warning,
    rule: rule,
    message: message,
    location: location,
    suggestion: suggestion,
    context: context,
  );

  factory ValidationIssue.info({
    required String rule,
    required String message,
    String? location,
    String? suggestion,
    Map<String, dynamic>? context,
  }) => ValidationIssue(
    severity: ValidationSeverity.info,
    rule: rule,
    message: message,
    location: location,
    suggestion: suggestion,
    context: context,
  );

  @override
  String toString() {
    final buffer = StringBuffer();

    final icon = switch (severity) {
      ValidationSeverity.error => '❌ ERROR',
      ValidationSeverity.warning => '⚠️  WARNING',
      ValidationSeverity.info => 'ℹ️  INFO',
    };

    buffer.write('$icon [$rule]: $message');
    if (location != null) {
      buffer.write('\n   Location: $location');
    }
    if (suggestion != null) {
      buffer.write('\n   Suggestion: $suggestion');
    }
    return buffer.toString();
  }
}

class ValidationReport {
  final String contractName;
  final String abiPath;
  final List<ValidationIssue> issues;
  final DateTime timestamp;
  final int durationMs;

  const ValidationReport({
    required this.contractName,
    required this.abiPath,
    required this.issues,
    required this.timestamp,
    required this.durationMs,
  });

  bool get passed => errors.isEmpty;
  bool get failed => !passed;

  List<ValidationIssue> get errors =>
      issues.where((i) => i.severity == ValidationSeverity.error).toList();

  List<ValidationIssue> get warnings =>
      issues.where((i) => i.severity == ValidationSeverity.warning).toList();

  List<ValidationIssue> get infos =>
      issues.where((i) => i.severity == ValidationSeverity.info).toList();

  String format({bool verbose = false}) {
    final buffer = StringBuffer();
    buffer.writeln('═' * 60);
    buffer.writeln('Validation Report: $contractName');
    buffer.writeln('ABI: $abiPath');
    buffer.writeln('Duration: ${durationMs}ms');
    buffer.writeln('═' * 60);
    buffer.writeln();

    if (issues.isEmpty) {
      buffer.writeln('✅ No issues found - ABI is valid!');
      return buffer.toString();
    }

    buffer.writeln('Summary:');
    buffer.writeln('  ${errors.length} error(s)');
    buffer.writeln('  ${warnings.length} warning(s)');
    buffer.writeln('  ${infos.length} info message(s)');
    buffer.writeln();

    if (errors.isNotEmpty) {
      buffer.writeln('Errors:');
      for (final issue in errors) {
        buffer.writeln(issue);
        buffer.writeln();
      }
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('Warnings:');
      for (final issue in warnings) {
        buffer.writeln(issue);
        buffer.writeln();
      }
    }

    if (verbose && infos.isNotEmpty) {
      buffer.writeln('Info:');
      for (final issue in infos) {
        buffer.writeln(issue);
        buffer.writeln();
      }
    }

    buffer.writeln('═' * 60);
    if (failed) {
      buffer.writeln('❌ Validation FAILED - Fix errors before generating code');
    } else {
      buffer.writeln('✅ Validation PASSED - Ready to generate code');
    }

    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
    'contractName': contractName,
    'abiPath': abiPath,
    'timestamp': timestamp.toIso8601String(),
    'durationMs': durationMs,
    'summary': {
      'passed': passed,
      'errors': errors.length,
      'warnings': warnings.length,
      'infos': infos.length,
    },
    'issues': issues
        .map(
          (i) => {
            'severity': i.severity.name,
            'rule': i.rule,
            'message': i.message,
            if (i.location != null) 'location': i.location,
            if (i.suggestion != null) 'suggestion': i.suggestion,
            if (i.context != null) 'context': i.context,
          },
        )
        .toList(),
  };
}
