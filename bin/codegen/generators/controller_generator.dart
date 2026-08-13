import 'package:abidock_mvx/src/abi/abi.dart';

import '../core/known_package_symbols.dart';
import '../core/name_sanitizer.dart';
import '../core/type_mapper.dart';
import '../models/file_output.dart';
import 'generator_base.dart';

class ControllerGenerator extends GeneratorBase {
  final SmartContractAbi abi;
  final NameSanitizer nameSanitizer;
  final TypeMapper typeMapper;
  final String contractName;
  final bool useLogger;
  final bool useAutoGas;

  ControllerGenerator({
    required this.abi,
    required this.nameSanitizer,
    required this.typeMapper,
    required this.contractName,
    this.useLogger = false,
    this.useAutoGas = false,
  });

  /// Gets the PascalCase controller class name (e.g., 'ping_pong' -> 'PingPongController')
  String get controllerClassName =>
      '${nameSanitizer.toPascalCase(contractName)}Controller';

  /// Gets the PascalCase events class name (e.g., 'ping_pong' -> 'PingPongEvents')
  String get eventsClassName =>
      '${nameSanitizer.toPascalCase(contractName)}Events';

  @override
  List<FileOutput> generate() {
    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());

    final modelTypes = _collectModelTypes();

    final imports = <String>[];

    imports.add('import \'dart:async\';');

    final needsTypedData = _needsTypedData();
    if (needsTypedData) {
      imports.add('import \'dart:typed_data\';');
    }

    imports.add('import \'package:abidock_mvx/abidock_mvx.dart\';');
    imports.add('import \'abi.dart\';');

    for (final typeName in modelTypes.toList()..sort()) {
      final fileName = nameSanitizer.toSnakeCase(typeName);
      imports.add('import \'models/$fileName.dart\';');
    }

    for (final endpoint in abi.endpoints.viewEndpoints) {
      final name = nameSanitizer.toSnakeCase(endpoint.name);
      imports.add('import \'queries/$name.dart\' as ${name}_query;');
    }

    for (final endpoint in abi.endpoints.mutableEndpoints) {
      final name = nameSanitizer.toSnakeCase(endpoint.name);
      imports.add('import \'calls/$name.dart\' as ${name}_call;');
    }

    for (final event in abi.events) {
      final name = nameSanitizer.toSnakeCase(event.identifier);
      imports.add(
        'import \'events/polling_events/$name.dart\' as ${name}_polling_stream;',
      );
      imports.add(
        'import \'events/websocket_events/$name.dart\' as ${name}_websocket_stream;',
      );
    }

    if (abi.events.isNotEmpty) {
      imports.add(
        'import \'events/multi_event_websocket_stream.dart\' as multi_event_websocket_stream;',
      );
    }

    if (abi.events.length > 1) {
      imports.add(
        'import \'events/multi_event_polling_stream.dart\' as multi_event_polling_stream;',
      );
    }

    _writeSortedImports(buffer, imports);
    buffer.writeln();

