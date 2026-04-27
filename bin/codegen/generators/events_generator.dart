import 'package:abidock_mvx/src/abi/abi.dart';
import '../core/import_manager.dart';
import '../core/name_sanitizer.dart';
import '../core/type_mapper.dart';
import '../models/file_output.dart';
import 'generator_base.dart';

final class EventsGenerator extends GeneratorBase {
  EventsGenerator({
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
      files.add(_generateControllerStream(event));
      files.add(_generateWebSocketStream(event));
    }

    if (abi.events.isNotEmpty) {
      files.add(_generateMultiEventWebSocketStream(abi.events.toList()));
    }

    if (abi.events.length > 1) {
      files.add(_generateMultiEventPollingStream(abi.events.toList()));
    }

    return files;
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

  FileOutput _generateControllerStream(EventDefinition event) {
    final className =
        '${nameSanitizer.toPascalCase(event.identifier)}PollingStream';
    final fileName = nameSanitizer.toSnakeCase(event.identifier);
    final eventClassName = _normalizeEventClassName(event.identifier);

    final importManager = ImportManager();

    importManager.addDartImport('dart:async');
    importManager.addPackageImport('package:abidock_mvx/abidock_mvx.dart');

    importManager.addRelativeImport(
      '../../models/${_normalizeEventFileName(event.identifier)}.dart',
    );

    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());
    buffer.write(importManager.generate());
    if (importManager.generate().isNotEmpty) {
      buffer.writeln();
    }

    buffer.writeln('/// HTTP polling stream for ${event.identifier} events.');

    if (event.documentation != null && event.documentation!.isNotEmpty) {
      buffer.writeln('///');
      for (final line in event.documentation!.split('\n')) {
        if (line.trim().isEmpty) {
          buffer.writeln('///');
        } else {
          buffer.writeln('/// $line');
        }
      }
    }

    buffer.writeln('///');

    if (event.inputs.isNotEmpty) {
      buffer.writeln('/// #### Event Fields:');
      for (final input in event.inputs) {
        final fieldName = nameSanitizer.sanitizeFieldName(input.name);
        final abiType = typeMapper.getAbiTypeStringForDocs(input.type);
        final indexed = input.indexed ? ' (indexed)' : '';
        buffer.writeln('/// - `$fieldName`: $abiType$indexed');
      }
    }

    buffer.writeln('final class $className {');
    buffer.writeln('  const $className(this.controller);');
    buffer.writeln();
    buffer.writeln('  final SmartContractController controller;');
    buffer.writeln();
    buffer.writeln('  /// Starts polling for ${event.identifier} events.');
    buffer.writeln('  Stream<$eventClassName> call({');
    buffer.writeln(
      '    Duration pollingInterval = const Duration(seconds: 10),',
    );
    buffer.writeln('    String? startFrom,');
    buffer.writeln('  }) {');
    final eventStructName = event.identifier.endsWith('_event')
        ? event.identifier
        : '${event.identifier}_event';

    buffer.writeln('    return controller.streamEvents(');
    buffer.writeln('      eventIdentifier: \'${event.identifier}\',');
    buffer.writeln('      pollingInterval: pollingInterval,');
    buffer.writeln('      startFrom: startFrom,');
    buffer.writeln('    ).map((parsedEvent) {');
    buffer.writeln(
      '      final eventStruct = parsedEvent.getValueByName(\'$eventStructName\');',
    );
    buffer.writeln('      if (eventStruct == null) {');
    buffer.writeln(
      '        throw StateError(\'Event struct not found in parsed event\');',
    );
    buffer.writeln('      }');
    buffer.writeln('      return $eventClassName.fromAbi(eventStruct);');
    buffer.writeln('    });');
    buffer.writeln('  }');
    buffer.writeln('}');

    return FileOutput(
      path: 'events/polling_events/$fileName.dart',
      content: buffer.toString(),
    );
  }

  FileOutput _generateWebSocketStream(EventDefinition event) {
    final className =
        '${nameSanitizer.toPascalCase(event.identifier)}WebSocketStream';
    final fileName = nameSanitizer.toSnakeCase(event.identifier);
    final eventClassName = _normalizeEventClassName(event.identifier);

    final importManager = ImportManager();

    importManager.addDartImport('dart:async');
    importManager.addPackageImport('package:abidock_mvx/abidock_mvx.dart');

    importManager.addRelativeImport(
      '../../models/${_normalizeEventFileName(event.identifier)}.dart',
    );

    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());
    buffer.write(importManager.generate());
    if (importManager.generate().isNotEmpty) {
      buffer.writeln();
    }

