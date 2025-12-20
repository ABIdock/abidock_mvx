import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('BytesType', () {
    test('works as singleton with correct name', () {
      final type1 = BytesType.type;
      final type2 = BytesType.type;
      expect(identical(type1, type2), isTrue);
      expect(BytesType.type.name, 'bytes');
    });
  });

  group('BytesValue', () {
    test('creates and handles byte arrays correctly', () {
      final bytes = [1, 2, 3, 4, 5];
      final value = BytesType.create(bytes);
      expect(value.nativeValue, bytes);
      expect(value.toBytes(), bytes);

      final largeArray = List.generate(1000, (i) => i % 256);
      final largeValue = BytesType.create(largeArray);
      expect(largeValue.nativeValue.length, 1000);
      expect(largeValue.nativeValue, largeArray);
    });

    test('value equality works correctly', () {
      final value1 = BytesType.create([1, 2, 3]);
      final value2 = BytesType.create([1, 2, 3]);
      final value3 = BytesType.create([4, 5, 6]);
      expect(value1.nativeValue, value2.nativeValue);
      expect(value1.nativeValue, isNot(value3.nativeValue));
    });
  });
}