    buffer.writeln('/// Smart contract controller.');
    buffer.writeln('///');
    buffer.writeln('/// #### Example');
    buffer.writeln('/// ```dart');
    if (useLogger) {
      buffer.writeln('/// final logger = ConsoleLogger(');
      buffer.writeln('///   minLevel: LogLevel.debug,');
      buffer.writeln('///   includeTimestamp: true,');
      buffer.writeln('///   prettyPrintContext: true,');
      buffer.writeln('///   showBorders: true,');
      buffer.writeln('///   useColors: true,');
      buffer.writeln('/// );');
      buffer.writeln('/// final controller = $controllerClassName(');
      buffer.writeln('///   contractAddress: \'erd1...\',');
      buffer.writeln('///   networkProvider: provider,');
      buffer.writeln('///   logger: logger,');
      buffer.writeln('/// );');
    } else {
      buffer.writeln('/// final controller = $controllerClassName(');
      buffer.writeln('///   contractAddress: \'erd1...\',');
      buffer.writeln('///   networkProvider: provider,');
      buffer.writeln('/// );');
    }
    buffer.writeln('/// ```');
    buffer.writeln('class $controllerClassName {');
    buffer.writeln('  final SmartContractController _controller;');
    if (useLogger) {
      buffer.writeln('  /// Logger surface for this controller.');
      buffer.writeln('  ///');
      buffer.writeln(
        '  /// Typed as the abstract [Logger] interface so any subtype passed',
      );
      buffer.writeln(
        '  /// to [SmartContractController] flows through unchanged.',
      );
      buffer.writeln('  final Logger logger;');
    }
    buffer.writeln();
    buffer.writeln('  /// Creates controller with contract address.');
    buffer.writeln('  $controllerClassName({');
    buffer.writeln('    required dynamic contractAddress,');
    buffer.writeln('    required NetworkProvider networkProvider,');
    if (useLogger) {
      buffer.writeln('    Logger? logger,');
    }
    buffer.writeln('  }) : ');
    if (useLogger) {
      buffer.writeln('    logger = logger ?? ConsoleLogger(');
      buffer.writeln('      minLevel: LogLevel.debug,');
      buffer.writeln('      includeTimestamp: true,');
      buffer.writeln('      prettyPrintContext: true,');
      buffer.writeln('      showBorders: true,');
      buffer.writeln('      useColors: true,');
      buffer.writeln('    ),');
    }
    buffer.writeln('    _controller = SmartContractController(');
    buffer.writeln('    abi: abi,');
    buffer.writeln('    contractAddress: contractAddress is String');
    buffer.writeln(
      '        ? SmartContractAddress.fromBech32(contractAddress)',
    );
    buffer.writeln('        : contractAddress as Address,');
    buffer.writeln('    networkProvider: networkProvider,');
    if (useLogger) {
      buffer.writeln('    logger: logger ?? ConsoleLogger(');
      buffer.writeln('      minLevel: LogLevel.debug,');
      buffer.writeln('      includeTimestamp: true,');
      buffer.writeln('      prettyPrintContext: true,');
      buffer.writeln('      showBorders: true,');
      buffer.writeln('      useColors: true,');
      buffer.writeln('    ),');
    }
    buffer.writeln('  );');
    buffer.writeln();
    buffer.writeln('  $controllerClassName.withController(this._controller)');
    if (useLogger) {
      buffer.writeln(
        '    : logger = _controller.logger ?? ConsoleLogger(minLevel: LogLevel.debug);',
      );
    } else {
      buffer.writeln('    ;');
    }
    buffer.writeln();
    buffer.writeln('  SmartContractController get controller => _controller;');
    buffer.writeln();
    buffer.writeln('  /// Network provider for queries and transactions.');
    buffer.writeln(
      '  NetworkProvider get networkProvider => _controller.networkProvider;',
    );
    buffer.writeln();
    buffer.writeln('  /// Factory for creating unsigned transactions.');
    buffer.writeln(
      '  SmartContractCallFactory get factory => SmartContractCallFactory(',
    );
    buffer.writeln('    contractAddress: _controller.contractAddress,');
    buffer.writeln('    abi: _controller.abi,');
    buffer.writeln('    chainId: _controller.networkProvider.chainId,');
    buffer.writeln('    logger: _controller.logger,');
    buffer.writeln('  );');
    buffer.writeln();

    if (abi.endpoints.viewEndpoints.isNotEmpty) {
      for (final endpoint in abi.endpoints.viewEndpoints) {
        final methodName = nameSanitizer.sanitizeParamName(endpoint.name);
        final snakeCaseName = nameSanitizer.toSnakeCase(endpoint.name);

        final hasOutput = endpoint.outputs.isNotEmpty;
        final returnType = hasOutput
            ? 'Future<${_getReturnType(endpoint.outputs.toList())}>'
            : 'Future<void>';

        buffer.write('  $returnType $methodName(');
        final params = <String>[];
        for (final input in endpoint.inputs) {
          final paramName = nameSanitizer.sanitizeParamName(input.name);
          final dartType = typeMapper.mapToDartType(input.type);
          params.add('$dartType $paramName');
        }
        if (params.isNotEmpty) {
          buffer.writeln();
          for (int i = 0; i < params.length; i++) {
            buffer.write('    ${params[i]}');
            if (i < params.length - 1) buffer.writeln(',');
          }
          buffer.writeln();
          buffer.write('  ');
        }
        buffer.write(') => ${snakeCaseName}_query.$methodName(_controller');
        if (params.isNotEmpty) {
          buffer.write(', ${params.map((p) => p.split(' ').last).join(', ')}');
        }
        buffer.writeln(');');
        buffer.writeln();
      }
    }

