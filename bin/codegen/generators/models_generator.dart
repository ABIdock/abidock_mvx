import 'package:abidock_mvx/src/abi/abi.dart';

import '../core/import_manager.dart';
import '../core/name_sanitizer.dart';
import '../core/type_mapper.dart';
import '../models/file_output.dart';
import '../utils/keyword_sanitizer.dart';
import 'generator_base.dart';

class ModelsGenerator extends GeneratorBase {
  final SmartContractAbi abi;
  final TypeMapper typeMapper;
  final NameSanitizer nameSanitizer;
  final KeywordSanitizer keywordSanitizer;

  ModelsGenerator({
    required this.abi,
    required this.typeMapper,
    required this.nameSanitizer,
    required this.keywordSanitizer,
  });

  @override
  List<FileOutput> generate() {
    final files = <FileOutput>[];

    final generationOrder = _getGenerationOrder();

    for (final typeName in generationOrder) {
      final type = abi.types[typeName];
      if (type == null) continue;

      if (type is StructType) {
        files.add(_generateStruct(type));
      } else if (type is EnumType) {
        files.add(_generateEnum(type));
      } else if (type is ExplicitEnumType) {
        files.add(_generateExplicitEnum(type));
      }
    }

    return files;
  }

  FileOutput _generateStruct(StructType structType) {
    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());
    final className = nameSanitizer.toPascalCase(structType.name);
    final filename =
        'models/${nameSanitizer.toSnakeCase(structType.name)}.dart';

    final importManager = ImportManager();

    if (_hasBytes(structType)) {
      importManager.addDartImport('dart:typed_data');
    }

    importManager.addPackageImport('package:abidock_mvx/abidock_mvx.dart');

    final dependencies = _collectDependencies(structType);
    for (final dep in dependencies.toList()..sort()) {
      final depFile = nameSanitizer.toSnakeCase(dep);
      importManager.addRelativeImport('$depFile.dart');
    }

    buffer.write(importManager.generate());
    buffer.writeln();

    buffer.writeln('/// ${structType.name} model.');

    if (structType.metadata != null && structType.metadata!['docs'] != null) {
      final docs = structType.metadata!['docs'];
      if (docs is String && docs.isNotEmpty) {
        buffer.writeln('///');
        for (final line in docs.split('\n')) {
          if (line.trim().isEmpty) {
            buffer.writeln('///');
          } else {
            buffer.writeln('/// $line');
          }
        }
      } else if (docs is List && docs.isNotEmpty) {
        buffer.writeln('///');
        for (final line in docs) {
          final lineStr = line.toString();
          if (lineStr.trim().isEmpty) {
            buffer.writeln('///');
          } else {
            buffer.writeln('/// $lineStr');
          }
        }
      }
    }

    buffer.writeln('class $className {');

    buffer.write('  const $className(');
    if (structType.fieldDefinitions.isNotEmpty) {
      buffer.writeln('{');
      for (final field in structType.fieldDefinitions) {
        final fieldName = nameSanitizer.sanitizeFieldName(field.name);
        buffer.writeln('    required this.$fieldName,');
      }
      buffer.writeln('  }');
    }
    buffer.writeln(');');
    buffer.writeln();

    for (final field in structType.fieldDefinitions) {
      final fieldName = nameSanitizer.sanitizeFieldName(field.name);
      final dartType = typeMapper.mapToDartType(field.type);
      buffer.writeln('  final $dartType $fieldName;');
    }

    buffer.writeln();

    buffer.writeln(
      '  static final type = ${_generateStructTypeExpr(structType)};',
    );
    buffer.writeln();

