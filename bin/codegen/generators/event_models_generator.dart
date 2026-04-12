import 'package:abidock_mvx/src/abi/abi.dart';
import '../core/import_manager.dart';
import '../core/name_sanitizer.dart';
import '../core/type_mapper.dart';
import '../models/file_output.dart';
import 'generator_base.dart';

final class EventModelsGenerator extends GeneratorBase {
  EventModelsGenerator({
    required this.abi,
    required this.typeMapper,
    required this.nameSanitizer,
  });

  final SmartContractAbi abi;
  final TypeMapper typeMapper;
  final NameSanitizer nameSanitizer;

  @override
  List<FileOutput> generate() {
    final files = <FileOutput>[];

    for (final event in abi.events) {
      final eventClassName = _normalizeEventClassName(event.identifier);

      final hasConflict = abi.types.keys.any(
        (typeName) => nameSanitizer.toPascalCase(typeName) == eventClassName,
      );

      if (hasConflict) {
        continue;
      }

      if (event.inputs.isEmpty) {
        files.add(_generateMarkerEvent(event));
      } else {
        files.add(_generateFlatEventModel(event));
      }
    }

    return files;
  }

  FileOutput _generateMarkerEvent(EventDefinition event) {
    final className = _normalizeEventClassName(event.identifier);
    final fileName = _normalizeEventFileName(event.identifier);

    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());
    buffer.writeln("import 'package:abidock_mvx/abidock_mvx.dart';");
    buffer.writeln();

    buffer.writeln('/// Event data for ${event.identifier}.');
    buffer.writeln('final class $className {');
    buffer.writeln('  const $className();');
    buffer.writeln();

    buffer.writeln('  /// Creates an instance from ABI data.');
    buffer.writeln('  static $className fromAbi(TypedValue value) {');
    buffer.writeln('    return const $className();');
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  Map<String, dynamic> toJson() => {};');
    buffer.writeln();

    buffer.writeln('  @override');
    buffer.writeln("  String toString() => '$className()';");
    buffer.writeln();

    buffer.writeln('  @override');
    buffer.writeln('  bool operator ==(Object other) => other is $className;');
    buffer.writeln();

    buffer.writeln('  @override');
    buffer.writeln('  int get hashCode => runtimeType.hashCode;');
    buffer.writeln();

    buffer.writeln('  /// ABI type definition.');
    buffer.writeln(
      '  static final type = StructType(name: \'$className\', fieldDefinitions: []);',
    );

    buffer.writeln('}');