    if (abi.endpoints.mutableEndpoints.isNotEmpty) {
      for (final endpoint in abi.endpoints.mutableEndpoints) {
        final methodName = nameSanitizer.sanitizeParamName(endpoint.name);
        final snakeCaseName = nameSanitizer.toSnakeCase(endpoint.name);

        buffer.write('  Future<Transaction> $methodName(');
        buffer.writeln();
        buffer.writeln('    IAccount sender,');
        buffer.writeln('    Nonce nonce,');

        final paramNames = <String>[];
        for (final input in endpoint.inputs) {
          final paramName = nameSanitizer.sanitizeParamName(input.name);
          paramNames.add(paramName);
          final dartType = typeMapper.mapToDartType(input.type);
          buffer.writeln('    $dartType $paramName,');
        }

        buffer.writeln('    {');
        if (endpoint.payableInTokens.isNotEmpty) {
          buffer.writeln(
            '      List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],',
          );
        }
        if (!useAutoGas) {
          buffer.writeln('      required GasLimit gasLimit,');
        }
        buffer.writeln('      Address? relayer,');
        buffer.writeln('      Address? guardian,');
        buffer.writeln('      Balance? value,');
        buffer.writeln('    }');
        buffer.write(
          '  ) => ${snakeCaseName}_call.$methodName(_controller, sender, nonce',
        );
        for (final paramName in paramNames) {
          buffer.write(', $paramName');
        }
        if (endpoint.payableInTokens.isNotEmpty) {
          buffer.write(', tokenTransfers: tokenTransfers');
        }
        if (useAutoGas) {
          buffer.writeln(
            ', relayer: relayer, guardian: guardian, value: value);',
          );
        } else {
          buffer.writeln(
            ', gasLimit: gasLimit, relayer: relayer, guardian: guardian, value: value);',
          );
        }
        buffer.writeln();
      }

      for (final endpoint in abi.endpoints.mutableEndpoints) {
        final methodName = nameSanitizer.sanitizeParamName(endpoint.name);
        final snakeCaseName = nameSanitizer.toSnakeCase(endpoint.name);

        if (useAutoGas) {
          buffer.write('  Future<Transaction> ${methodName}Unsigned(');
        } else {
          buffer.write('  Transaction ${methodName}Unsigned(');
        }
        buffer.writeln();
        buffer.writeln('    Address sender,');
        buffer.writeln('    Nonce nonce,');

        final paramNames = <String>[];
        for (final input in endpoint.inputs) {
          final paramName = nameSanitizer.sanitizeParamName(input.name);
          paramNames.add(paramName);
          final dartType = typeMapper.mapToDartType(input.type);
          buffer.writeln('    $dartType $paramName,');
        }

        buffer.writeln('    {');
        if (endpoint.payableInTokens.isNotEmpty) {
          buffer.writeln(
            '      List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],',
          );
        }
        if (!useAutoGas) {
          buffer.writeln('      required GasLimit gasLimit,');
        }
        buffer.writeln('      Balance? value,');
        buffer.writeln('    }');
        if (useAutoGas) {
          buffer.write(
            '  ) => ${snakeCaseName}_call.${methodName}Unsigned(factory, networkProvider, sender, nonce',
          );
        } else {
          buffer.write(
            '  ) => ${snakeCaseName}_call.${methodName}Unsigned(factory, sender, nonce',
          );
        }
        for (final paramName in paramNames) {
          buffer.write(', $paramName');
        }
        if (endpoint.payableInTokens.isNotEmpty) {
          buffer.write(', tokenTransfers: tokenTransfers');
        }
        if (useAutoGas) {
          buffer.writeln(', value: value);');
        } else {
          buffer.writeln(', gasLimit: gasLimit, value: value);');
        }
        buffer.writeln();
      }
    }

    if (abi.events.isNotEmpty) {
      buffer.writeln(
        '  late final $eventsClassName events = $eventsClassName(_controller);',
      );
      buffer.writeln();
    }

    buffer.writeln('}');

