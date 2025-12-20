import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('Address <-> AddressValue Extensions', () {
    test('should convert Address to AddressValue', () {
      final address = Address.fromBech32(
        'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
      );
      final addressValue = address.toAddressValue();
      expect(addressValue.value.length, equals(32));
      expect(addressValue.toBech32(), equals(address.bech32));
    });
    test('should convert AddressValue to Address', () {
      final addressValue = AddressValue.fromBech32(
        'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
      );
      final address = addressValue.toAddress();
      expect(address.bech32, equals(addressValue.toBech32()));
      expect(address.bytes, equals(addressValue.value.toList()));
    });
    test('should be bidirectional', () {
      final original = Address.fromBech32(
        'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
      );
      final converted = original.toAddressValue().toAddress();
      expect(converted.bech32, equals(original.bech32));
    });
  });
  group('Nonce <-> U64Value Extensions', () {
    test('should convert Nonce to U64Value', () {
      const nonce = Nonce(42);
      final u64 = nonce.toU64Value();
      expect(u64.value, equals(BigInt.from(42)));
    });
    test('should convert U64Value to Nonce', () {
      final u64 = U64Value(BigInt.from(100));
      final nonce = u64.toNonce();
      expect(nonce.value, equals(100));
    });
    test('should be bidirectional', () {
      const original = Nonce(123);
      final converted = original.toU64Value().toNonce();
      expect(converted.value, equals(original.value));
    });
  });
  group('Balance <-> BigUIntValue Extensions', () {
    test('should convert Balance to BigUIntValue', () {
      final balance = Balance.fromEgld(1.5);
      final bigUint = balance.toBigUIntValue();
      expect(bigUint.value, equals(balance.value));
    });
    test('should convert BigUIntValue to Balance', () {
      final bigUint = BigUIntValue(BigInt.parse('1000000000000000000'));
      final balance = bigUint.toBalance();
      expect(balance.toDenominatedTrimmed, equals('1'));
    });
    test('should preserve denomination', () {
      final original = Balance.fromEgld(2.5);
      final converted = original.toBigUIntValue().toBalance();
      expect(converted.toDenominated, equals(original.toDenominated));
      expect(converted.value, equals(original.value));
    });
  });
  group('GasLimit <-> U64Value Extensions', () {
    test('should convert GasLimit to U64Value', () {
      const gasLimit = GasLimit(50000);
      final u64 = gasLimit.toU64Value();
      expect(u64.value, equals(BigInt.from(50000)));
    });
    test('should convert U64Value to GasLimit', () {
      final u64 = U64Value(BigInt.from(100000));
      final gasLimit = u64.toGasLimit();
      expect(gasLimit.value, equals(100000));
    });
    test('should be bidirectional', () {
      const original = GasLimit(75000);
      final converted = original.toU64Value().toGasLimit();
      expect(converted.value, equals(original.value));
    });
  });
  group('GasPrice <-> U64Value Extensions', () {
    test('should convert GasPrice to U64Value', () {
      const gasPrice = GasPrice(1000000000);
      final u64 = gasPrice.toU64Value();
      expect(u64.value, equals(BigInt.from(1000000000)));
    });
    test('should convert U64Value to GasPrice', () {
      final u64 = U64Value(BigInt.from(1000000000));
      final gasPrice = u64.toGasPrice();
      expect(gasPrice.value, equals(1000000000));
    });
    test('should be bidirectional', () {
      const original = GasPrice(2000000000);
      final converted = original.toU64Value().toGasPrice();
      expect(converted.value, equals(original.value));
    });
  });
}