    buffer.writeln(
      '/// Real-time WebSocket stream for ${event.identifier} events.',
    );

    if (event.documentation != null && event.documentation!.isNotEmpty) {
      buffer.writeln('///');
      for (final line in event.documentation!.split('\n')) {
        if (line.trim().isEmpty) {
          buffer.writeln('///');
        } else {
          buffer.writeln('/// $line');
        }
      }
    }

    buffer.writeln('///');

    if (event.inputs.isNotEmpty) {
      buffer.writeln('/// #### Event Fields:');
      for (final input in event.inputs) {
        final fieldName = nameSanitizer.sanitizeFieldName(input.name);
        final abiType = typeMapper.getAbiTypeStringForDocs(input.type);
        final indexed = input.indexed ? ' (indexed)' : '';
        buffer.writeln('/// - `$fieldName`: $abiType$indexed');
      }
    }

    buffer.writeln('final class $className {');
    buffer.writeln('  $className({');
    buffer.writeln('    required SmartContractController controller,');
    buffer.writeln('    required String websocketUrl,');
    buffer.writeln('    Map<String, String>? headers,');
    buffer.writeln('    bool autoReconnect = true,');
    buffer.writeln(
      '    Duration reconnectDelay = const Duration(milliseconds: 300),',
    );
    buffer.writeln(
      '    Duration connectionTimeout = const Duration(seconds: 5),',
    );
    buffer.writeln('    Duration pingInterval = const Duration(seconds: 10),');
    buffer.writeln('  }) : _controller = controller {');
    buffer.writeln('    _config = WebSocketEventStreamConfig.byIdentifiers(');
    buffer.writeln('      websocketUrl: websocketUrl,');
    buffer.writeln('      identifiers: [\'${event.identifier}\'],');
    buffer.writeln('      contractAddress: _controller.contractAddress,');
    buffer.writeln('      abi: _controller.abi,');
    buffer.writeln('      autoReconnect: autoReconnect,');
    buffer.writeln('      reconnectDelay: reconnectDelay,');
    buffer.writeln('      connectionTimeout: connectionTimeout,');
    buffer.writeln('      pingInterval: pingInterval,');
    buffer.writeln('      logger: _controller.logger,');
    buffer.writeln('    );');
    buffer.writeln();
    buffer.writeln('    _stream = WebSocketEventStream(_config);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  final SmartContractController _controller;');
    buffer.writeln('  late final WebSocketEventStreamConfig _config;');
    buffer.writeln('  late final WebSocketEventStream _stream;');
    buffer.writeln();
    buffer.writeln(
      '  /// Stream of typed $eventClassName events filtered server-side.',
    );
    buffer.writeln(
      '  /// Converts WebSocket payloads into strongly typed objects.',
    );
    buffer.writeln('  Stream<$eventClassName> get events =>');
    buffer.writeln('      EventConverter.filterByIdentifier<$eventClassName>(');
    buffer.writeln('        _stream.events,');
    buffer.writeln('        \'${event.identifier}\',');
    buffer.writeln(
      '        (parsed) => EventConverter.convertEvent<$eventClassName>(',
    );
    buffer.writeln('          parsed,');
    buffer.writeln('          $eventClassName.fromAbi,');
    buffer.writeln('          $eventClassName.type,');
    buffer.writeln('        ),');
    buffer.writeln('      );');
    buffer.writeln();
    buffer.writeln(
      '  Stream<WebSocketStatusChange> get statusChanges => _stream.statusChanges;',
    );
    buffer.writeln();
    buffer.writeln(
      '  Stream<WebSocketEventError> get errors => _stream.errors;',
    );
    buffer.writeln();
    buffer.writeln('  Future<void> connect() => _stream.connect();');
    buffer.writeln();
    buffer.writeln('  Future<void> disconnect() => _stream.disconnect();');
    buffer.writeln();
    buffer.writeln('  Future<void> dispose() => _stream.dispose();');
    buffer.writeln();
    buffer.writeln('  WebSocketStatus get status => _stream.status;');
    buffer.writeln();
    buffer.writeln('  void pause() => _stream.pause();');
    buffer.writeln();
    buffer.writeln('  void resume() => _stream.resume();');
    buffer.writeln('}');