    buffer.writeln('  factory $className.fromAbi(TypedValue value) {');
    buffer.writeln('    final struct = value as StructValue;');
    buffer.writeln('    return $className(');
    for (final field in structType.fieldDefinitions) {
      final fieldName = nameSanitizer.sanitizeFieldName(field.name);
      final dartType = typeMapper.mapToDartType(field.type);
      final isListOfCustomStruct = _isListOfCustomStruct(field.type);

      if (isListOfCustomStruct) {
        final elementTypeName = _getListElementTypeName(dartType);
        buffer.writeln('      $fieldName: () {');
        buffer.writeln(
          '        final listValue = struct.getFieldValue(\'${field.name}\') as ListValue;',
        );
        buffer.writeln(
          '        return listValue.elements.map((item) => $elementTypeName.fromAbi(item)).toList();',
        );
        buffer.writeln('      }(),');
      } else if (field.type is EnumType) {
        final enumTypeName = nameSanitizer.toPascalCase(field.type.name);
        buffer.writeln('      $fieldName: () {');
        buffer.writeln(
          '        final fieldValue = struct.getFieldValue(\'${field.name}\').nativeValue;',
        );
        buffer.writeln('        if (fieldValue == null) {');
        buffer.writeln(
          '          throw ArgumentError(\'Field ${field.name} cannot be null for enum type $enumTypeName\');',
        );
        buffer.writeln('        }');
        buffer.writeln('        if (fieldValue is Map<String, dynamic>) {');
        buffer.writeln(
          '          return $enumTypeName.fromAbi($enumTypeName.type.createValue(fieldValue));',
        );
        buffer.writeln('        }');
        buffer.writeln(
          '        return $enumTypeName.fromAbi($enumTypeName.type.createValue(fieldValue));',
        );
        buffer.writeln('      }(),');
      } else {
        buffer.writeln(
          '      $fieldName: infer<$dartType>(struct.getFieldValue(\'${field.name}\').nativeValue),',
        );
      }
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  TypedValue toAbi() {');
    buffer.writeln('    return type.createValue({');
    for (final field in structType.fieldDefinitions) {
      final fieldName = nameSanitizer.sanitizeFieldName(field.name);
      final convertedValue = _generateToAbiConversion(field.type, fieldName);
      buffer.writeln('      \'${field.name}\': $convertedValue,');
    }
    buffer.writeln('    });');
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  Map<String, dynamic> toJson() {');
    buffer.writeln('    return {');
    for (final field in structType.fieldDefinitions) {
      final fieldName = nameSanitizer.sanitizeFieldName(field.name);
      final jsonValue = _generateToJsonValue(field.type, fieldName);
      buffer.writeln('      \'${field.name}\': $jsonValue,');
    }
    buffer.writeln('    };');
    buffer.writeln('  }');
    buffer.writeln('}');

    return FileOutput(path: filename, content: buffer.toString());
  }

  FileOutput _generateEnum(EnumType enumType) {
    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());
    final enumName = nameSanitizer.toPascalCase(enumType.name);
    final filename = 'models/${nameSanitizer.toSnakeCase(enumType.name)}.dart';

    buffer.writeln('import \'package:abidock_mvx/abidock_mvx.dart\';');
    buffer.writeln();

    buffer.writeln('/// ${enumType.name} enum.');

    if (enumType.metadata != null && enumType.metadata!['docs'] != null) {
      final docs = enumType.metadata!['docs'];
      if (docs is String && docs.isNotEmpty) {
        buffer.writeln('///');
        for (final line in docs.split('\n')) {
          if (line.trim().isEmpty) {
            buffer.writeln('///');
          } else {
            buffer.writeln('/// $line');
          }
        }
      } else if (docs is List && docs.isNotEmpty) {
        buffer.writeln('///');
        for (final line in docs) {
          final lineStr = line.toString();
          if (lineStr.trim().isEmpty) {
            buffer.writeln('///');
          } else {
            buffer.writeln('/// $lineStr');
          }
        }
      }
    }

    buffer.writeln('enum $enumName {');

    for (int i = 0; i < enumType.variants.length; i++) {
      final variant = enumType.variants[i];
      final variantName = keywordSanitizer.sanitizeEnumVariant(
        nameSanitizer.toCamelCase(variant.name),
      );
      buffer.write('  $variantName');
      if (i < enumType.variants.length - 1) {
        buffer.writeln(',');
      } else {
        buffer.writeln(';');
      }
    }
    buffer.writeln();

    buffer.writeln('  static final type = ${_generateEnumTypeExpr(enumType)};');
    buffer.writeln();

    buffer.writeln('  factory $enumName.fromAbi(TypedValue value) {');
    buffer.writeln('    final nativeValue = value.nativeValue;');
    buffer.writeln('    ');
    buffer.writeln('    // Handle int discriminant');
    buffer.writeln('    if (nativeValue is int) {');
    buffer.writeln(
      '      final discriminants = <int>[${enumType.variants.map((v) => '${v.discriminant}').join(', ')}];',
    );
    buffer.writeln('      final idx = discriminants.indexOf(nativeValue);');
    buffer.writeln(
      '      if (idx < 0) throw ArgumentError(\'Unknown $enumName discriminant: \$nativeValue\');',
    );
    buffer.writeln('      return $enumName.values[idx];');
    buffer.writeln('    }');
    buffer.writeln('    ');
    buffer.writeln('    // Handle String variant name (from event parsing)');
    buffer.writeln('    if (nativeValue is String) {');
    buffer.writeln('      return $enumName.values.firstWhere(');
    buffer.writeln(
      '        (v) => v.name.toLowerCase() == nativeValue.toLowerCase(),',
    );
    buffer.writeln(
      '        orElse: () => throw ArgumentError(\'Unknown $enumName variant: \$nativeValue\'),',
    );
    buffer.writeln('      );');
    buffer.writeln('    }');
    buffer.writeln('    ');
    buffer.writeln(
      '    throw ArgumentError(\'Invalid $enumName value: \$nativeValue\');',
    );
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  TypedValue toAbi() {');
    buffer.writeln('    return type.createValue(index);');
    buffer.writeln('  }');
    buffer.writeln('}');

    return FileOutput(path: filename, content: buffer.toString());
  }

  /// Generates an explicit enum model file.
  ///
  /// Explicit enums are simpler than regular enums - they only have string
  /// variants without associated data. They are used for simple discriminated
  /// values like status codes or category names.
  FileOutput _generateExplicitEnum(ExplicitEnumType enumType) {
    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());
    final enumName = nameSanitizer.toPascalCase(enumType.name);
    final filename = 'models/${nameSanitizer.toSnakeCase(enumType.name)}.dart';

    buffer.writeln('import \'package:abidock_mvx/abidock_mvx.dart\';');
    buffer.writeln();

    buffer.writeln('/// ${enumType.name} explicit enum.');

    if (enumType.metadata != null && enumType.metadata!['docs'] != null) {
      final docs = enumType.metadata!['docs'];
      if (docs is String && docs.isNotEmpty) {
        buffer.writeln('///');
        for (final line in docs.split('\n')) {
          if (line.trim().isEmpty) {
            buffer.writeln('///');
          } else {
            buffer.writeln('/// $line');
          }
        }
      } else if (docs is List && docs.isNotEmpty) {
        buffer.writeln('///');
        for (final line in docs) {
          final lineStr = line.toString();
          if (lineStr.trim().isEmpty) {
            buffer.writeln('///');
          } else {
            buffer.writeln('/// $lineStr');
          }
        }
      }
    }

    buffer.writeln('enum $enumName {');

    for (int i = 0; i < enumType.variants.length; i++) {
      final variant = enumType.variants[i];
      final variantName = keywordSanitizer.sanitizeEnumVariant(
        nameSanitizer.toCamelCase(variant.name),
      );
      buffer.write('  $variantName');
      if (i < enumType.variants.length - 1) {
        buffer.writeln(',');
      } else {
        buffer.writeln(';');
      }
    }
    buffer.writeln();

    buffer.writeln(
      '  static final type = ${_generateExplicitEnumTypeExpr(enumType)};',
    );
    buffer.writeln();

    buffer.writeln('  factory $enumName.fromAbi(TypedValue value) {');
    buffer.writeln('    final nativeValue = value.nativeValue;');
    buffer.writeln('    ');
    buffer.writeln('    // Handle int discriminant');
    buffer.writeln('    if (nativeValue is int) {');
    buffer.writeln(
      '      final discriminants = <int>[${enumType.variants.map((v) => '${v.discriminant}').join(', ')}];',
    );
    buffer.writeln('      final idx = discriminants.indexOf(nativeValue);');
    buffer.writeln(
      '      if (idx < 0) throw ArgumentError(\'Unknown $enumName discriminant: \$nativeValue\');',
    );
    buffer.writeln('      return $enumName.values[idx];');
    buffer.writeln('    }');
    buffer.writeln('    ');
    buffer.writeln('    // Handle String variant name');
    buffer.writeln('    if (nativeValue is String) {');
    buffer.writeln('      return $enumName.values.firstWhere(');
    buffer.writeln(
      '        (v) => v.name.toLowerCase() == nativeValue.toLowerCase(),',
    );
    buffer.writeln(
      '        orElse: () => throw ArgumentError(\'Unknown $enumName variant: \$nativeValue\'),',
    );
    buffer.writeln('      );');
    buffer.writeln('    }');
    buffer.writeln('    ');
    buffer.writeln(
      '    throw ArgumentError(\'Invalid $enumName value: \$nativeValue\');',
    );
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  TypedValue toAbi() {');
    buffer.writeln('    return type.createValue(index);');
    buffer.writeln('  }');
    buffer.writeln('}');

    return FileOutput(path: filename, content: buffer.toString());
  }

  String _generateStructTypeExpr(StructType type) {
    final buffer = StringBuffer();
    buffer.write('StructType(name: \'${type.name}\', fieldDefinitions: [');

    for (int i = 0; i < type.fieldDefinitions.length; i++) {
      final field = type.fieldDefinitions[i];
      buffer.write(
        'FieldDefinition(name: \'${field.name}\', type: ${typeMapper.mapToTypeExpression(field.type)})',
      );
      if (i < type.fieldDefinitions.length - 1) {
        buffer.write(', ');
      }
    }

    buffer.write('])');
    return buffer.toString();
  }

  String _generateEnumTypeExpr(EnumType type) {
    final buffer = StringBuffer();
    buffer.write('EnumType(name: \'${type.name}\', variants: [');

    for (int i = 0; i < type.variants.length; i++) {
      final variant = type.variants[i];
      buffer.write(
        'const EnumVariantDefinition(name: \'${variant.name}\', discriminant: ${variant.discriminant})',
      );
      if (i < type.variants.length - 1) {
        buffer.write(', ');
      }
    }

    buffer.write('])');
    return buffer.toString();
  }

  String _generateExplicitEnumTypeExpr(ExplicitEnumType type) {
    final buffer = StringBuffer();
    buffer.write('ExplicitEnumType(name: \'${type.name}\', variants: [');

    for (int i = 0; i < type.variants.length; i++) {
      final variant = type.variants[i];
      buffer.write(
        'const ExplicitEnumVariantDefinition(name: \'${variant.name}\', discriminant: ${variant.discriminant})',
      );
      if (i < type.variants.length - 1) {
        buffer.write(', ');
      }
    }

    buffer.write('])');
    return buffer.toString();
  }

  Set<String> _collectDependencies(StructType type) {
    final deps = <String>{};
    for (final field in type.fieldDefinitions) {
      _collectTypeDependencies(field.type, deps);
    }
    deps.remove(type.name);
    return deps;
  }

  void _collectTypeDependencies(AbiType type, Set<String> deps) {
    if (type is StructType || type is EnumType || type is ExplicitEnumType) {
      deps.add(type.name);
    } else if (type is OptionType) {
      _collectTypeDependencies(type.innerType, deps);
    } else if (type is OptionalType) {
      _collectTypeDependencies(type.innerType, deps);
    } else if (type is ListType) {
      _collectTypeDependencies(type.elementType, deps);
    } else if (type is ArrayType) {
      _collectTypeDependencies(type.elementType, deps);
    } else if (type is VariadicType) {
      _collectTypeDependencies(type.itemType, deps);
    } else if (type is TupleType) {
      for (final elem in type.elementTypes) {
        _collectTypeDependencies(elem, deps);
      }
    } else if (type is CompositeType) {
      for (final field in type.fieldTypes) {
        _collectTypeDependencies(field, deps);
      }
    }
  }

  List<String> _getGenerationOrder() {
    final visited = <String>{};
    final order = <String>[];

    void visit(String typeName) {
      if (visited.contains(typeName)) return;
      visited.add(typeName);

      final type = abi.types[typeName];
      if (type is StructType) {
        for (final field in type.fieldDefinitions) {
          _visitTypeDeps(field.type, visit);
        }
      }

      order.add(typeName);
    }

    for (final name in abi.types.keys) {
      visit(name);
    }

    return order;
  }

  void _visitTypeDeps(AbiType type, void Function(String) visit) {
    if (type is StructType || type is EnumType || type is ExplicitEnumType) {
      if (abi.types.containsKey(type.name)) {
        visit(type.name);
      }
    }

    for (final param in type.typeParameters) {
      _visitTypeDeps(param, visit);
    }
  }

  bool _hasBytes(StructType structType) {
    for (final field in structType.fieldDefinitions) {
      if (_fieldHasBytes(field.type)) return true;
    }
    return false;
  }

  bool _fieldHasBytes(AbiType type) {
    if (type is BytesType) return true;
    if (type is OptionType) return _fieldHasBytes(type.innerType);
    if (type is OptionalType) return _fieldHasBytes(type.innerType);
    if (type is ListType) return _fieldHasBytes(type.elementType);
    if (type is ArrayType) return _fieldHasBytes(type.elementType);
    if (type is VariadicType) return _fieldHasBytes(type.itemType);
    if (type is TupleType) return type.elementTypes.any(_fieldHasBytes);
    return false;
  }

  String _generateToAbiConversion(AbiType type, String fieldName) {
    if (type is AddressType) {
      return fieldName;
    }

    if (type is TokenIdentifierType) {
      return fieldName;
    }

    if (type is StructType || type is EnumType || type is ExplicitEnumType) {
      return '$fieldName.toAbi()';
    }

    if (type is OptionType || type is OptionalType) {
      final AbiType innerType = type is OptionType
          ? type.innerType
          : (type as OptionalType).innerType;
      final innerConversion = _generateToAbiConversion(innerType, fieldName);

      if (innerConversion != fieldName) {
        if (innerConversion.endsWith('.toAbi()')) {
          return '$fieldName?.toAbi()';
        }
        return '$fieldName != null ? $innerConversion : null';
      }
      return fieldName;
    }

    if (type is ListType || type is ArrayType) {
      final AbiType elementType = type is ListType
          ? type.elementType
          : (type as ArrayType).elementType;
      final elementConversion = _generateToAbiConversion(elementType, 'e');

      if (elementConversion != 'e') {
        return '$fieldName.map((e) => $elementConversion).toList()';
      }
      return fieldName;
    }

    if (type is TupleType) {
      return fieldName;
    }

    return fieldName;
  }

  bool _isListOfCustomStruct(AbiType type) {
    if (type is ListType) {
      return abi.types.containsKey(type.elementType.name);
    }
    if (type is ArrayType) {
      return abi.types.containsKey(type.elementType.name);
    }
    return false;
  }

  /// Generates a JSON-safe expression for a field value.
  String _generateToJsonValue(AbiType type, String fieldName) {
    if (type is StructType) {
      return '$fieldName.toJson()';
    }
    if (type is EnumType || type is ExplicitEnumType) {
      return '$fieldName.index';
    }
    if (type is AddressType) {
      return fieldName;
    }
    if (type is BigUIntType ||
        type is BigIntType ||
        type is U64Type ||
        type is I64Type ||
        type is ManagedDecimalType) {
      return '$fieldName.toString()';
    }
    if (type is OptionType || type is OptionalType) {
      final AbiType innerType = type is OptionType
          ? type.innerType
          : (type as OptionalType).innerType;
      final innerJson = _generateToJsonValue(innerType, fieldName);
      if (innerJson != fieldName) {
        if (innerJson.startsWith('$fieldName.')) {
          return '$fieldName?.${innerJson.substring(fieldName.length + 1)}';
        }
        return '$fieldName != null ? $innerJson : null';
      }
      return fieldName;
    }
    if (type is ListType || type is ArrayType) {
      final AbiType elementType = type is ListType
          ? type.elementType
          : (type as ArrayType).elementType;
      final elementJson = _generateToJsonValue(elementType, 'e');
      if (elementJson != 'e') {
        return '$fieldName.map((e) => $elementJson).toList()';
      }
      return fieldName;
    }
    return fieldName;
  }

  String _getListElementTypeName(String dartType) {
    if (!dartType.startsWith('List<') || !dartType.endsWith('>')) {
      return dartType;
    }
    return dartType.substring(5, dartType.length - 1);
  }
}
