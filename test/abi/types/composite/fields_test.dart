import 'package:abidock_mvx/src/abi/types/composite/fields.dart';
import 'package:abidock_mvx/src/abi/types/primitives/boolean.dart';
import 'package:abidock_mvx/src/abi/types/primitives/numerical.dart';
import 'package:abidock_mvx/src/abi/types/primitives/string.dart';
import 'package:test/test.dart';

void main() {
  group('FieldDefinition', () {
    group('constructor', () {
      test('creates with required parameters', () {
        final field = FieldDefinition(name: 'balance', type: U64Type.type);
        expect(field.name, equals('balance'));
        expect(field.type.name, equals('u64'));
        expect(field.description, isNull);
      });

      test('creates with description', () {
        final field = FieldDefinition(
          name: 'active',
          type: BooleanType.type,
          description: 'Whether the account is active',
        );
        expect(field.description, equals('Whether the account is active'));
      });
    });

    group('toMap', () {
      test('returns correct map structure', () {
        final field = FieldDefinition(name: 'amount', type: BigUIntType.type);
        final map = field.toMap();
        expect(map['name'], equals('amount'));
        expect(map['type'], equals('BigUint'));
      });
    });

    group('equality', () {
      test('equal fields are equal', () {
        final field1 = FieldDefinition(name: 'x', type: U32Type.type);
        final field2 = FieldDefinition(name: 'x', type: U32Type.type);
        expect(field1, equals(field2));
      });

      test('different names are not equal', () {
        final field1 = FieldDefinition(name: 'x', type: U32Type.type);
        final field2 = FieldDefinition(name: 'y', type: U32Type.type);
        expect(field1, isNot(equals(field2)));
      });

      test('different types are not equal', () {
        final field1 = FieldDefinition(name: 'x', type: U32Type.type);
        final field2 = FieldDefinition(name: 'x', type: U64Type.type);
        expect(field1, isNot(equals(field2)));
      });

      test('hashCode is consistent', () {
        final field1 = FieldDefinition(name: 'test', type: U8Type.type);
        final field2 = FieldDefinition(name: 'test', type: U8Type.type);
        expect(field1.hashCode, equals(field2.hashCode));
      });
    });

    group('toString', () {
      test('format without description', () {
        final field = FieldDefinition(name: 'value', type: U64Type.type);
        expect(field.toString(), contains('value'));
        expect(field.toString(), contains('u64'));
      });

      test('format with description', () {
        final field = FieldDefinition(
          name: 'count',
          type: U32Type.type,
          description: 'Item count',
        );
        expect(field.toString(), contains('count'));
        expect(field.toString(), contains('u32'));
        expect(field.toString(), contains('Item count'));
      });
    });
  });

  group('Field', () {
    group('constructor', () {
      test('creates with name and value', () {
        final field = Field(name: 'enabled', value: BooleanValue(true));
        expect(field.name, equals('enabled'));
        expect((field.value as BooleanValue).value, isTrue);
      });

      test('works with different value types', () {
        final u64Field = Field(name: 'n', value: U64Value(BigInt.from(42)));
        expect(u64Field.name, equals('n'));

        final stringField = Field(name: 's', value: StringValue('hello'));
        expect(stringField.name, equals('s'));

        final boolField = Field(name: 'b', value: BooleanValue(false));
        expect(boolField.name, equals('b'));
      });
    });

    group('value access', () {
      test('value returns correct type', () {
        final field = Field(
          name: 'amount',
          value: BigUIntValue(BigInt.parse('1000000000000000000')),
        );
        expect(field.value, isA<BigUIntValue>());
        expect(
          (field.value as BigUIntValue).value,
          equals(BigInt.parse('1000000000000000000')),
        );
      });
    });
  });

  group('Field combinations', () {
    test('multiple fields with different types', () {
      final fields = [
        Field(name: 'id', value: U64Value(BigInt.from(1))),
        Field(name: 'name', value: StringValue('Test')),
        Field(name: 'active', value: BooleanValue(true)),
        Field(name: 'balance', value: BigUIntValue(BigInt.from(1000))),
      ];

      expect(fields.length, equals(4));
      expect(fields[0].name, equals('id'));
      expect(fields[1].name, equals('name'));
      expect(fields[2].name, equals('active'));
      expect(fields[3].name, equals('balance'));
    });
  });
}
