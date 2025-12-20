import 'package:abidock_mvx/src/abi/abi.dart';
import '../core/name_sanitizer.dart';
import '../core/type_mapper.dart';
import '../models/file_output.dart';
import 'generator_base.dart';

class QueriesGenerator extends GeneratorBase {
  final SmartContractAbi abi;
  final TypeMapper typeMapper;
  final NameSanitizer nameSanitizer;

  QueriesGenerator({
    required this.abi,
    required this.typeMapper,
    required this.nameSanitizer,
  });

  @override
  List<FileOutput> generate() {
    final files = <FileOutput>[];

    for (final endpoint in abi.endpoints.viewEndpoints) {
      files.add(_generateQuery(endpoint));
    }

    return files;
  }

  FileOutput _generateQuery(AbiEndpoint endpoint) {
    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());
    final functionName = nameSanitizer.toCamelCase(endpoint.name);
    final filename = 'queries/${nameSanitizer.toSnakeCase(endpoint.name)}.dart';

    final imports = <String>[];

    final needsTypedData = _needsTypedData(endpoint);
    if (needsTypedData) {
      imports.add('import \'dart:typed_data\';');
    }

    imports.add('import \'package:abidock_mvx/abidock_mvx.dart\';');

    final customTypes = _collectCustomTypes(endpoint);
    for (final typeName in customTypes.toList()..sort()) {
      final typeFile = nameSanitizer.toSnakeCase(typeName);
      imports.add('import \'../models/$typeFile.dart\';');
    }

    _writeSortedImports(buffer, imports);
    buffer.writeln();

    final hasOutput = endpoint.outputs.isNotEmpty;
    final returnType = hasOutput
        ? 'Future<${_getReturnType(endpoint.outputs.toList())}>'
        : 'Future<void>';

    buffer.writeln('/// Queries ${endpoint.name} endpoint.');

    if (endpoint.documentation != null && endpoint.documentation!.isNotEmpty) {
      buffer.writeln('///');
      for (final line in endpoint.documentation!.split('\n')) {
        if (line.trim().isEmpty) {
          buffer.writeln('///');
        } else {
          buffer.writeln('/// $line');
        }
      }
    }

    buffer.writeln('///');

    if (endpoint.isOnlyOwner) {
      buffer.writeln('/// #### Access:');
      buffer.writeln('/// Only owner');
      buffer.writeln('///');
    }

    buffer.writeln('/// #### Read-only:');
    buffer.writeln('/// Yes');

    if (endpoint.inputs.isNotEmpty) {
      buffer.writeln('///');
      buffer.writeln('/// #### Parameters:');
      for (final input in endpoint.inputs) {
        final paramName = nameSanitizer.toCamelCase(input.name);
        final abiType = typeMapper.getAbiTypeStringForDocs(input.type);
        buffer.writeln('/// - `$paramName`: $abiType');
      }
    }

    if (hasOutput) {
      buffer.writeln('///');
      buffer.writeln('/// #### Returns:');
      for (final output in endpoint.outputs) {
        final abiType = typeMapper.getAbiTypeStringForDocs(output.type);
        final outputName = output.name.isNotEmpty ? output.name : 'result';
        buffer.writeln('/// - `$outputName`: $abiType');
      }
    }

    buffer.writeln('///');
    buffer.writeln('/// #### Throws:');
    buffer.writeln('/// - [NetworkException] if network request fails');
    buffer.writeln('/// - [ABIException] if ABI decoding fails');
    buffer.writeln('$returnType $functionName(');
    buffer.writeln('  SmartContractController controller,');
    for (final input in endpoint.inputs) {
      final paramName = nameSanitizer.toCamelCase(input.name);
      final dartType = typeMapper.mapToDartType(input.type);
      buffer.writeln('  $dartType $paramName,');
    }
    buffer.writeln(') async {');

    if (endpoint.inputs.isNotEmpty) {
      for (final input in endpoint.inputs) {
        final paramName = nameSanitizer.toCamelCase(input.name);
        final typeExpr = typeMapper.mapToTypeExpression(input.type);
        buffer.writeln(
          '  final ${paramName}Value = $typeExpr.createValue($paramName);',
        );
      }
      buffer.writeln();
    }

    buffer.writeln('  return executeQuery(');
    buffer.writeln('    endpointName: \'${endpoint.name}\',');
    buffer.writeln('    action: () async {');

    if (hasOutput) {
      buffer.writeln('      final result = await controller.query(');
    } else {
      buffer.writeln('      await controller.query(');
    }

    buffer.writeln('        endpointName: \'${endpoint.name}\',');

    if (endpoint.inputs.isNotEmpty) {
      buffer.writeln('        arguments: [');
      for (final input in endpoint.inputs) {
        final paramName = nameSanitizer.toCamelCase(input.name);
        buffer.writeln('          ${paramName}Value,');
      }
      buffer.writeln('        ],');
    }

    buffer.writeln('      );');

