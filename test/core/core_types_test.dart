import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('Address', () {
    test('creates from different formats', () {
      final bech32Address = Address.fromBech32(
        'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
      );
      expect(bech32Address.bech32.length, 62);
      expect(bech32Address.bech32, startsWith('erd1'));

      final hexAddress = Address.fromHex('0' * 64);
      expect(hexAddress, isNotNull);

      final zeroAddress = Address.zero();
      expect(zeroAddress.bech32, startsWith('erd1qqqqqqqqqqqq'));
    });

    test('preserves address data', () {
      const original =
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8';
      final address = Address.fromBech32(original);
      expect(address.bech32, original);
    });
  });

  group('Balance', () {
    test('creates and handles different values', () {
      final egldBalance = Balance.fromEgld(1.5);
      expect(egldBalance.value, BigInt.from(1500000000000000000));
      expect(egldBalance.toString(), isNotEmpty);

      final zeroBalance = Balance.zero();
      expect(zeroBalance.value, BigInt.zero);

      final bigIntBalance = Balance(BigInt.from(1000000));
      expect(bigIntBalance.value, BigInt.from(1000000));

      final largeBalance = Balance(BigInt.from(1000000000000000000));
      expect(largeBalance.value, BigInt.from(1000000000000000000));
    });

    test('fromString throws on invalid input', () {
      expect(() => Balance.fromString(''), throwsFormatException);
      expect(() => Balance.fromString('abc'), throwsFormatException);
      expect(() => Balance.fromString('12.34.56'), throwsFormatException);
      expect(() => Balance.fromString('not_a_number'), throwsFormatException);
      expect(() => Balance.fromString('  '), throwsFormatException);
      expect(() => Balance.fromString('123abc'), throwsFormatException);
      expect(() => Balance.fromString('-'), throwsFormatException);
      expect(() => Balance.fromString('+'), throwsFormatException);
      expect(() => Balance.fromString('12.34'), throwsFormatException);
      expect(() => Balance.fromString('1,000'), throwsFormatException);
    });

    test('fromString handles valid edge cases', () {
      expect(Balance.fromString('0').value, BigInt.zero);
      expect(Balance.fromString('1').value, BigInt.one);
      expect(
        Balance.fromString('999999999999999999999999999999').value,
        BigInt.parse('999999999999999999999999999999'),
      );
    });

    test('fromEgldString throws on invalid input', () {
      expect(() => Balance.fromEgldString(''), throwsFormatException);
      expect(() => Balance.fromEgldString('abc'), throwsFormatException);
      expect(() => Balance.fromEgldString('1.2.3'), throwsFormatException);
    });

    test('fromEgldString handles valid edge cases', () {
      expect(Balance.fromEgldString('0').value, BigInt.zero);
      expect(Balance.fromEgldString('0.0').value, BigInt.zero);
      expect(Balance.fromEgldString('0.000000000000000001').value, BigInt.one);
      expect(
        Balance.fromEgldString('.5').value,
        BigInt.parse('500000000000000000'),
      );
    });
  });

  group('Nonce', () {
    test('creates and handles nonce values', () {
      const nonce = Nonce(42);
      expect(nonce.value, 42);

      const zero = Nonce(0);
      expect(zero.value, 0);

      const large = Nonce(999999);
      expect(large.value, 999999);
    });

    test('increment works correctly', () {
      const nonce = Nonce(5);
      final next = nonce.increment();
      expect(next.value, 6);
      expect(nonce.value, 5);
    });
  });

  group('Signature', () {
    test('creates and handles signature data', () {
      final bytes = Uint8List(64);
      final sig = Signature.fromUint8List(bytes);
      expect(sig.hex.length, 128);

      const empty = Signature.empty();
      expect(empty.hex, isEmpty);

      final filledBytes = Uint8List.fromList(List.filled(64, 170));
      final filledSig = Signature.fromUint8List(filledBytes);
      expect(filledSig.hex, isNotEmpty);
      expect(filledSig.hex.length, 128);
    });
  });
}
