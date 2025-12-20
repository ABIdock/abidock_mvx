import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('OptionalType', () {
    test('has correct properties', () {
      final type = OptionalType.of(U32Type.type);
      expect(type.name, 'Optional');
      expect(type.innerType, U32Type.type);
    });

    test('creates values from input', () {
      final type = OptionalType.of(U32Type.type);

      final provided = type.createValue(42) as OptionalValue;
      expect(provided.isProvided, isTrue);
      expect(provided.isMissing, isFalse);
      expect(provided.nativeValue, 42);

      final missing = type.createValue(null) as OptionalValue;
      expect(missing.isProvided, isFalse);
      expect(missing.isMissing, isTrue);
      expect(missing.nativeValue, isNull);
    });

    test('works with different inner types', () {
      final numType = OptionalType.of(U64Type.type);
      expect(numType.innerType, isA<U64Type>());

      final strType = OptionalType.of(StringType.type);
      expect(strType.innerType, isA<StringType>());
    });
  });

  group('OptionalValue - Provided', () {
    test('handles provided values correctly', () {
      final type = OptionalType.of(U32Type.type);
      final value = type.createValue(100) as OptionalValue;

      expect(value.nativeValue, 100);
      expect(value.isProvided, isTrue);
      expect(value.isMissing, isFalse);

      final unwrapped = value.unwrap();
      expect(unwrapped, isA<U32Value>());
      expect((unwrapped as U32Value).nativeValue, 100);
    });

    test('handles edge cases', () {
      final numType = OptionalType.of(U32Type.type);
      final zeroValue = numType.createValue(0) as OptionalValue;
      expect(zeroValue.isProvided, isTrue);
      expect(zeroValue.nativeValue, 0);

      final strType = OptionalType.of(StringType.type);
      final stringValue = strType.createValue('hello') as OptionalValue;
      expect(stringValue.nativeValue, 'hello');
    });
  });

  group('OptionalValue - Missing', () {
    test('handles missing values correctly', () {
      final type = OptionalType.of(U32Type.type);
      final value = type.createValue(null) as OptionalValue;

      expect(value.nativeValue, isNull);
      expect(value.isProvided, isFalse);
      expect(value.isMissing, isTrue);
      expect(() => value.unwrap(), throwsStateError);
    });

    test('works with factory methods', () {
      final type = OptionalType.of(U32Type.type);

      final innerValue = U32Type.create(42);
      final provided = OptionalValue.provided(type, innerValue);
      expect(provided.isProvided, isTrue);
      expect(provided.nativeValue, 42);

      final missing = OptionalValue.missing(type);
      expect(missing.isMissing, isTrue);
      expect(missing.nativeValue, isNull);
    });
  });
}
