import 'package:abidock_mvx/src/abi/abi.dart';

import '../core/import_manager.dart';
import '../core/name_sanitizer.dart';
import '../core/type_mapper.dart';
import '../models/file_output.dart';
import 'generator_base.dart';

class CallsGenerator extends GeneratorBase {
  final SmartContractAbi abi;
  final TypeMapper typeMapper;
  final NameSanitizer nameSanitizer;
  final bool generateUnsigned;
  final bool useAutoGas;

  /// Gas limit used when building the *probe* transaction we feed to
  /// `simulateGas` in the auto-gas path. 600M is the MultiversX per-tx
  /// ceiling — it guarantees the probe doesn't get rejected for
  /// insufficient gas before the simulator can compute an estimate.
  static const String _simulationProbeGas = 'const GasLimit(600000000)';

  CallsGenerator({
    required this.abi,
    required this.typeMapper,
    required this.nameSanitizer,
    this.generateUnsigned = true,
    this.useAutoGas = false,
  });

  @override
  List<FileOutput> generate() {
    final files = <FileOutput>[];

    for (final endpoint in abi.endpoints.mutableEndpoints) {
      files.add(_generateCall(endpoint));
    }

    return files;
  }

  FileOutput _generateCall(AbiEndpoint endpoint) {
    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());
    final functionName = nameSanitizer.sanitizeParamName(endpoint.name);
    final filename = 'calls/${nameSanitizer.toSnakeCase(endpoint.name)}.dart';

    final importManager = ImportManager();

    if (_needsTypedData(endpoint)) {
      importManager.addDartImport('dart:typed_data');
    }

    importManager.addPackageImport('package:abidock_mvx/abidock_mvx.dart');

    final customTypes = _collectCustomTypes(endpoint);
    for (final typeName in customTypes.toList()..sort()) {
      final typeFile = nameSanitizer.toSnakeCase(typeName);
      importManager.addRelativeImport('../models/$typeFile.dart');
    }
    buffer.write(importManager.generate());
    buffer.writeln();

    buffer.writeln('/// Calls ${endpoint.name} endpoint.');

    if (endpoint.documentation != null && endpoint.documentation!.isNotEmpty) {
      buffer.writeln('///');
      for (final line in endpoint.documentation!.split('\n')) {
        if (line.trim().isEmpty) {
          buffer.writeln('///');
        } else {
          buffer.writeln('/// ${escapeDocLine(line)}');
        }
      }
    }

    buffer.writeln('///');

    if (endpoint.isOnlyOwner) {
      buffer.writeln('/// #### Access:');
      buffer.writeln('/// Only owner');
      buffer.writeln('///');
    }

    if (endpoint.isPayable) {
      buffer.writeln('/// #### Payable:');
      final tokens = <String>[];
      if (endpoint.payableInTokens.isEmpty ||
          endpoint.payableInTokens.contains('*')) {
        tokens.add('EGLD');
        tokens.add('ESDT tokens');
      } else {
        if (endpoint.payableInTokens.contains('EGLD')) {
          tokens.add('EGLD');
        }
        final esdtTokens = endpoint.payableInTokens
            .where((t) => t != 'EGLD' && t != '*')
            .toList();
        if (esdtTokens.isNotEmpty) {
          tokens.add('ESDT tokens (${esdtTokens.join(', ')})');
        }
      }
      buffer.writeln('/// ${tokens.join(', ')}');
      buffer.writeln('///');
    }

    if (endpoint.inputs.isNotEmpty) {
      buffer.writeln('/// #### Parameters:');
      for (final input in endpoint.inputs) {
        final paramName = nameSanitizer.sanitizeParamName(input.name);
        final abiType = typeMapper.getAbiTypeStringForDocs(input.type);
        buffer.writeln('/// - `$paramName`: $abiType');
      }
      buffer.writeln('///');
    }

    buffer.writeln('/// #### Throws:');
    buffer.writeln('/// - [NetworkException] if network request fails');
    buffer.writeln(
      '/// - [EndpointNotFoundException] if endpoint not found in ABI',
    );
    buffer.writeln('/// - [ArgumentEncodingException] if ABI encoding fails');
    buffer.writeln('Future<Transaction> $functionName(');
    buffer.writeln('  SmartContractController controller,');
    buffer.writeln('  IAccount sender,');
    buffer.writeln('  Nonce nonce,');

    final argsList = <String>[];
    for (final input in endpoint.inputs) {
      final paramName = nameSanitizer.sanitizeParamName(input.name);
      argsList.add(typeMapper.wrapArgumentExpression(input.type, paramName));
      final dartType = typeMapper.mapToDartType(input.type);
      buffer.writeln('  $dartType $paramName,');
    }