    return FileOutput(
      path: 'models/$fileName.dart',
      content: buffer.toString(),
    );
  }

  FileOutput _generateFlatEventModel(EventDefinition event) {
    final className = _normalizeEventClassName(event.identifier);
    final fileName = _normalizeEventFileName(event.identifier);

    final importManager = ImportManager();
    importManager.addPackageImport('package:abidock_mvx/abidock_mvx.dart');

    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());

    final fields = <_FieldInfo>[];
    for (final input in event.inputs) {
      var fieldName = nameSanitizer.toCamelCase(input.name);
      if (_isReservedKeyword(fieldName)) {
        fieldName = '${fieldName}Value';
      }

      final dartType = typeMapper.mapToDartType(input.type);

      if (dartType.contains('Uint8List')) {
        importManager.addDartImport('dart:typed_data');
      }

      _addCustomTypeImports(input.type, importManager, className);

      fields.add(
        _FieldInfo(
          name: fieldName,
          abiName: input.name,
          dartType: dartType,
          abiType: input.type,
          isIndexed: input.indexed,
        ),
      );
    }

    buffer.write(importManager.generate());
    if (importManager.generate().isNotEmpty) {
      buffer.writeln();
    }

    buffer.writeln('/// Event model for ${event.identifier}.');
    buffer.writeln('final class $className {');

    if (fields.isEmpty) {
      buffer.writeln('  const $className();');
    } else {
      buffer.writeln('  const $className({');
      for (final field in fields) {
        buffer.writeln('    required this.${field.name},');
      }
      buffer.writeln('  });');
      buffer.writeln();

      for (final field in fields) {
        buffer.writeln('  final ${field.dartType} ${field.name};');
      }
    }
    buffer.writeln();

    buffer.writeln('  /// ABI type definition.');
    buffer.write('  static final type = StructType(');
    buffer.write("name: '$className', ");
    buffer.write('fieldDefinitions: [');
    for (int i = 0; i < fields.length; i++) {
      final field = fields[i];
      final abiTypeExpr = typeMapper.mapToTypeExpression(field.abiType);
      buffer.write(
        "FieldDefinition(name: '${field.abiName}', type: $abiTypeExpr)",
      );
      if (i < fields.length - 1) {
        buffer.write(', ');
      }
    }
    buffer.writeln(']);');
    buffer.writeln();

    buffer.writeln('  /// Creates an instance from ABI data.');
    buffer.writeln('  factory $className.fromAbi(TypedValue value) {');
    if (fields.isEmpty) {
      buffer.writeln('    return const $className();');
    } else {
      buffer.writeln('    final struct = value as StructValue;');
      buffer.writeln('    return $className(');
      for (final field in fields) {
        final isCustomStruct = abi.types.containsKey(field.abiType.name);
        final isEnum = field.abiType is EnumType;
        final isListOfCustomStruct = _isListOfCustomStruct(field.abiType, abi);

        final isExplicitEnum = field.abiType is ExplicitEnumType;

        if (isListOfCustomStruct) {
          final elementTypeName = _getListElementTypeName(field.dartType);
          buffer.writeln('      ${field.name}: () {');
          buffer.writeln(
            '        final listValue = struct.getFieldValue(\'${field.abiName}\') as ListValue;',
          );
          buffer.writeln(
            '        return listValue.elements.map((item) => $elementTypeName.fromAbi(item)).toList();',
          );
          buffer.writeln('      }(),');
        } else if (isEnum || isExplicitEnum) {
          buffer.writeln('      ${field.name}: () {');
          buffer.writeln(
            '        final fieldValue = struct.getFieldValue(\'${field.abiName}\');',
          );
          buffer.writeln(
            '        return ${field.dartType}.fromAbi(fieldValue);',
          );
          buffer.writeln('      }(),');
        } else if (isCustomStruct) {
          buffer.writeln('      ${field.name}: () {');
          buffer.writeln(
            '        final fieldValue = struct.getFieldValue(\'${field.abiName}\').nativeValue;',
          );
          buffer.writeln('        if (fieldValue is Map<String, dynamic>) {');
          buffer.writeln(
            '          return ${field.dartType}.fromAbi(${field.dartType}.type.createValue(fieldValue));',
          );
          buffer.writeln('        }');
          buffer.writeln(
            '        return infer<${field.dartType}>(fieldValue);',
          );
          buffer.writeln('      }(),');
        } else {
          buffer.writeln(
            '      ${field.name}: infer<${field.dartType}>(struct.getFieldValue(\'${field.abiName}\').nativeValue),',
          );
        }
      }
      buffer.writeln('    );');
    }
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  /// Converts to JSON map.');
    buffer.writeln('  Map<String, dynamic> toJson() {');
    if (fields.isEmpty) {
      buffer.writeln('    return {};');
    } else {
      buffer.writeln('    return {');
      for (final field in fields) {
        final value = _getJsonValue(field);
        buffer.writeln("      '${field.abiName}': $value,");
      }
      buffer.writeln('    };');
    }
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  @override');
    if (fields.isEmpty) {
      buffer.writeln("  String toString() => '$className()';");
    } else {
      buffer.write("  String toString() => '$className(");
      final fieldStrs = fields
          .take(3)
          .map((f) => '${f.name}: \$${f.name}')
          .join(', ');
      if (fields.length > 3) {
        buffer.write('$fieldStrs, ...');
      } else {
        buffer.write(fieldStrs);
      }
      buffer.writeln(")';");
    }
    buffer.writeln();

    buffer.writeln('  @override');
    buffer.writeln('  bool operator ==(Object other) {');
    buffer.writeln('    if (identical(this, other)) return true;');
    if (fields.isEmpty) {
      buffer.writeln('    return other is $className;');
    } else {
      buffer.writeln('    return other is $className &&');
      for (int i = 0; i < fields.length; i++) {
        final field = fields[i];
        final isLast = i == fields.length - 1;
        buffer.write('        other.${field.name} == ${field.name}');
        buffer.writeln(isLast ? ';' : ' &&');
      }
    }
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  @override');
    if (fields.isEmpty) {
      buffer.writeln('  int get hashCode => runtimeType.hashCode;');
    } else if (fields.length == 1) {
      buffer.writeln('  int get hashCode => ${fields.first.name}.hashCode;');
    } else {
      buffer.writeln('  int get hashCode {');
      buffer.write('    return Object.hash(');
      final hashFields = fields.take(20).map((f) => f.name).join(', ');
      buffer.write(hashFields);
      buffer.writeln(');');
      buffer.writeln('  }');
    }

    buffer.writeln('}');

    return FileOutput(
      path: 'models/$fileName.dart',
      content: buffer.toString(),
    );
  }

  void _addCustomTypeImports(
    AbiType type,
    ImportManager importManager,
    String eventClassName,
  ) {
    final typeName = type.name;
    if (abi.types.containsKey(typeName)) {
      if (nameSanitizer.toPascalCase(typeName) != eventClassName) {
        final fileName = nameSanitizer.toSnakeCase(typeName);
        importManager.addRelativeImport('$fileName.dart');
      }
    }

    if (type.isGeneric && type.typeParameters.isNotEmpty) {
      for (final typeParam in type.typeParameters) {
        _addCustomTypeImports(typeParam, importManager, eventClassName);
      }
    }
  }

  bool _isReservedKeyword(String name) {
    const keywords = {
      'new',
      'default',
      'class',
      'if',
      'else',
      'for',
      'while',
      'do',
      'switch',
      'case',
      'break',
      'continue',
      'return',
      'try',
      'catch',
      'finally',
      'throw',
      'import',
      'export',
      'library',
      'part',
      'of',
      'const',
      'final',
      'var',
      'void',
      'dynamic',
      'abstract',
      'static',
      'extends',
      'implements',
      'with',
      'mixin',
      'enum',
      'typedef',
      'this',
      'super',
      'true',
      'false',
      'null',
      'as',
      'is',
      'in',
      'async',
      'await',
      'yield',
      'sync',
      'assert',
      'deferred',
      'covariant',
      'required',
      'late',
    };
    return keywords.contains(name);
  }

  String _getJsonValue(_FieldInfo field) {
    final dartType = field.dartType;
    final fieldName = field.name;

    if (dartType == 'Address') {
      return '$fieldName.bech32';
    } else if (dartType == 'TokenIdentifier' ||
        dartType == 'EgldOrEsdtTokenIdentifier') {
      return '$fieldName.value';
    } else if (dartType == 'BigInt') {
      return '$fieldName.toString()';
    } else if (dartType == 'bool' ||
        dartType == 'int' ||
        dartType == 'String') {
      return fieldName;
    } else if (dartType.startsWith('List<')) {
      return '$fieldName.map((e) => e.toString()).toList()';
    } else {
      return '$fieldName.toString()';
    }
  }

  String _normalizeEventClassName(String identifier) {
    String normalized = identifier;
    if (normalized.endsWith('_event')) {
      normalized = normalized.substring(0, normalized.length - 6);
    }
    return '${nameSanitizer.toPascalCase(normalized)}Event';
  }

  String _normalizeEventFileName(String identifier) {
    String normalized = identifier;
    if (normalized.endsWith('_event')) {
      normalized = normalized.substring(0, normalized.length - 6);
    }
    return '${nameSanitizer.toSnakeCase(normalized)}_event';
  }

  bool _isListOfCustomStruct(AbiType type, SmartContractAbi abi) {
    if (type is ListType) {
      return abi.types.containsKey(type.elementType.name);
    }
    if (type is ArrayType) {
      return abi.types.containsKey(type.elementType.name);
    }
    return false;
  }

  String _getListElementTypeName(String dartType) {
    if (!dartType.startsWith('List<') || !dartType.endsWith('>')) {
      return dartType;
    }
    return dartType.substring(5, dartType.length - 1);
  }
}

class _FieldInfo {
  final String name;
  final String abiName;
  final String dartType;
  final AbiType abiType;
  final bool isIndexed;

  _FieldInfo({
    required this.name,
    required this.abiName,
    required this.dartType,
    required this.abiType,
    required this.isIndexed,
  });
}