    if (abi.events.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('/// Event streaming accessor');
      buffer.writeln('class $eventsClassName {');
      buffer.writeln('  const $eventsClassName(this._controller);');
      buffer.writeln();
      buffer.writeln('  final SmartContractController _controller;');
      buffer.writeln();

      buffer.writeln(
        '  /// Create a unified WebSocket stream for multiple events.',
      );
      buffer.writeln('  ///');
      buffer.writeln(
        '  /// More efficient than individual streams - uses single WebSocket connection.',
      );
      buffer.writeln('  ///');
      buffer.writeln('  /// Example:');
      buffer.writeln('  /// ```dart');
      buffer.writeln('  /// final stream = controller.events.websocketStream(');
      buffer.writeln(
        '  ///   websocketUrl: \'wss://kepler-api.projectx.mx/mainnet/events\',',
      );
      buffer.writeln('  ///   headers: {\'Api-Key\': \'your-key\'},');
      buffer.writeln('  /// );');
      buffer.writeln('  /// await stream.connect();');
      buffer.writeln('  ///');
      buffer.writeln('  /// // Listen to specific events');
      if (abi.events.isNotEmpty) {
        final firstEvent = abi.events.first;
        final firstEventName = nameSanitizer.toCamelCase(firstEvent.identifier);
        buffer.writeln(
          '  /// stream.$firstEventName.listen((event) => print(event));',
        );
      }
      buffer.writeln('  ///');
      buffer.writeln('  /// // Or listen to all events');
      buffer.writeln('  /// stream.all.listen((event) { ... });');
      buffer.writeln('  /// ```');
      buffer.writeln(
        '  multi_event_websocket_stream.MultiEventWebSocketStream websocketStream({',
      );
      buffer.writeln('    required String websocketUrl,');
      buffer.writeln('    Map<String, String> headers = const {},');
      buffer.writeln('    bool autoReconnect = true,');
      buffer.writeln(
        '    Duration reconnectDelay = const Duration(seconds: 1),',
      );
      buffer.writeln(
        '    Duration connectionTimeout = const Duration(seconds: 5),',
      );
      buffer.writeln(
        '    Duration pingInterval = const Duration(seconds: 10),',
      );
      buffer.writeln('  }) {');
      buffer.writeln(
        '    return multi_event_websocket_stream.MultiEventWebSocketStream(',
      );
      buffer.writeln('      controller: _controller,');
      buffer.writeln('      websocketUrl: websocketUrl,');
      buffer.writeln('      headers: headers,');
      buffer.writeln('      autoReconnect: autoReconnect,');
      buffer.writeln('      reconnectDelay: reconnectDelay,');
      buffer.writeln('      connectionTimeout: connectionTimeout,');
      buffer.writeln('      pingInterval: pingInterval,');
      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln();

      if (abi.events.length > 1) {
        buffer.writeln(
          '  /// Create a unified polling stream for multiple events.',
        );
        buffer.writeln('  ///');
        buffer.writeln(
          '  /// More efficient than individual streams - uses single API call.',
        );
        buffer.writeln('  ///');
        buffer.writeln('  /// Example:');
        buffer.writeln('  /// ```dart');
        buffer.writeln('  /// final stream = controller.events.pollingStream(');
        buffer.writeln('  ///   pollingInterval: Duration(seconds: 10),');
        buffer.writeln('  /// );');
        buffer.writeln('  ///');
        buffer.writeln('  /// // Listen to specific events');
        if (abi.events.isNotEmpty) {
          final firstEvent = abi.events.first;
          final firstEventName = nameSanitizer.toCamelCase(
            firstEvent.identifier,
          );
          buffer.writeln(
            '  /// stream.$firstEventName.listen((event) => print(event));',
          );
        }
        buffer.writeln('  ///');
        buffer.writeln('  /// // Or listen to all events');
        buffer.writeln('  /// stream.all.listen((event) { ... });');
        buffer.writeln('  /// ```');
        buffer.writeln(
          '  multi_event_polling_stream.MultiEventPollingStream pollingStream({',
        );
        buffer.writeln(
          '    Duration pollingInterval = const Duration(seconds: 10),',
        );
        buffer.writeln('    String? startFrom,');
        buffer.writeln('  }) {');
        buffer.writeln(
          '    return multi_event_polling_stream.MultiEventPollingStream(',
        );
        buffer.writeln('      controller: _controller,');
        buffer.writeln('      pollingInterval: pollingInterval,');
        buffer.writeln('      startFrom: startFrom,');
        buffer.writeln('    );');
        buffer.writeln('  }');
        buffer.writeln();
      }

      for (final event in abi.events) {
        final methodName = nameSanitizer.toCamelCase(event.identifier);
        final snakeCaseName = nameSanitizer.toSnakeCase(event.identifier);
        final pascalName = nameSanitizer.toPascalCase(event.identifier);
        final pollingClassName = '${pascalName}PollingStream';
        final webSocketClassName = '${pascalName}WebSocketStream';

        buffer.writeln('  ${snakeCaseName}_polling_stream.$pollingClassName');
        buffer.writeln('      ${methodName}Polling() =>');
        buffer.writeln(
          '    ${snakeCaseName}_polling_stream.$pollingClassName(_controller);',
        );
        buffer.writeln();

        buffer.writeln(
          '  ${snakeCaseName}_websocket_stream.$webSocketClassName ${methodName}WebSocket({',
        );
        buffer.writeln('    required String websocketUrl,');
        buffer.writeln('    Map<String, String> headers = const {},');
        buffer.writeln('    bool autoReconnect = true,');
        buffer.writeln(
          '    Duration reconnectDelay = const Duration(seconds: 5),',
        );
        buffer.writeln(
          '    Duration connectionTimeout = const Duration(seconds: 15),',
        );
        buffer.writeln(
          '    Duration pingInterval = const Duration(seconds: 30),',
        );
        buffer.writeln('  }) {');
        buffer.writeln(
          '    return ${snakeCaseName}_websocket_stream.$webSocketClassName(',
        );
        buffer.writeln('      controller: _controller,');
        buffer.writeln('      websocketUrl: websocketUrl,');
        buffer.writeln('      headers: headers,');
        buffer.writeln('      autoReconnect: autoReconnect,');
        buffer.writeln('      reconnectDelay: reconnectDelay,');
        buffer.writeln('      connectionTimeout: connectionTimeout,');
        buffer.writeln('      pingInterval: pingInterval,');
        buffer.writeln('    );');
        buffer.writeln('  }');
        buffer.writeln();
      }

      buffer.writeln('}');
    }

