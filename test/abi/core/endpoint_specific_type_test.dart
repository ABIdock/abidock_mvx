/// Coverage for the two ABI JSON keys that carry endpoint metadata beyond the
/// wire type: the endpoint's internal method name and a parameter's semantic
/// refinement of a plain integer type.
///
/// The chain exposes both second-resolution and millisecond-resolution time
/// values, so a `u64` declared as `TimestampMillis` must stay distinguishable
/// from one declared as `TimestampSeconds` even though both encode identically.
library;

import 'dart:convert';
import 'dart:io';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../../../bin/codegen/cli/validation/abi_validator.dart';
import '../../../bin/codegen/cli/validation/validation_models.dart';

const String _abiWithMetadataKeys = '''
{
  "buildInfo": {
    "rustc": {"version": "1.85.0"},
    "contractCrate": {"name": "time-tester", "version": "0.0.0"},
    "framework": {"name": "multiversx-sc", "version": "0.66.2"}
  },
  "name": "TimeTester",
  "constructor": {
    "inputs": [],
    "outputs": []
  },
  "endpoints": [
    {
      "name": "scheduleTask",
      "rustMethodName": "schedule_task",
      "mutability": "mutable",
      "inputs": [
        {
          "name": "start_at",
          "type": "u64",
          "specificType": "TimestampMillis"
        },
        {
          "name": "window",
          "type": "u64",
          "specificType": "DurationSeconds"
        },
        {
          "name": "payload",
          "type": "bytes"
        }
      ],
      "outputs": [
        {
          "type": "u64",
          "specificType": "TimestampSeconds"
        },
        {
          "type": "u64",
          "specificType": "DurationMillis"
        }
      ]
    },
    {
      "name": "plainEndpoint",
      "mutability": "readonly",
      "inputs": [
        {
          "name": "index",
          "type": "u64"
        }
      ],
      "outputs": [
        {
          "type": "u64"
        }
      ]
    }
  ],
  "events": [],
  "esdtAttributes": [],
  "hasCallback": false,
  "types": {}
}
''';