    buffer.writeln('  {');
    if (endpoint.isPayable) {
      buffer.writeln(
        '    List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],',
      );
    }
    if (!useAutoGas) {
      buffer.writeln('    required GasLimit gasLimit,');
    }
    buffer.writeln('    Address? relayer,');
    buffer.writeln('    Address? guardian,');
    buffer.writeln('    Balance? value,');
    buffer.writeln('  }');
    buffer.writeln(') async {');

    if (useAutoGas) {
      buffer.writeln('  final factory = SmartContractCallFactory(');
      buffer.writeln('    contractAddress: controller.contractAddress,');
      buffer.writeln('    abi: controller.abi,');
      buffer.writeln('    chainId: controller.networkProvider.chainId,');
      buffer.writeln('  );');
      buffer.writeln('  final probeTx = factory.createCall(');
      buffer.writeln('    sender: sender.address,');
      buffer.writeln('    nonce: nonce,');
      buffer.writeln('    endpointName: \'${endpoint.name}\',');
      if (argsList.isNotEmpty) {
        buffer.writeln('    arguments: <dynamic>[${argsList.join(', ')}],');
      }
      if (endpoint.isPayable) {
        buffer.writeln('    tokenTransfers: tokenTransfers,');
      }
      buffer.writeln('    gasLimit: $_simulationProbeGas,');
      buffer.writeln('    value: value,');
      buffer.writeln('  );');
      buffer.writeln(
        '  final gasLimit = await simulateGas(probeTx, controller.networkProvider);',
      );
      buffer.writeln();
      buffer.writeln('  return controller.call(');
      buffer.writeln('    account: sender,');
      buffer.writeln('    nonce: nonce,');
      buffer.writeln('    endpointName: \'${endpoint.name}\',');
      if (argsList.isNotEmpty) {
        buffer.writeln('    arguments: <dynamic>[${argsList.join(', ')}],');
      }
      if (endpoint.isPayable) {
        buffer.writeln('    tokenTransfers: tokenTransfers,');
      }
      buffer.writeln('    value: value,');
      buffer.writeln('    options: BaseControllerInput(');
      buffer.writeln('      gasLimit: gasLimit,');
      buffer.writeln('      relayer: relayer,');
      buffer.writeln('      guardian: guardian,');
      buffer.writeln('    ),');
      buffer.writeln('  );');
    } else {
      buffer.writeln('  return controller.call(');
      buffer.writeln('    account: sender,');
      buffer.writeln('    nonce: nonce,');
      buffer.writeln('    endpointName: \'${endpoint.name}\',');
      if (argsList.isNotEmpty) {
        buffer.writeln('    arguments: <dynamic>[${argsList.join(', ')}],');
      }
      if (endpoint.isPayable) {
        buffer.writeln('    tokenTransfers: tokenTransfers,');
      }
      buffer.writeln('    value: value,');
      buffer.writeln('    options: BaseControllerInput(');
      buffer.writeln('      gasLimit: gasLimit,');
      buffer.writeln('      relayer: relayer,');
      buffer.writeln('      guardian: guardian,');
      buffer.writeln('    ),');
      buffer.writeln('  );');
    }

    buffer.writeln('}');

    if (generateUnsigned) {
      buffer.writeln();
      _generateUnsignedCall(buffer, endpoint, functionName);
    }