    return FileOutput(
      path: 'events/websocket_events/$fileName.dart',
      content: buffer.toString(),
    );
  }

  FileOutput _generateMultiEventWebSocketStream(List<EventDefinition> events) {
    const className = 'MultiEventWebSocketStream';
    const fileName = 'multi_event_websocket_stream';

    final importManager = ImportManager();

    importManager.addDartImport('dart:async');
    importManager.addPackageImport('package:abidock_mvx/abidock_mvx.dart');

    for (final event in events) {
      importManager.addRelativeImport(
        '../models/${_normalizeEventFileName(event.identifier)}.dart',
      );
    }

    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());
    buffer.write(importManager.generate());
    if (importManager.generate().isNotEmpty) {
      buffer.writeln();
    }

    buffer.writeln('/// Combined WebSocket stream that fans out every event.');
    buffer.writeln(
      '/// Use typed getters, `all`, or `only` to consume events.',
    );

    buffer.writeln('final class $className {');

    buffer.writeln('  $className({');
    buffer.writeln('    required SmartContractController controller,');
    buffer.writeln('    required String websocketUrl,');
    buffer.writeln('    Map<String, String> headers = const {},');
    buffer.writeln('    bool autoReconnect = true,');
    buffer.writeln(
      '    Duration reconnectDelay = const Duration(milliseconds: 300),',
    );
    buffer.writeln(
      '    Duration connectionTimeout = const Duration(seconds: 5),',
    );
    buffer.writeln('    Duration pingInterval = const Duration(seconds: 10),');
    buffer.writeln('  }) : _controller = controller {');
    buffer.writeln();
    final identifiersList = events.map((e) => "'${e.identifier}'").join(', ');
    buffer.writeln('    _config = WebSocketEventStreamConfig.byIdentifiers(');
    buffer.writeln('      websocketUrl: websocketUrl,');
    buffer.writeln('      identifiers: [$identifiersList],');
    buffer.writeln('      contractAddress: _controller.contractAddress,');
    buffer.writeln('      abi: _controller.abi,');
    buffer.writeln('      headers: headers,');
    buffer.writeln('      logger: _controller.logger,');
    buffer.writeln('      autoReconnect: autoReconnect,');
    buffer.writeln('      reconnectDelay: reconnectDelay,');
    buffer.writeln('      connectionTimeout: connectionTimeout,');
    buffer.writeln('      pingInterval: pingInterval,');
    buffer.writeln('    );');
    buffer.writeln();
    buffer.writeln('    _stream = WebSocketEventStream(_config);');
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  final SmartContractController _controller;');
    buffer.writeln('  late final WebSocketEventStreamConfig _config;');
    buffer.writeln('  late final WebSocketEventStream _stream;');
    buffer.writeln();

    for (final event in events) {
      final eventClassName = _normalizeEventClassName(event.identifier);
      final streamName = nameSanitizer.toCamelCase(event.identifier);
      String normalizedIdentifier = event.identifier;
      if (normalizedIdentifier.endsWith('_event')) {
        normalizedIdentifier = normalizedIdentifier.substring(
          0,
          normalizedIdentifier.length - 6,
        );
      }

      buffer.writeln('  /// Stream of ${event.identifier} events.');
      buffer.writeln('  Stream<$eventClassName> get $streamName =>');
      buffer.writeln(
        '      EventConverter.filterByIdentifier<$eventClassName>(',
      );
      buffer.writeln('        _stream.events,');
      buffer.writeln('        \'${event.identifier}\',');
      buffer.writeln(
        '        (parsed) => EventConverter.convertEvent<$eventClassName>(',
      );
      buffer.writeln('          parsed,');
      buffer.writeln('          $eventClassName.fromAbi,');
      buffer.writeln('          $eventClassName.type,');
      buffer.writeln('        ),');
      buffer.writeln('      );');
      buffer.writeln();
    }
    buffer.writeln('  /// Stream of all events (any type).');
    buffer.writeln('  ///');
    buffer.writeln('  /// Use type checks to handle different events:');
    buffer.writeln('  /// ```dart');
    buffer.writeln('  /// stream.all.listen((event) {');
    if (events.isNotEmpty) {
      final eventClass1 =
          '${nameSanitizer.toPascalCase(events.first.identifier)}Event';
      buffer.writeln('  ///   if (event is $eventClass1) { ... }');
    }
    buffer.writeln('  /// });');
    buffer.writeln('  /// ```');
    buffer.writeln('  Stream<dynamic> get all =>');
    buffer.writeln('      _stream.events');
    buffer.writeln('          .where((r) => r.parsedEvent != null)');
    buffer.writeln('          .map((r) {');
    buffer.writeln(
      '        final identifier = r.parsedEvent!.definition.identifier;',
    );
    buffer.writeln('        switch (identifier) {');

    for (final event in events) {
      final eventClassName = _normalizeEventClassName(event.identifier);
      buffer.writeln('          case \'${event.identifier}\':');
      buffer.writeln(
        '            return EventConverter.convertEvent<$eventClassName>(',
      );
      buffer.writeln('              r.parsedEvent!,');
      buffer.writeln('              $eventClassName.fromAbi,');
      buffer.writeln('              $eventClassName.type,');
      buffer.writeln('            );');
    }

    buffer.writeln('          default:');
    buffer.writeln('            return null;');
    buffer.writeln('        }');
    buffer.writeln('      })');
    buffer.writeln('      .where((event) => event != null)');
    buffer.writeln('      .cast<dynamic>();');
    buffer.writeln();

    buffer.writeln('  /// Filter to only specified event types.');
    buffer.writeln('  ///');
    buffer.writeln('  /// Example:');
    buffer.writeln('  /// ```dart');
    if (events.length >= 2) {
      final eventClass1 =
          '${nameSanitizer.toPascalCase(events.first.identifier)}Event';
      final eventClass2 =
          '${nameSanitizer.toPascalCase(events[1].identifier)}Event';
      buffer.writeln(
        '  /// stream.only([$eventClass1, $eventClass2]).listen((event) {',
      );
      buffer.writeln('  ///   // Only receive these event types');
      buffer.writeln('  /// });');
    }
    buffer.writeln('  /// ```');
    buffer.writeln('  Stream<dynamic> only(List<Type> eventTypes) {');
    buffer.writeln(
      '    return all.where((event) => eventTypes.contains(event.runtimeType));',
    );
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  /// Stream of connection status changes.');
    buffer.writeln(
      '  Stream<WebSocketStatusChange> get statusChanges => _stream.statusChanges;',
    );
    buffer.writeln();
    buffer.writeln('  /// Stream of WebSocket errors.');
    buffer.writeln(
      '  Stream<WebSocketEventError> get errors => _stream.errors;',
    );
    buffer.writeln();
    buffer.writeln('  /// Connects to WebSocket server.');
    buffer.writeln('  Future<void> connect() => _stream.connect();');
    buffer.writeln();
    buffer.writeln('  /// Disconnects from WebSocket server.');
    buffer.writeln('  Future<void> disconnect() => _stream.disconnect();');
    buffer.writeln();
    buffer.writeln('  /// Dispose resources.');
    buffer.writeln('  Future<void> dispose() => _stream.dispose();');
    buffer.writeln();
    buffer.writeln('  /// Current connection status.');
    buffer.writeln('  WebSocketStatus get status => _stream.status;');
    buffer.writeln();
    buffer.writeln('  /// Pause event streaming.');
    buffer.writeln('  void pause() => _stream.pause();');
    buffer.writeln();
    buffer.writeln('  /// Resume event streaming.');
    buffer.writeln('  void resume() => _stream.resume();');
    buffer.writeln('}');

    return FileOutput(
      path: 'events/$fileName.dart',
      content: buffer.toString(),
    );
  }

  FileOutput _generateMultiEventPollingStream(List<EventDefinition> events) {
    final importManager = ImportManager();

    importManager.addDartImport('dart:async');
    importManager.addPackageImport('package:abidock_mvx/abidock_mvx.dart');

    for (final event in events) {
      importManager.addRelativeImport(
        '../models/${_normalizeEventFileName(event.identifier)}.dart',
      );
    }

    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());
    buffer.write(importManager.generate());
    if (importManager.generate().isNotEmpty) {
      buffer.writeln();
    }

    buffer.writeln('/// HTTP polling stream that fans out every event.');
    buffer.writeln('/// Runs one polling loop and exposes typed getters.');
    buffer.writeln('final class MultiEventPollingStream {');
    buffer.writeln('  MultiEventPollingStream({');
    buffer.writeln('    required this.controller,');
    buffer.writeln(
      '    Duration pollingInterval = const Duration(seconds: 10),',
    );
    buffer.writeln('    String? startFrom,');
    buffer.writeln('  }) {');
    buffer.writeln('    _baseStream = controller.streamAllEvents(');
    buffer.writeln('      pollingInterval: pollingInterval,');
    buffer.writeln('      startFrom: startFrom,');
    buffer.writeln('    ).asBroadcastStream(onCancel: (sub) => sub.cancel());');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  final SmartContractController controller;');
    buffer.writeln('  late final Stream<ParsedEvent> _baseStream;');
    buffer.writeln();

    for (final event in events) {
      final eventName = nameSanitizer.toCamelCase(event.identifier);
      final eventClass = _normalizeEventClassName(event.identifier);
      final pollingStructName = event.identifier.endsWith('_event')
          ? event.identifier
          : '${event.identifier}_event';

      buffer.writeln('  /// Stream of ${event.identifier} events.');
      buffer.writeln('  Stream<$eventClass> get $eventName => _baseStream');
      buffer.writeln(
        '      .where((event) => event.definition.identifier == \'${event.identifier}\')',
      );
      buffer.writeln('      .map((parsedEvent) {');
      buffer.writeln(
        '        final eventStruct = parsedEvent.getValueByName(\'$pollingStructName\');',
      );
      buffer.writeln('        if (eventStruct == null) {');
      buffer.writeln(
        '          throw StateError(\'Event struct not found in parsed event\');',
      );
      buffer.writeln('        }');
      buffer.writeln('        return $eventClass.fromAbi(eventStruct);');
      buffer.writeln('      });');
      buffer.writeln();
    }

    buffer.writeln('  /// Stream of all event types as dynamic objects.');
    buffer.writeln('  ///');
    buffer.writeln('  /// Use type checking to handle different event types:');
    buffer.writeln('  /// ```dart');
    buffer.writeln('  /// stream.all.listen((event) {');

    for (int i = 0; i < events.length && i < 3; i++) {
      final event = events[i];
      final eventClass = _normalizeEventClassName(event.identifier);
      final prefix = i == 0 ? 'if' : 'else if';
      buffer.writeln('  ///   $prefix (event is $eventClass) {');
      buffer.writeln('  ///     // Handle ${event.identifier}');
      buffer.writeln('  ///   }');
    }

    buffer.writeln('  /// });');
    buffer.writeln('  /// ```');
    buffer.writeln('  Stream<dynamic> get all {');
    buffer.writeln('    return _baseStream.asyncMap((parsedEvent) async {');
    buffer.writeln(
      '      final identifier = parsedEvent.definition.identifier;',
    );
    buffer.writeln('      switch (identifier) {');

    for (final event in events) {
      final eventClass = _normalizeEventClassName(event.identifier);
      final pollingStructName = event.identifier.endsWith('_event')
          ? event.identifier
          : '${event.identifier}_event';
      buffer.writeln('        case \'${event.identifier}\':');
      buffer.writeln(
        '          final struct = parsedEvent.getValueByName(\'$pollingStructName\');',
      );
      buffer.writeln(
        '          return struct != null ? $eventClass.fromAbi(struct) : null;',
      );
    }

    buffer.writeln('        default:');
    buffer.writeln('          return null;');
    buffer.writeln('      }');
    buffer.writeln('    }).where((event) => event != null).cast<dynamic>();');
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  /// Stream filtered to only specified event types.');
    buffer.writeln('  ///');
    buffer.writeln('  /// #### Example');
    buffer.writeln('  /// ```dart');

    if (events.length >= 2) {
      final eventClass1 =
          '${nameSanitizer.toPascalCase(events[0].identifier)}Event';
      final eventClass2 =
          '${nameSanitizer.toPascalCase(events[1].identifier)}Event';
      buffer.writeln(
        '  /// stream.only([$eventClass1, $eventClass2]).listen((event) {',
      );
      buffer.writeln(
        '  ///   // Only ${events[0].identifier} and ${events[1].identifier} events',
      );
      buffer.writeln('  /// });');
    }

    buffer.writeln('  /// ```');
    buffer.writeln('  Stream<dynamic> only(List<Type> types) {');
    buffer.writeln(
      '    return all.where((event) => types.contains(event.runtimeType));',
    );
    buffer.writeln('  }');
    buffer.writeln('}');

    return FileOutput(
      path: 'events/multi_event_polling_stream.dart',
      content: buffer.toString(),
    );
  }
}
