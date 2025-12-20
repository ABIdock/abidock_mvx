import 'dart:convert';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../../fixtures/test_fixtures.dart';

void main() {
  group('SmartContractAbi', () {
    late SmartContractAbi abi;

    setUp(() {
      abi = SmartContractAbi.fromJson(mockPairAbiJson);
    });

    group('fromJson', () {
      test('parses valid JSON', () {
        expect(abi, isNotNull);
        expect(abi.name, 'Pair');
      });

      test('throws FormatException for invalid JSON', () {
        expect(
          () => SmartContractAbi.fromJson('invalid json'),
          throwsFormatException,
        );
      });

      test('throws FormatException for non-object JSON', () {
        expect(() => SmartContractAbi.fromJson('[]'), throwsFormatException);
      });
    });

    group('fromMap', () {
      test('parses map with all fields', () {
        final map = jsonDecode(mockPairAbiJson) as Map<String, dynamic>;
        final parsed = SmartContractAbi.fromMap(map);
        expect(parsed.name, 'Pair');
        expect(parsed.endpoints.length, 3);
        expect(parsed.events.length, 4);
        expect(parsed.types.length, 2);
      });

      test('handles missing optional fields', () {
        final minimal = SmartContractAbi.fromMap({
          'name': 'Minimal',
          'endpoints': [],
        });
        expect(minimal.name, 'Minimal');
        expect(minimal.version, '1.0');
        expect(minimal.constructor, isNull);
        expect(minimal.endpoints.isEmpty, isTrue);
        expect(minimal.events.isEmpty, isTrue);
        expect(minimal.types.isEmpty, isTrue);
      });

      test('parses custom types with dependencies', () {
        const jsonWithDeps = '''{
          "name": "Test",
          "endpoints": [],
          "types": {
            "Inner": {
              "type": "struct",
              "fields": [{"name": "value", "type": "u32"}]
            },
            "Outer": {
              "type": "struct",
              "fields": [{"name": "inner", "type": "Inner"}]
            }
          }
        }''';
        final parsed = SmartContractAbi.fromJson(jsonWithDeps);
        expect(parsed.types.containsKey('Inner'), isTrue);
        expect(parsed.types.containsKey('Outer'), isTrue);
      });

      test('throws on circular type dependencies', () {
        const circularJson = '''{
          "name": "Test",
          "endpoints": [],
          "types": {
            "A": {
              "type": "struct",
              "fields": [{"name": "b", "type": "B"}]
            },
            "B": {
              "type": "struct",
              "fields": [{"name": "a", "type": "A"}]
            }
          }
        }''';
        expect(
          () => SmartContractAbi.fromJson(circularJson),
          throwsFormatException,
        );
      });
    });

    group('empty constructor', () {
      test('creates ABI with no endpoints', () {
        const empty = SmartContractAbi.empty();
        expect(empty.name, '');
        expect(empty.version, '1.0');
        expect(empty.isEmpty, isTrue);
        expect(empty.constructor, isNull);
      });

      test('creates ABI with custom name', () {
        const empty = SmartContractAbi.empty(name: 'Empty', version: '2.0');
        expect(empty.name, 'Empty');
        expect(empty.version, '2.0');
      });
    });

    group('getEndpoint', () {
      test('returns endpoint when exists', () {
        final endpoint = abi.getEndpoint(
          const SmartContractFunction('getReserve'),
        );
        expect(endpoint, isNotNull);
        expect(endpoint!.name, 'getReserve');
      });

      test('returns null when endpoint does not exist', () {
        final endpoint = abi.getEndpoint(
          const SmartContractFunction('nonExistent'),
        );
        expect(endpoint, isNull);
      });
    });

    group('hasEndpoint', () {
      test('returns true for existing endpoint', () {
        expect(
          abi.hasEndpoint(const SmartContractFunction('getReserve')),
          isTrue,
        );
      });

      test('returns false for non-existing endpoint', () {
        expect(
          abi.hasEndpoint(const SmartContractFunction('nonExistent')),
          isFalse,
        );
      });
    });

    group('hasConstructor', () {
      test('returns true when constructor exists', () {
        expect(abi.hasConstructor, isTrue);
      });

      test('returns false when constructor does not exist', () {
        final noConstructor = SmartContractAbi.fromMap({
          'name': 'Test',
          'endpoints': [],
        });
        expect(noConstructor.hasConstructor, isFalse);
      });
    });

    group('hasUpgradeConstructor', () {
      test('returns false when upgrade constructor does not exist', () {
        expect(abi.hasUpgradeConstructor, isFalse);
      });
    });

    group('getEvent', () {
      test('returns event when exists', () {
        final event = abi.getEvent('swap');
        expect(event, isNotNull);
        expect(event!.identifier, 'swap');
      });

      test('returns null when event does not exist', () {
        final event = abi.getEvent('nonExistent');
        expect(event, isNull);
      });
    });

    group('hasEvent', () {
      test('returns true for existing event', () {
        expect(abi.hasEvent('swap'), isTrue);
      });

      test('returns false for non-existing event', () {
        expect(abi.hasEvent('nonExistent'), isFalse);
      });
    });

    group('endpoint categorization', () {
      test('viewEndpoints returns readonly endpoints', () {
        final views = abi.viewEndpoints;
        expect(views.length, 1);
        expect(views.first.name, 'getReserve');
      });

      test('mutableEndpoints returns mutable endpoints', () {
        final mutables = abi.mutableEndpoints;
        expect(mutables.length, 2);
      });

      test('payableEndpoints returns payable endpoints', () {
        final payables = abi.payableEndpoints;
        expect(payables.length, 2);
      });
    });

    group('endpointCount and isEmpty', () {
      test('endpointCount returns correct count', () {
        expect(abi.endpointCount, 3);
      });

      test('isEmpty returns false when has endpoints', () {
        expect(abi.isEmpty, isFalse);
      });

      test('isNotEmpty returns true when has endpoints', () {
        expect(abi.isNotEmpty, isTrue);
      });

      test('isEmpty returns true for empty ABI', () {
        const empty = SmartContractAbi.empty();
        expect(empty.isEmpty, isTrue);
        expect(empty.isNotEmpty, isFalse);
      });
    });

    group('getCustomType', () {
      test('returns type when exists', () {
        final type = abi.getCustomType('EsdtTokenPayment');
        expect(type, isNotNull);
        expect(type, isA<StructType>());
      });

      test('returns null when type does not exist', () {
        final type = abi.getCustomType('NonExistent');
        expect(type, isNull);
      });
    });

    group('getEnum', () {
      test('returns enum type when exists', () {
        final enumType = abi.getEnum('State');
        expect(enumType, isNotNull);
        expect(enumType!.variants.length, 3);
      });

      test('returns null when enum does not exist', () {
        final enumType = abi.getEnum('NonExistent');
        expect(enumType, isNull);
      });

      test('throws when type is not enum', () {
        expect(() => abi.getEnum('EsdtTokenPayment'), throwsArgumentError);
      });
    });

    group('getStruct', () {
      test('returns struct type when exists', () {
        final structType = abi.getStruct('EsdtTokenPayment');
        expect(structType, isNotNull);
        expect(structType!.fieldDefinitions.length, 3);
      });

      test('returns null when struct does not exist', () {
        final structType = abi.getStruct('NonExistent');
        expect(structType, isNull);
      });

      test('throws when type is not struct', () {
        expect(() => abi.getStruct('State'), throwsArgumentError);
      });
    });

    group('hasCustomType', () {
      test('returns true for existing type', () {
        expect(abi.hasCustomType('EsdtTokenPayment'), isTrue);
      });

      test('returns false for non-existing type', () {
        expect(abi.hasCustomType('NonExistent'), isFalse);
      });
    });

    group('customTypeCount', () {
      test('returns correct count', () {
        expect(abi.customTypeCount, 2);
      });
    });

    group('validateInputs', () {
      test('returns true for valid inputs', () {
        final isValid = abi.validateInputs(
          const SmartContractFunction('getReserve'),
          ['TOKEN-123456'],
        );
        expect(isValid, isTrue);
      });

      test('returns false for non-existing endpoint', () {
        final isValid = abi.validateInputs(
          const SmartContractFunction('nonExistent'),
          [],
        );
        expect(isValid, isFalse);
      });
    });

    group('copyWith', () {
      test('creates copy with same values', () {
        final copy = abi.copyWith();
        expect(copy.name, abi.name);
        expect(copy.version, abi.version);
        expect(copy.endpoints.length, abi.endpoints.length);
        expect(copy.types.length, abi.types.length);
      });

      test('creates copy with updated name', () {
        final copy = abi.copyWith(name: 'NewName');
        expect(copy.name, 'NewName');
        expect(copy.version, abi.version);
      });

      test('creates copy with updated version', () {
        final copy = abi.copyWith(version: '2.0');
        expect(copy.version, '2.0');
        expect(copy.name, abi.name);
      });

      test('creates copy with updated types', () {
        final newTypes = <String, AbiType>{'Custom': U32Type.type};
        final copy = abi.copyWith(types: newTypes);
        expect(copy.types.length, 1);
        expect(copy.types.containsKey('Custom'), isTrue);
      });

      test('creates copy with updated metadata', () {
        final copy = abi.copyWith(metadata: {'key': 'value'});
        expect(copy.metadata['key'], 'value');
      });
    });

    group('toMap', () {
      test('serializes basic fields', () {
        final map = abi.toMap();
        expect(map['name'], 'Pair');
        expect(map['version'], '1.0');
        expect(map['endpoints'], isA<List>());
      });

      test('includes constructor when present', () {
        final map = abi.toMap();
        expect(map.containsKey('constructor'), isTrue);
      });

      test('includes events when present', () {
        final map = abi.toMap();
        expect(map.containsKey('events'), isTrue);
        expect(map['events'], isA<List>());
      });

      test('includes types when present', () {
        final map = abi.toMap();
        expect(map.containsKey('types'), isTrue);
        expect(map['types'], isA<Map>());
      });

      test('excludes constructor when null', () {
        final noConstructor = SmartContractAbi.fromMap({
          'name': 'Test',
          'endpoints': [],
        });
        final map = noConstructor.toMap();
        expect(map.containsKey('constructor'), isFalse);
      });

      test('excludes events when empty', () {
        final noEvents = SmartContractAbi.fromMap({
          'name': 'Test',
          'endpoints': [],
        });
        final map = noEvents.toMap();
        expect(map.containsKey('events'), isFalse);
      });

      test('excludes types when empty', () {
        final noTypes = SmartContractAbi.fromMap({
          'name': 'Test',
          'endpoints': [],
        });
        final map = noTypes.toMap();
        expect(map.containsKey('types'), isFalse);
      });

      test('serializes struct types correctly', () {
        final map = abi.toMap();
        final types = map['types'] as Map<String, dynamic>;
        final structType = types['EsdtTokenPayment'] as Map<String, dynamic>;
        expect(structType['type'], 'struct');
        expect(structType['fields'], isA<List>());
      });

      test('serializes enum types correctly', () {
        final map = abi.toMap();
        final types = map['types'] as Map<String, dynamic>;
        final enumType = types['State'] as Map<String, dynamic>;
        expect(enumType['type'], 'enum');
        expect(enumType['variants'], isA<List>());
      });
    });

    group('toJson', () {
      test('returns valid JSON string', () {
        final json = abi.toJson();
        expect(() => jsonDecode(json), returnsNormally);
      });

      test('returns indented JSON when indent specified', () {
        final json = abi.toJson(indent: '  ');
        expect(json.contains('\n'), isTrue);
      });

      test('returns compact JSON when no indent', () {
        final json = abi.toJson();
        expect(json.contains('\n'), isFalse);
      });
    });

    group('equality', () {
      test('equal ABIs are equal', () {
        final abi1 = SmartContractAbi.fromJson(mockPairAbiJson);
        final abi2 = SmartContractAbi.fromJson(mockPairAbiJson);
        expect(abi1, equals(abi2));
      });

      test('different names are not equal', () {
        final abi1 = SmartContractAbi.fromJson(mockPairAbiJson);
        final abi2 = abi1.copyWith(name: 'Different');
        expect(abi1, isNot(equals(abi2)));
      });

      test('different versions are not equal', () {
        final abi1 = SmartContractAbi.fromJson(mockPairAbiJson);
        final abi2 = abi1.copyWith(version: '2.0');
        expect(abi1, isNot(equals(abi2)));
      });

      test('different types are not equal', () {
        final abi1 = SmartContractAbi.fromJson(mockPairAbiJson);
        final abi2 = abi1.copyWith(types: {});
        expect(abi1, isNot(equals(abi2)));
      });

      test('identical ABI is equal', () {
        expect(abi, equals(abi));
      });
    });

    group('hashCode', () {
      test('hashCode returns integer', () {
        expect(abi.hashCode, isA<int>());
      });

      test('different ABIs may have different hashCodes', () {
        final different = abi.copyWith(name: 'Different');
        expect(abi.hashCode, isNot(equals(different.hashCode)));
      });
    });

    group('toString', () {
      test('includes name and version', () {
        final str = abi.toString();
        expect(str.contains('Pair'), isTrue);
        expect(str.contains('v1.0'), isTrue);
      });

      test('includes endpoint count', () {
        final str = abi.toString();
        expect(str.contains('3 endpoints'), isTrue);
      });

      test('includes event count when events exist', () {
        final str = abi.toString();
        expect(str.contains('4 events'), isTrue);
      });

      test('includes constructor info when present', () {
        final str = abi.toString();
        expect(str.contains('has constructor'), isTrue);
      });
    });
  });

  group('AbiRegistry', () {
    late AbiRegistry registry;
    late SmartContractAbi abi;

    setUp(() {
      registry = AbiRegistry();
      abi = SmartContractAbi.fromJson(mockPairAbiJson);
    });

    group('constructor', () {
      test('creates empty registry', () {
        expect(registry.isEmpty, isTrue);
        expect(registry.count, 0);
      });
    });

    group('withAbis', () {
      test('creates registry with initial ABIs', () {
        final reg = AbiRegistry.withAbis({'Pair': abi});
        expect(reg.count, 1);
        expect(reg.hasAbi('Pair'), isTrue);
      });
    });

    group('register', () {
      test('registers ABI successfully', () {
        registry.register('Pair', abi);
        expect(registry.hasAbi('Pair'), isTrue);
      });

      test('replaces existing ABI', () {
        registry.register('Pair', abi);
        final newAbi = abi.copyWith(version: '2.0');
        registry.register('Pair', newAbi);
        expect(registry.getAbi('Pair')!.version, '2.0');
      });

      test('throws ArgumentError for empty name', () {
        expect(() => registry.register('', abi), throwsArgumentError);
      });
    });

    group('loadFromJson', () {
      test('loads and registers ABI from JSON', () {
        registry.loadFromJson('Pair', mockPairAbiJson);
        expect(registry.hasAbi('Pair'), isTrue);
        expect(registry.getAbi('Pair')!.name, 'Pair');
      });

      test('throws ArgumentError for empty name', () {
        expect(
          () => registry.loadFromJson('', mockPairAbiJson),
          throwsArgumentError,
        );
      });

      test('throws FormatException for invalid JSON', () {
        expect(
          () => registry.loadFromJson('Test', 'invalid'),
          throwsFormatException,
        );
      });
    });

    group('getAbi', () {
      test('returns ABI when exists', () {
        registry.register('Pair', abi);
        final result = registry.getAbi('Pair');
        expect(result, isNotNull);
        expect(result!.name, 'Pair');
      });

      test('returns null when not exists', () {
        final result = registry.getAbi('NonExistent');
        expect(result, isNull);
      });
    });

    group('hasAbi', () {
      test('returns true for registered ABI', () {
        registry.register('Pair', abi);
        expect(registry.hasAbi('Pair'), isTrue);
      });

      test('returns false for unregistered ABI', () {
        expect(registry.hasAbi('NonExistent'), isFalse);
      });
    });

    group('contractNames', () {
      test('returns list of registered names', () {
        registry.register('Pair', abi);
        registry.register('Token', abi.copyWith(name: 'Token'));
        final names = registry.contractNames;
        expect(names.length, 2);
        expect(names.contains('Pair'), isTrue);
        expect(names.contains('Token'), isTrue);
      });

      test('returns empty list when no ABIs', () {
        expect(registry.contractNames, isEmpty);
      });
    });

    group('abis', () {
      test('returns list of registered ABIs', () {
        registry.register('Pair', abi);
        final abis = registry.abis;
        expect(abis.length, 1);
        expect(abis.first.name, 'Pair');
      });

      test('returns empty list when no ABIs', () {
        expect(registry.abis, isEmpty);
      });
    });

    group('count', () {
      test('returns correct count', () {
        registry.register('Pair', abi);
        registry.register('Token', abi.copyWith(name: 'Token'));
        expect(registry.count, 2);
      });
    });

    group('isEmpty and isNotEmpty', () {
      test('isEmpty returns true for empty registry', () {
        expect(registry.isEmpty, isTrue);
        expect(registry.isNotEmpty, isFalse);
      });

      test('isEmpty returns false when has ABIs', () {
        registry.register('Pair', abi);
        expect(registry.isEmpty, isFalse);
        expect(registry.isNotEmpty, isTrue);
      });
    });

    group('remove', () {
      test('removes and returns ABI', () {
        registry.register('Pair', abi);
        final removed = registry.remove('Pair');
        expect(removed, isNotNull);
        expect(removed!.name, 'Pair');
        expect(registry.hasAbi('Pair'), isFalse);
      });

      test('returns null when ABI not found', () {
        final removed = registry.remove('NonExistent');
        expect(removed, isNull);
      });
    });

    group('clear', () {
      test('removes all ABIs', () {
        registry.register('Pair', abi);
        registry.register('Token', abi.copyWith(name: 'Token'));
        registry.clear();
        expect(registry.isEmpty, isTrue);
        expect(registry.count, 0);
      });
    });

    group('toString', () {
      test('includes ABI count', () {
        registry.register('Pair', abi);
        final str = registry.toString();
        expect(str.contains('1 ABIs'), isTrue);
      });
    });
  });
}