    return FileOutput(path: filename, content: buffer.toString());
  }

  /// Generates unsigned transaction variant for batch operations.
  void _generateUnsignedCall(
    StringBuffer buffer,
    AbiEndpoint endpoint,
    String functionName,
  ) {
    buffer.writeln(
      '/// Builds an unsigned transaction for ${endpoint.name} endpoint.',
    );

    if (endpoint.inputs.isNotEmpty) {
      buffer.writeln('/// #### Parameters:');
      for (final input in endpoint.inputs) {
        final paramName = nameSanitizer.sanitizeParamName(input.name);
        final abiType = typeMapper.getAbiTypeStringForDocs(input.type);
        buffer.writeln('/// - `$paramName`: $abiType');
      }
      buffer.writeln('///');
    }

    buffer.writeln('/// #### Returns:');
    if (useAutoGas) {
      buffer.writeln(
        '/// Future<[Transaction]> - Unsigned transaction with auto-estimated gas',
      );
    } else {
      buffer.writeln('/// Unsigned [Transaction] ready to be signed');
    }
    buffer.writeln('///');
    buffer.writeln('/// #### Example:');
    buffer.writeln('/// ```dart');
    buffer.writeln('/// // Build unsigned transactions for batch signing');
    if (useAutoGas) {
      buffer.writeln(
        '/// final tx1 = await ${functionName}Unsigned(factory, provider, sender, nonce1, ...);',
      );
      buffer.writeln(
        '/// final tx2 = await anotherUnsigned(factory2, provider, sender, nonce2, ...);',
      );
    } else {
      buffer.writeln(
        '/// final tx1 = ${functionName}Unsigned(factory, sender, nonce1, ...);',
      );
      buffer.writeln(
        '/// final tx2 = anotherUnsigned(factory2, sender, nonce2, ...);',
      );
    }
    buffer.writeln('///');
    buffer.writeln('/// // Sign batch');
    buffer.writeln(
      '/// final sigs = await account.signTransactions([tx1, tx2]);',
    );
    buffer.writeln('///');
    buffer.writeln('/// // Apply signatures and send');
    buffer.writeln(
      '/// final signed1 = tx1.copyWith(newSignature: Signature.fromUint8List(sigs[0]));',
    );
    buffer.writeln(
      '/// final signed2 = tx2.copyWith(newSignature: Signature.fromUint8List(sigs[1]));',
    );
    buffer.writeln('/// await provider.sendTransactions([signed1, signed2]);');
    buffer.writeln('/// ```');

    if (useAutoGas) {
      buffer.writeln('Future<Transaction> ${functionName}Unsigned(');
      buffer.writeln('  SmartContractCallFactory factory,');
      buffer.writeln('  NetworkProvider networkProvider,');
      buffer.writeln('  Address sender,');
      buffer.writeln('  Nonce nonce,');
    } else {
      buffer.writeln('Transaction ${functionName}Unsigned(');
      buffer.writeln('  SmartContractCallFactory factory,');
      buffer.writeln('  Address sender,');
      buffer.writeln('  Nonce nonce,');
    }

    final argsList = <String>[];
    for (final input in endpoint.inputs) {
      final paramName = nameSanitizer.sanitizeParamName(input.name);
      argsList.add(typeMapper.wrapArgumentExpression(input.type, paramName));
      final dartType = typeMapper.mapToDartType(input.type);
      buffer.writeln('  $dartType $paramName,');
    }

    buffer.writeln('  {');
    if (endpoint.isPayable) {
      buffer.writeln(
        '    List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],',
      );
    }
    if (!useAutoGas) {
      buffer.writeln('    required GasLimit gasLimit,');
    }
    buffer.writeln('    Balance? value,');
    buffer.writeln('  }');

    if (useAutoGas) {
      buffer.writeln(') async {');
    } else {
      buffer.writeln(') {');
    }

    if (useAutoGas) {
      buffer.writeln('  final tx = factory.createCall(');
      buffer.writeln('    sender: sender,');
      buffer.writeln('    nonce: nonce,');
      buffer.writeln('    endpointName: \'${endpoint.name}\',');
      if (argsList.isNotEmpty) {
        buffer.writeln('    arguments: <dynamic>[${argsList.join(', ')}],');
      }
      if (endpoint.isPayable) {
        buffer.writeln('    tokenTransfers: tokenTransfers,');
      }
      buffer.writeln('    gasLimit: $_simulationProbeGas,');
      buffer.writeln('    value: value,');
      buffer.writeln('  );');
      buffer.writeln();
      buffer.writeln(
        '  final gasLimit = await simulateGas(tx, networkProvider);',
      );
      buffer.writeln();
      buffer.writeln('  return tx.copyWith(newGasLimit: gasLimit);');
    } else {
      buffer.writeln('  return factory.createCall(');
      buffer.writeln('    sender: sender,');
      buffer.writeln('    nonce: nonce,');
      buffer.writeln('    endpointName: \'${endpoint.name}\',');
      if (argsList.isNotEmpty) {
        buffer.writeln('    arguments: <dynamic>[${argsList.join(', ')}],');
      }
      if (endpoint.isPayable) {
        buffer.writeln('    tokenTransfers: tokenTransfers,');
      }
      buffer.writeln('    gasLimit: gasLimit,');
      buffer.writeln('    value: value,');
      buffer.writeln('  );');
    }

    buffer.writeln('}');
  }

  Set<String> _collectCustomTypes(AbiEndpoint endpoint) {
    final types = <String>{};
    for (final input in endpoint.inputs) {
      _collectTypeNames(input.type, types);
    }
    return types;
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

  bool _needsTypedData(AbiEndpoint endpoint) {
    for (final param in endpoint.inputs) {
      if (typeMapper.needsTypedData(param.type)) return true;
    }
    for (final param in endpoint.outputs) {
      if (typeMapper.needsTypedData(param.type)) return true;
    }
    return false;
  }
}
