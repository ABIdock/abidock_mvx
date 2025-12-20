import 'package:abidock_mvx/src/abi/types/primitives/boolean.dart';
import 'package:abidock_mvx/src/abi/types/primitives/numerical.dart';
import 'package:abidock_mvx/src/abi/types/primitives/string.dart';
import 'package:abidock_mvx/src/abi/types/special/composite.dart';
import 'package:test/test.dart';

void main() {
  group('CompositeType', () {
    group('of', () {
      test('creates with single field type', () {
        final type = CompositeType.of([U32Type.type]);
        expect(type.fieldTypes.length, equals(1));
        expect(type.fieldTypes[0].name, equals('u32'));
      });

      test('creates with multiple field types', () {
        final type = CompositeType.of([
          U64Type.type,
          BooleanType.type,
          StringType.type,
        ]);
        expect(type.fieldTypes.length, equals(3));
      });

      test('throws on empty field types', () {
        expect(() => CompositeType.of([]), throwsArgumentError);
      });

      test('name includes field types', () {
        final type = CompositeType.of([U32Type.type, BooleanType.type]);
        expect(type.name, contains('u32'));
        expect(type.name, contains('bool'));
      });
    });

    group('create', () {
      test('creates value with matching types', () {
        final value = CompositeType.create(
          [U32Type.type, BooleanType.type],
          [42, true],
        );
        expect(value.length, equals(2));
        expect((value[0] as U32Value).value, equals(42));
        expect((value[1] as BooleanValue).value, isTrue);
      });

      test('creates value with BigInt', () {
        final value = CompositeType.create(
          [BigUIntType.type],
          [BigInt.from(1000000)],
        );
        expect((value[0] as BigUIntValue).value, equals(BigInt.from(1000000)));
      });
    });

    group('createValue', () {
      test('throws on wrong number of values', () {
        final type = CompositeType.of([U32Type.type, U64Type.type]);
        expect(() => type.createValue([1]), throwsArgumentError);
        expect(() => type.createValue([1, 2, 3]), throwsArgumentError);
      });

      test('handles nested types', () {
        final type = CompositeType.of([
          U8Type.type,
          U16Type.type,
          U32Type.type,
          U64Type.type,
        ]);
        final value = type.createValue([1, 2, 3, BigInt.from(4)]);
        expect(value, isA<CompositeValue>());
      });
    });

    group('properties', () {
      test('className is correct', () {
        final type = CompositeType.of([U32Type.type]);
        expect(type.className, equals('CompositeType'));
      });

      test('classHierarchy is correct', () {
        final type = CompositeType.of([U32Type.type]);
        expect(type.classHierarchy, contains('CompositeType'));
        expect(type.classHierarchy, contains('CustomType'));
        expect(type.classHierarchy, contains('AbiType'));
      });
    });
  });

  group('CompositeValue', () {
    group('length', () {
      test('returns correct field count', () {
        final value = CompositeType.create(
          [U32Type.type, BooleanType.type, StringType.type],
          [1, true, 'test'],
        );
        expect(value.length, equals(3));
      });
    });

    group('index operator', () {
      test('retrieves typed value by index', () {
        final value = CompositeType.create(
          [U64Type.type, BooleanType.type],
          [BigInt.from(999), false],
        );
        expect((value[0] as U64Value).value, equals(BigInt.from(999)));
        expect((value[1] as BooleanValue).value, isFalse);
      });

      test('throws on invalid index', () {
        final value = CompositeType.create([U32Type.type], [42]);
        expect(() => value[1], throwsRangeError);
        expect(() => value[-1], throwsRangeError);
      });
    });

    group('fields', () {
      test('returns all field values', () {
        final value = CompositeType.create([U8Type.type, U16Type.type], [1, 2]);
        expect(value.fields.length, equals(2));
      });
    });

    group('nativeValue', () {
      test('returns list of native values', () {
        final value = CompositeType.create(
          [U32Type.type, BooleanType.type],
          [42, true],
        );
        final native = value.nativeValue;
        expect(native, isA<List>());
        expect(native[0], equals(42));
        expect(native[1], equals(true));
      });
    });

    group('equality', () {
      test('equal composites are equal', () {
        final v1 = CompositeType.create([U32Type.type], [42]);
        final v2 = CompositeType.create([U32Type.type], [42]);
        expect(v1.nativeValue, equals(v2.nativeValue));
      });

      test('different values are not equal', () {
        final v1 = CompositeType.create([U32Type.type], [42]);
        final v2 = CompositeType.create([U32Type.type], [43]);
        expect(v1.nativeValue, isNot(equals(v2.nativeValue)));
      });
    });
  });
}