    if (hasOutput) {
      buffer.writeln();
      final outputs = endpoint.outputs.toList();
      if (outputs.length == 1) {
        final output = outputs.first;
        final dartType = typeMapper.mapToDartType(output.type);
        if (output.multiResult) {
          final typeStr = output.type.toString();
          final isVariadic =
              typeStr.startsWith('variadic<') || typeStr.startsWith('multi<');

          buffer.writeln('      if (result.isEmpty) {');
          if (isVariadic) {
            buffer.writeln(
              '        return <${_extractInnerType(dartType)}>[];',
            );
          } else {
            buffer.writeln('        return null;');
          }
          buffer.writeln('      }');
        }
        buffer.writeln('      return infer<$dartType>(result[0]);');
      } else {
        buffer.writeln('      return (');
        for (int i = 0; i < outputs.length; i++) {
          final dartType = typeMapper.mapToDartType(outputs[i].type);
          buffer.write('        infer<$dartType>(result[$i])');
          if (i < outputs.length - 1) buffer.writeln(',');
        }
        buffer.writeln();
        buffer.writeln('      );');
      }
    }

    buffer.writeln('    },');
    buffer.writeln('  );');
    buffer.writeln('}');

    return FileOutput(path: filename, content: buffer.toString());
  }

  /// Extract inner type from List&lt;T&gt; into the inner T type.
  String _extractInnerType(String listType) {
    if (listType.startsWith('List<') && listType.endsWith('>')) {
      return listType.substring(5, listType.length - 1);
    }
    return 'dynamic';
  }

  String _getReturnType(List<AbiParameter> outputs) {
    if (outputs.isEmpty) return 'void';
    if (outputs.length == 1) {
      return typeMapper.mapToDartType(outputs[0].type);
    }

    final types = outputs
        .map((o) => typeMapper.mapToDartType(o.type))
        .join(', ');
    return '($types)';
  }

  Set<String> _collectCustomTypes(AbiEndpoint endpoint) {
    final types = <String>{};
    for (final input in endpoint.inputs) {
      _collectTypeNames(input.type, types);
    }
    for (final output in endpoint.outputs) {
      _collectTypeNames(output.type, types);
    }
    return types;
  }

  void _collectTypeNames(AbiType type, Set<String> types) {
    if (type is StructType || type is EnumType) {
      types.add(type.name);
    } else if (type is OptionType) {
      _collectTypeNames(type.innerType, types);
    } else if (type is OptionalType) {
      _collectTypeNames(type.innerType, types);
    } else if (type is ListType) {
      _collectTypeNames(type.elementType, types);
    } else if (type is ArrayType) {
      _collectTypeNames(type.elementType, types);
    } else if (type is VariadicType) {
      _collectTypeNames(type.itemType, types);
    } else if (type is TupleType) {
      for (final elem in type.elementTypes) {
        _collectTypeNames(elem, types);
      }
    } else if (type is CompositeType) {
      for (final field in type.fieldTypes) {
        _collectTypeNames(field, types);
      }
    }
  }

  bool _needsTypedData(AbiEndpoint endpoint) {
    for (final param in endpoint.inputs) {
      if (_typeNeedsTypedData(param.type)) return true;
    }
    for (final param in endpoint.outputs) {
      if (_typeNeedsTypedData(param.type)) return true;
    }
    return false;
  }

  bool _typeNeedsTypedData(AbiType type) {
    if (type is BytesType) return true;
    if (type is H256Type) return true;
    if (type is OptionType) return _typeNeedsTypedData(type.innerType);
    if (type is OptionalType) return _typeNeedsTypedData(type.innerType);
    if (type is ListType) return _typeNeedsTypedData(type.elementType);
    if (type is ArrayType) return _typeNeedsTypedData(type.elementType);
    if (type is VariadicType) return _typeNeedsTypedData(type.itemType);
    if (type is TupleType) return type.elementTypes.any(_typeNeedsTypedData);
    if (type is CompositeType) {
      for (final field in type.fieldTypes) {
        if (_typeNeedsTypedData(field)) return true;
      }
    }
    return false;
  }

  void _writeSortedImports(StringBuffer buffer, List<String> imports) {
    final dartImports = <String>[];
    final packageImports = <String>[];
    final relativeImports = <String>[];

    for (final import in imports) {
      if (import.contains('dart:')) {
        dartImports.add(import);
      } else if (import.contains('package:')) {
        packageImports.add(import);
      } else {
        relativeImports.add(import);
      }
    }

    dartImports.sort();
    packageImports.sort();
    relativeImports.sort();

    for (final import in dartImports) {
      buffer.writeln(import);
    }
    if (dartImports.isNotEmpty &&
        (packageImports.isNotEmpty || relativeImports.isNotEmpty)) {
      buffer.writeln();
    }

    for (final import in packageImports) {
      buffer.writeln(import);
    }
    if (packageImports.isNotEmpty && relativeImports.isNotEmpty) {
      buffer.writeln();
    }

    for (final import in relativeImports) {
      buffer.writeln(import);
    }
  }
}
