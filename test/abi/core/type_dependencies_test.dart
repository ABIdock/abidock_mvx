import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('SmartContractAbi nested type dependency resolution', () {
    test('walks Tuple<u32, Option<MyStruct>> to find MyStruct dep', () {
      final Map<String, dynamic> data = <String, dynamic>{
        'name': 'TestContract',
        'types': <String, dynamic>{
          'MyStruct': <String, dynamic>{
            'type': 'struct',
            'fields': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'a', 'type': 'u32'},
            ],
          },
          'Outer': <String, dynamic>{
            'type': 'struct',
            'fields': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'data',
                'type': 'Tuple<u32, Option<MyStruct>>',
              },
            ],
          },
        },
      };

      final SmartContractAbi abi = SmartContractAbi.fromMap(data);
      expect(abi.types.keys, containsAll(<String>['MyStruct', 'Outer']));
      expect(abi.types['MyStruct'], isA<StructType>());
      expect(abi.types['Outer'], isA<StructType>());
    });

    test('walks enum variant fields to find struct dep', () {
      final Map<String, dynamic> data = <String, dynamic>{
        'name': 'C',
        'types': <String, dynamic>{
          'MyStruct': <String, dynamic>{
            'type': 'struct',
            'fields': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'a', 'type': 'u32'},
            ],
          },
          'E': <String, dynamic>{
            'type': 'enum',
            'variants': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'A',
                'discriminant': 0,
                'fields': <Map<String, dynamic>>[
                  <String, dynamic>{'name': '0', 'type': 'MyStruct'},
                ],
              },
              <String, dynamic>{'name': 'B', 'discriminant': 1},
            ],
          },
        },
      };
      final SmartContractAbi abi = SmartContractAbi.fromMap(data);
      expect(abi.types['MyStruct'], isA<StructType>());
      expect(abi.types['E'], isA<EnumType>());
    });

    test('resolves self-referential LinkedList without error', () {
      final Map<String, dynamic> data = <String, dynamic>{
        'name': 'C',
        'types': <String, dynamic>{
          'LinkedList': <String, dynamic>{
            'type': 'struct',
            'fields': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'value', 'type': 'u32'},
              <String, dynamic>{'name': 'next', 'type': 'Option<LinkedList>'},
            ],
          },
        },
      };
      final SmartContractAbi abi = SmartContractAbi.fromMap(data);
      expect(abi.types['LinkedList'], isA<StructType>());
    });

    test('resolves cross-recursive structs A<->B', () {
      final Map<String, dynamic> data = <String, dynamic>{
        'name': 'C',
        'types': <String, dynamic>{
          'A': <String, dynamic>{
            'type': 'struct',
            'fields': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'b', 'type': 'Option<B>'},
            ],
          },
          'B': <String, dynamic>{
            'type': 'struct',
            'fields': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'a', 'type': 'Option<A>'},
            ],
          },
        },
      };
      final SmartContractAbi abi = SmartContractAbi.fromMap(data);
      expect(abi.types['A'], isA<StructType>());
      expect(abi.types['B'], isA<StructType>());
    });

    test('handles deeply nested List<Option<Foo>> dependency', () {
      final Map<String, dynamic> data = <String, dynamic>{
        'name': 'C',
        'types': <String, dynamic>{
          'Foo': <String, dynamic>{
            'type': 'struct',
            'fields': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'x', 'type': 'u64'},
            ],
          },
          'Wrapper': <String, dynamic>{
            'type': 'struct',
            'fields': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'items', 'type': 'List<Option<Foo>>'},
            ],
          },
        },
      };
      final SmartContractAbi abi = SmartContractAbi.fromMap(data);
      expect(abi.types['Foo'], isA<StructType>());
      expect(abi.types['Wrapper'], isA<StructType>());
    });
  });

  group('ExplicitEnumType.fromRegistry', () {
    test('returns the registered ExplicitEnumType', () {
      final ExplicitEnumType original = ExplicitEnumType(
        name: 'Color',
        variants: const <ExplicitEnumVariantDefinition>[
          ExplicitEnumVariantDefinition(name: 'Red', discriminant: 0),
          ExplicitEnumVariantDefinition(name: 'Blue', discriminant: 1),
        ],
      );

      final AbiTypeFactory factory = AbiTypeFactory();
      factory.registerCustomType('Color', original);

      final ExplicitEnumType resolved = ExplicitEnumType.fromRegistry(
        'Color',
        factory,
      );
      expect(identical(resolved, original), isTrue);
      expect(resolved.variantCount, 2);
    });

    test('throws when name is not registered as an ExplicitEnumType', () {
      final AbiTypeFactory factory = AbiTypeFactory();
      expect(
        () => ExplicitEnumType.fromRegistry('Missing', factory),
        throwsArgumentError,
      );
    });
  });

  group('TypeFormula metadata', () {
    test('parses trailing *metadata* segment', () {
      final formula = TypeFormulaParser.parseString('ManagedDecimal<usize>*8*');

      expect(formula.name, 'ManagedDecimal');
      expect(formula.typeParameters.length, 1);
      expect(formula.typeParameters.first.name, 'usize');
      expect(formula.metadata, '8');
    });

    test('metadata round-trips through toString()', () {
      const input = 'ManagedDecimal<usize>*8*';
      final formula = TypeFormulaParser.parseString(input);
      expect(formula.toString(), input);
    });

    test('absent metadata stays null', () {
      final formula = TypeFormulaParser.parseString('Option<u32>');
      expect(formula.metadata, isNull);
      expect(formula.toString(), 'Option<u32>');
    });
  });
}
