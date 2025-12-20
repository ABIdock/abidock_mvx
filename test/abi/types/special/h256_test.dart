import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('H256Type', () {
    test('type_properties', () {
      final type = H256Type.type;
      expect(type.name, 'H256');
      expect(type.sizeInBytes, 32);
      expect(H256Type.hashLength, 32);
    });

    test('createValue_from_bytes', () {
      final type = H256Type.type;
      final bytes = Uint8List(32);
      final value = type.createValue(bytes);
      expect(value, isA<H256Value>());
    });

    test('createValue_from_hex', () {
      final type = H256Type.type;
      final hex = '0' * 64;
      final value = type.createValue(hex);
      expect(value, isA<H256Value>());
    });

    test('createValue_validation_errors', () {
      final type = H256Type.type;
      expect(() => type.createValue(Uint8List(16)), throwsArgumentError);
      expect(() => type.createValue('0' * 32), throwsArgumentError);
    });
  });

  group('H256Value', () {
    test('fromHex_creation', () {
      const hex =
          '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
      final value = H256Value.fromHex(hex);
      expect(value.value.length, 32);
    });

    test('toHex_conversion', () {
      final bytes = Uint8List.fromList(List.generate(32, (i) => i));
      final value = H256Value(bytes);
      final hex = value.toHex();
      expect(hex.length, 64);
    });
  });
}