    return [FileOutput(path: 'controller.dart', content: buffer.toString())];
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

  Set<String> _collectModelTypes() {
    final types = <String>{};
    for (final endpoint in abi.endpoints.viewEndpoints) {
      for (final input in endpoint.inputs) {
        _extractCustomTypes(input.type, types);
      }
      for (final output in endpoint.outputs) {
        _extractCustomTypes(output.type, types);
      }
    }

    for (final endpoint in abi.endpoints.mutableEndpoints) {
      for (final input in endpoint.inputs) {
        _extractCustomTypes(input.type, types);
      }
    }

    return types;
  }

  void _extractCustomTypes(AbiType type, Set<String> types) {
    if (type is StructType) {
      types.add(type.name);
    } else if (type is EnumType) {
      types.add(type.name);
    } else if (type is ExplicitEnumType) {
      types.add(type.name);
    } else if (type is ListType) {
      _extractCustomTypes(type.elementType, types);
    } else if (type is ArrayType) {
      _extractCustomTypes(type.elementType, types);
    } else if (type is OptionType) {
      _extractCustomTypes(type.innerType, types);
    } else if (type is OptionalType) {
      _extractCustomTypes(type.innerType, types);
    } else if (type is TupleType) {
      for (final field in type.fieldDefinitions) {
        _extractCustomTypes(field.type, types);
      }
    } else if (type is VariadicType) {
      _extractCustomTypes(type.itemType, types);
    } else if (type is CompositeType) {
      for (final field in type.fieldTypes) {
        _extractCustomTypes(field, types);
      }
    } else if (type is MultiValueType) {
      for (final t in type.types) {
        _extractCustomTypes(t, types);
      }
    }
  }

  bool _needsTypedData() {
    for (final endpoint in abi.endpoints.viewEndpoints) {
      for (final param in endpoint.inputs) {
        if (typeMapper.needsTypedData(param.type)) return true;
      }
      for (final param in endpoint.outputs) {
        if (typeMapper.needsTypedData(param.type)) return true;
      }
    }
    for (final endpoint in abi.endpoints.mutableEndpoints) {
      for (final param in endpoint.inputs) {
        if (typeMapper.needsTypedData(param.type)) return true;
      }
      for (final param in endpoint.outputs) {
        if (typeMapper.needsTypedData(param.type)) return true;
      }
    }
    return false;
  }

  /// Sorts imports into `dart:` / `package:` / relative groups and emits a
  /// `hide` clause on `package:abidock_mvx/abidock_mvx.dart` for any
  /// non-aliased local import whose filename collides with a public symbol
  /// exported by the package. Aliased imports (`as X`) are skipped from
  /// conflict detection because the alias prefix already disambiguates.
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

    final localSymbols = <String>{};
    for (final import in relativeImports) {
      if (import.contains(' as ')) continue;
      final match = RegExp(r"import '([^']+)';").firstMatch(import);
      if (match == null) continue;
      final filename = match.group(1)!.split('/').last.replaceAll('.dart', '');
      localSymbols.add(nameSanitizer.toPascalCase(filename));
    }
    final conflicts = localSymbols.intersection(knownPackageSymbols);

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
      if (conflicts.isNotEmpty &&
          import.contains("'package:abidock_mvx/abidock_mvx.dart'")) {
        final hideList = conflicts.toList()..sort();
        buffer.writeln(
          "import 'package:abidock_mvx/abidock_mvx.dart' "
          "hide ${hideList.join(', ')};",
        );
      } else {
        buffer.writeln(import);
      }
    }
    if (packageImports.isNotEmpty && relativeImports.isNotEmpty) {
      buffer.writeln();
    }

    for (final import in relativeImports) {
      buffer.writeln(import);
    }
  }
}
