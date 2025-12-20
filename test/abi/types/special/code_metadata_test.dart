import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('CodeMetadataType', () {
    test('should create and validate type properties', () {
      final type = CodeMetadataType.type;
      expect(type.name, 'CodeMetadata');
      expect(type.sizeInBytes, 2);

      final value = type.createValue(0x0001);
      expect(value.flags, 0x0001);

      final valueFromBytes = type.createValue([0x00, 0x01]);
      expect(valueFromBytes.flags, 0x0001);

      expect(() => type.createValue([0x01]), throwsArgumentError);
      expect(() => type.createValue('invalid'), throwsArgumentError);
    });
  });

  group('CodeMetadataValue', () {
    test('should create with flags and validate ranges', () {
      final value = CodeMetadataValue(0x0506);
      expect(value.flags, 0x0506);
      expect(value.nativeValue, 0x0506);

      expect(() => CodeMetadataValue(-1), throwsArgumentError);
      expect(() => CodeMetadataValue(0x10000), throwsArgumentError);
    });

    test('should check flag constants and properties', () {
      // Flag constants match MultiversX ABI spec (big-endian 16-bit layout)
      // See: https://docs.multiversx.com/developers/data/code-metadata/#bit-flag-layout
      expect(CodeMetadataValue.upgradeableFlag, 0x0100); // LSB of first byte
      expect(CodeMetadataValue.readableFlag, 0x0400); // 3rd LSB of first byte
      expect(CodeMetadataValue.payableFlag, 0x0002); // 2nd LSB of second byte
      expect(
        CodeMetadataValue.payableBySCFlag,
        0x0004,
      ); // 3rd LSB of second byte

      const allFlags =
          CodeMetadataValue.upgradeableFlag |
          CodeMetadataValue.readableFlag |
          CodeMetadataValue.payableFlag |
          CodeMetadataValue.payableBySCFlag;
      final value = CodeMetadataValue(allFlags);

      expect(value.isUpgradeable, isTrue);
      expect(value.isReadable, isTrue);
      expect(value.isPayable, isTrue);
      expect(value.isPayableBySC, isTrue);
    });

    test('should encode to bytes with big endian format', () {
      final value = CodeMetadataValue(0x0102);
      final bytes = value.toBytes();

      expect(bytes, hasLength(2));
      expect(bytes[0], 0x01);
      expect(bytes[1], 0x02);

      final type = CodeMetadataType.type;
      final restored = type.createValue(bytes);
      expect(restored.flags, value.flags);
    });

    test('should format flags in toString representation', () {
      final zeroValue = CodeMetadataValue(0);
      expect(zeroValue.toString(), 'CodeMetadata()');

      const allFlags =
          CodeMetadataValue.upgradeableFlag |
          CodeMetadataValue.readableFlag |
          CodeMetadataValue.payableFlag |
          CodeMetadataValue.payableBySCFlag;
      final value = CodeMetadataValue(allFlags);
      final str = value.toString();

      expect(str, contains('upgradeable'));
      expect(str, contains('readable'));
      expect(str, contains('payable'));
      expect(str, contains('payable-by-sc'));
    });
  });
}
