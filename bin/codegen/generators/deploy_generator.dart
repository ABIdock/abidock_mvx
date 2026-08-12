import 'package:abidock_mvx/src/abi/abi.dart';

import '../core/import_manager.dart';
import '../core/name_sanitizer.dart';
import '../core/type_mapper.dart';
import '../models/file_output.dart';
import 'generator_base.dart';

/// Emits top-level `deploy()` / `upgrade()` helpers when the ABI exposes a
/// `constructor` / `upgradeConstructor`. Both helpers encode the typed
/// constructor inputs through [ArgSerializer] and hand the resulting raw
/// argument bytes to [SmartContractTransactionsFactory] — matching the
/// hex-args contract of `createTransactionForDeploy` /
/// `createTransactionForUpgrade`.
///
/// Generates nothing when the corresponding ABI section is absent.
class DeployGenerator extends GeneratorBase {
  DeployGenerator({
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
    if (abi.constructor != null) {
      files.add(_generate(abi.constructor!, isUpgrade: false));
    }
    if (abi.upgradeConstructor != null) {
      files.add(_generate(abi.upgradeConstructor!, isUpgrade: true));
    }
    return files;
  }

  FileOutput _generate(AbiEndpoint endpoint, {required bool isUpgrade}) {
    final fnName = isUpgrade ? 'upgrade' : 'deploy';
    final filename = 'calls/$fnName.dart';

    final importManager = ImportManager();
    importManager.addDartImport('dart:typed_data');
    importManager.addPackageImport('package:abidock_mvx/abidock_mvx.dart');

    final customTypes = <String>{};
    for (final input in endpoint.inputs) {
      _collectTypeNames(input.type, customTypes);
    }
    for (final t in customTypes.toList()..sort()) {
      importManager.addRelativeImport(
        '../models/${nameSanitizer.toSnakeCase(t)}.dart',
      );
    }

    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());
    buffer.write(importManager.generate());
    buffer.writeln();

    if (isUpgrade) {
      buffer.writeln('/// Builds an unsigned upgrade transaction.');
      buffer.writeln('///');
      buffer.writeln(
        '/// Typed wrapper over [SmartContractTransactionsFactory.createTransactionForUpgrade].',
      );
    } else {
      buffer.writeln('/// Builds an unsigned deploy transaction.');
      buffer.writeln('///');
      buffer.writeln(
        '/// Typed wrapper over [SmartContractTransactionsFactory.createTransactionForDeploy].',
      );
    }
    if (endpoint.inputs.isNotEmpty) {
      buffer.writeln('///');
      buffer.writeln('/// #### Constructor parameters:');
      for (final input in endpoint.inputs) {
        final paramName = nameSanitizer.sanitizeParamName(input.name);
        final abiType = typeMapper.getAbiTypeStringForDocs(input.type);
        buffer.writeln('/// - `$paramName`: $abiType');
      }
    }
    buffer.writeln('Transaction $fnName(');
    buffer.writeln('  NetworkProvider networkProvider,');
    buffer.writeln('  Address sender,');
    buffer.writeln('  Nonce nonce,');
    buffer.writeln('  Uint8List bytecode,');
    buffer.writeln('  GasLimit gasLimit,');
    if (isUpgrade) {
      buffer.writeln('  Address contract,');
    }
    final paramNames = <String>[];
    for (final input in endpoint.inputs) {
      final paramName = nameSanitizer.sanitizeParamName(input.name);
      paramNames.add(paramName);
      final dartType = typeMapper.mapToDartType(input.type);
      buffer.writeln('  $dartType $paramName,');
    }
    buffer.writeln('  {');
    buffer.writeln('    Uint8List? codeMetadata,');
    if (!isUpgrade) {
      buffer.writeln("    String vmType = '0500',");
    }
    buffer.writeln('  }');
    buffer.writeln(') {');

    buffer.writeln('  final factory = SmartContractTransactionsFactory(');
    buffer.writeln(
      '    SmartContractTransactionsConfig(chainId: networkProvider.chainId),',
    );
    buffer.writeln('  );');
    buffer.writeln();

    if (endpoint.inputs.isEmpty) {
      buffer.writeln('  const List<Uint8List> argBytes = <Uint8List>[];');
    } else {
      buffer.writeln('  final typedArgs = <TypedValue>[');
      for (int i = 0; i < endpoint.inputs.length; i++) {
        final input = endpoint.inputs[i];
        final paramName = paramNames[i];
        final typeExpr = typeMapper.mapToTypeExpression(input.type);
        final wrapped = typeMapper.wrapArgumentExpression(
          input.type,
          paramName,
        );
        buffer.writeln('    $typeExpr.createValue($wrapped),');
      }
      buffer.writeln('  ];');
      buffer.writeln(
        '  final argBytes = ArgSerializer().valuesToBuffers(typedArgs);',
      );
    }

    buffer.writeln();
    if (isUpgrade) {
      buffer.writeln('  return factory.createTransactionForUpgrade(');
      buffer.writeln('    sender: sender,');
      buffer.writeln('    contract: contract,');
      buffer.writeln('    bytecode: bytecode,');
      buffer.writeln('    gasLimit: gasLimit,');
      buffer.writeln('    codeMetadata: codeMetadata,');
      buffer.writeln('    arguments: argBytes,');
      buffer.writeln('    nonce: nonce,');
      buffer.writeln('  );');
    } else {
      buffer.writeln('  return factory.createTransactionForDeploy(');
      buffer.writeln('    sender: sender,');
      buffer.writeln('    bytecode: bytecode,');
      buffer.writeln('    gasLimit: gasLimit,');
      buffer.writeln('    codeMetadata: codeMetadata,');
      buffer.writeln('    vmType: vmType,');
      buffer.writeln('    arguments: argBytes,');
      buffer.writeln('    nonce: nonce,');
      buffer.writeln('  );');
    }

    buffer.writeln('}');
    return FileOutput(path: filename, content: buffer.toString());
  }

  void _collectTypeNames(AbiType type, Set<String> types) {
    if (type is StructType || type is EnumType || type is ExplicitEnumType) {
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
    } else if (type is MultiValueType) {
      for (final t in type.types) {
        _collectTypeNames(t, types);
      }
    }
  }
}