void main() {
  group('AbiParameter specificType', () {
    late SmartContractAbi abi;

    setUp(() {
      abi = SmartContractAbi.fromJson(_abiWithMetadataKeys);
    });

    test('is exposed on inputs that declare it', () {
      final AbiEndpoint endpoint = abi.endpoints.getByName('scheduleTask')!;

      expect(endpoint.inputs[0].name, 'start_at');
      expect(endpoint.inputs[0].specificType, 'TimestampMillis');
      expect(endpoint.inputs[1].name, 'window');
      expect(endpoint.inputs[1].specificType, 'DurationSeconds');
    });

    test('is exposed on outputs that declare it', () {
      final AbiEndpoint endpoint = abi.endpoints.getByName('scheduleTask')!;

      expect(endpoint.outputs[0].specificType, 'TimestampSeconds');
      expect(endpoint.outputs[1].specificType, 'DurationMillis');
    });

    test('distinguishes millisecond from second resolution', () {
      final AbiEndpoint endpoint = abi.endpoints.getByName('scheduleTask')!;

      expect(
        endpoint.inputs[0].specificType,
        isNot(endpoint.inputs[1].specificType),
      );
      expect(
        endpoint.outputs[0].specificType,
        isNot(endpoint.outputs[1].specificType),
      );
    });

    test('leaves the wire type untouched', () {
      final AbiEndpoint endpoint = abi.endpoints.getByName('scheduleTask')!;

      expect(endpoint.inputs[0].type.name, 'u64');
      expect(endpoint.inputs[1].type.name, 'u64');
      expect(endpoint.outputs[0].type.name, 'u64');
      expect(endpoint.outputs[1].type.name, 'u64');
    });

    test('is null when the ABI omits it', () {
      final AbiEndpoint endpoint = abi.endpoints.getByName('scheduleTask')!;
      expect(endpoint.inputs[2].name, 'payload');
      expect(endpoint.inputs[2].specificType, isNull);

      final AbiEndpoint plain = abi.endpoints.getByName('plainEndpoint')!;
      expect(plain.inputs[0].specificType, isNull);
      expect(plain.outputs[0].specificType, isNull);
    });

    test('participates in equality', () {
      final AbiParameter millis = AbiParameter(
        name: 'at',
        type: U64Type.type,
        specificType: 'TimestampMillis',
      );
      final AbiParameter seconds = AbiParameter(
        name: 'at',
        type: U64Type.type,
        specificType: 'TimestampSeconds',
      );
      final AbiParameter bare = AbiParameter(name: 'at', type: U64Type.type);

      expect(millis == seconds, isFalse);
      expect(millis == bare, isFalse);
      expect(millis.hashCode == seconds.hashCode, isFalse);
    });

    test('round-trips through toMap', () {
      final AbiEndpoint endpoint = abi.endpoints.getByName('scheduleTask')!;
      final Map<String, dynamic> map = endpoint.inputs[0].toMap();

      expect(map['type'], 'u64');
      expect(map['specificType'], 'TimestampMillis');

      final AbiParameter reparsed = AbiParameter.fromMap(map);
      expect(reparsed.specificType, 'TimestampMillis');
      expect(reparsed.type.name, 'u64');
    });

    test('is omitted from toMap when absent', () {
      final AbiParameter bare = AbiParameter(name: 'at', type: U64Type.type);
      expect(bare.toMap().containsKey('specificType'), isFalse);
    });

    test('is carried by AbiParameter.fromTypeString', () {
      final AbiParameter param = AbiParameter.fromTypeString(
        name: 'deadline',
        typeString: 'u64',
        specificType: 'TimestampSeconds',
      );

      expect(param.specificType, 'TimestampSeconds');
      expect(param.type.name, 'u64');
    });
  });

  group('AbiEndpoint internalMethodName', () {
    late SmartContractAbi abi;

    setUp(() {
      abi = SmartContractAbi.fromJson(_abiWithMetadataKeys);
    });

    test('is exposed when the ABI declares it', () {
      final AbiEndpoint endpoint = abi.endpoints.getByName('scheduleTask')!;

      expect(endpoint.name, 'scheduleTask');
      expect(endpoint.internalMethodName, 'schedule_task');
    });

    test('is null when the ABI omits it', () {
      final AbiEndpoint endpoint = abi.endpoints.getByName('plainEndpoint')!;

      expect(endpoint.name, 'plainEndpoint');
      expect(endpoint.internalMethodName, isNull);
    });

    test('does not replace the dispatched endpoint name', () {
      expect(abi.endpoints.hasEndpoint('scheduleTask'), isTrue);
      expect(abi.endpoints.hasEndpoint('schedule_task'), isFalse);
      expect(abi.endpoints.getByName('schedule_task'), isNull);
    });

    test('participates in equality', () {
      const AbiEndpoint withInternal = AbiEndpoint(
        name: 'scheduleTask',
        internalMethodName: 'schedule_task',
      );
      const AbiEndpoint withoutInternal = AbiEndpoint(name: 'scheduleTask');

      expect(withInternal == withoutInternal, isFalse);
      expect(withInternal.hashCode == withoutInternal.hashCode, isFalse);
    });

    test('round-trips through toMap', () {
      final AbiEndpoint endpoint = abi.endpoints.getByName('scheduleTask')!;
      final Map<String, dynamic> map = endpoint.toMap();

      expect(map['name'], 'scheduleTask');
      expect(map['rustMethodName'], 'schedule_task');

      final AbiEndpoint reparsed = AbiEndpoint.fromMap(map);
      expect(reparsed.internalMethodName, 'schedule_task');
    });

    test('is omitted from toMap when absent', () {
      final AbiEndpoint endpoint = abi.endpoints.getByName('plainEndpoint')!;
      expect(endpoint.toMap().containsKey('rustMethodName'), isFalse);
    });
  });

  group('ABI reader tolerance', () {
    test('parses an ABI carrying both metadata keys without throwing', () {
      final SmartContractAbi abi = SmartContractAbi.fromJson(
        _abiWithMetadataKeys,
      );

      expect(abi.name, 'TimeTester');
      expect(abi.endpointCount, 2);
    });

    test('ignores unrecognised keys on endpoints and parameters', () {
      final Map<String, dynamic> data =
          jsonDecode(_abiWithMetadataKeys) as Map<String, dynamic>;
      final List<dynamic> endpoints = data['endpoints'] as List<dynamic>;
      final Map<String, dynamic> endpoint =
          endpoints[0] as Map<String, dynamic>;
      endpoint['someFutureEndpointKey'] = 'value';
      final List<dynamic> inputs = endpoint['inputs'] as List<dynamic>;
      (inputs[0] as Map<String, dynamic>)['someFutureInputKey'] = 42;

      final SmartContractAbi abi = SmartContractAbi.fromMap(data);

      expect(abi.endpointCount, 2);
      expect(
        abi.endpoints.getByName('scheduleTask')!.inputs[0].specificType,
        'TimestampMillis',
      );
    });
  });

  group('AbiValidator', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('abidock_abi_validator');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('accepts an ABI carrying both metadata keys', () async {
      final File abiFile = File('${tempDir.path}/time_tester.abi.json');
      abiFile.writeAsStringSync(_abiWithMetadataKeys);

      final ValidationReport report = await AbiValidator().validate(
        contractName: 'TimeTester',
        abiPath: abiFile.path,
      );

      expect(report.passed, isTrue);
      expect(report.errors, isEmpty);
      expect(report.warnings, isEmpty);
      expect(
        report.issues.where(
          (ValidationIssue issue) =>
              issue.message.contains('specificType') ||
              issue.message.contains('rustMethodName'),
        ),
        isEmpty,
      );
    });

    test('validates a real contract ABI without warnings', () async {
      final ValidationReport report = await AbiValidator().validate(
        contractName: 'Pair',
        abiPath: 'example/cookbook/pair.abi.json',
      );

      expect(report.errors, isEmpty);
      expect(
        report.warnings.map((ValidationIssue issue) => issue.message),
        isEmpty,
      );
    });

    test('warns when buildInfo omits contractCrate and framework', () async {
      final File abiFile = File('${tempDir.path}/no_build_info.abi.json');
      abiFile.writeAsStringSync('''
{
  "buildInfo": {"rustc": {"version": "1.85.0"}},
  "name": "Bare",
  "endpoints": [{"name": "ping", "mutability": "mutable"}],
  "types": {}
}
''');

      final ValidationReport report = await AbiValidator().validate(
        contractName: 'Bare',
        abiPath: abiFile.path,
      );

      final List<String> messages = report.warnings
          .map((ValidationIssue issue) => issue.message)
          .toList();

      expect(messages, contains('Missing "contractCrate" in buildInfo'));
      expect(messages, contains('Missing "framework" in buildInfo'));
    });
  });
}
