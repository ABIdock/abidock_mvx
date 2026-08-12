import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('ManagedByteArrayType', () {
    test('name uses the canonical ABI form with metadata', () {
      final type = ManagedByteArrayType(48);
      expect(type.name, 'ManagedByteArray');
      expect(type.length, 48);
      expect(type.sizeInBytes, 48);
      expect(type.fullyQualifiedName, 'multiversx:types:ManagedByteArray*48*');
    });

    test('createValue rejects wrong length', () {
      final type = ManagedByteArrayType(48);
      expect(() => type.createValue(Uint8List(32)), throwsArgumentError);
      expect(() => type.createValue('00' * 32), throwsArgumentError);
    });

    test('round-trip N=32 (no length prefix)', () {
      final BinaryCodec codec = BinaryCodec.withDefaults();
      final type = ManagedByteArrayType(32);
      final Uint8List input = Uint8List.fromList(List.generate(32, (i) => i));
      final ManagedByteArrayValue value = type.createValue(input);

      final Uint8List nested = codec.encodeNested(value);
      expect(nested.length, 32);
      expect(nested, input);

      final Uint8List top = codec.encodeTopLevel(value);
      expect(top.length, 32);
      expect(top, input);

      final (decoded, consumed) = codec.decodeNested(nested, type, 0);
      expect(consumed, 32);
      expect((decoded as ManagedByteArrayValue).value, input);

      final ManagedByteArrayValue decodedTop =
          codec.decodeTopLevel(top, type) as ManagedByteArrayValue;
      expect(decodedTop.value, input);
    });

    test('round-trip N=48 and N=96 (arbitrary lengths)', () {
      final BinaryCodec codec = BinaryCodec.withDefaults();
      for (final int n in const <int>[48, 96]) {
        final type = ManagedByteArrayType(n);
        final Uint8List input = Uint8List.fromList(
          List.generate(n, (i) => (i * 7) & 0xFF),
        );
        final ManagedByteArrayValue value = type.createValue(input);
        final Uint8List nested = codec.encodeNested(value);
        expect(nested.length, n);
        final (decoded, consumed) = codec.decodeNested(nested, type, 0);
        expect(consumed, n);
        expect((decoded as ManagedByteArrayValue).value, input);
      }
    });

    test('factory resolves array32<u8>, array48<u8>, array96<u8>', () {
      final AbiTypeFactory factory = AbiTypeFactory();
      expect(
        factory.fromString('array32<u8>'),
        isA<ManagedByteArrayType>().having((t) => t.length, 'length', 32),
      );
      expect(
        factory.fromString('array48<u8>'),
        isA<ManagedByteArrayType>().having((t) => t.length, 'length', 48),
      );
      expect(
        factory.fromString('array96<u8>'),
        isA<ManagedByteArrayType>().having((t) => t.length, 'length', 96),
      );
    });

    test('factory resolves ManagedByteArray*48*', () {
      final AbiTypeFactory factory = AbiTypeFactory();
      final AbiType resolved = factory.fromString('ManagedByteArray*48*');
      expect(resolved, isA<ManagedByteArrayType>());
      expect((resolved as ManagedByteArrayType).length, 48);
    });
  });
}
