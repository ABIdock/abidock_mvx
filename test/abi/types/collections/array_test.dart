import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('ArrayType', () {
    test('creates instance with size and element type', () {
      final arrayType = ArrayType(U32Type.type, 5);
      expect(arrayType.name, contains('Array'));
    });
    test('has element type', () {
      final arrayType = ArrayType(U32Type.type, 3);
      expect(arrayType.elementType, equals(U32Type.type));
    });
  });
  group('ArrayValue', () {
    test('creates from list with exact size', () {
      final arrayType = ArrayType(U32Type.type, 3);
      final value = arrayType.createValue([100, 200, 300]);
      expect(value.nativeValue, isA<List>());
      expect(value.nativeValue.length, 3);
    });
    test('preserves element values', () {
      final arrayType = ArrayType(U32Type.type, 4);
      final input = [10, 20, 30, 40];
      final value = arrayType.createValue(input);
      expect(value.nativeValue.length, input.length);
    });
    test('toBytes encoding', () {
      final arrayType = ArrayType(U32Type.type, 2);
      final value = arrayType.createValue([1, 2]);
      final bytes = value.toBytes();
      expect(bytes, isA<List<int>>());
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
