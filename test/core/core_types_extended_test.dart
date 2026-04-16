import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('Address HRP semantics', () {
    test('equality distinguishes addresses by HRP', () {
      final bytes = List<int>.filled(32, 0);
      final erd = Address(bytes, hrp: 'erd');
      final testErd = Address(bytes, hrp: 'test');
      expect(erd == testErd, isFalse);
      expect(erd.hashCode == testErd.hashCode, isFalse);
    });

    test('fromHex rejects wrong length', () {
      expect(() => Address.fromHex('00' * 16), throwsFormatException);
    });

    test('fromHex accepts 32 bytes', () {
      final addr = Address.fromHex('00' * 32);
      expect(addr.bytes.length, 32);
    });

    test('computeContractAddress propagates deployer HRP', () {
      final deployer = Address(List<int>.filled(32, 0x11), hrp: 'custom');
      final contract = AddressComputer.computeContractAddress(
        deployer,
        const Nonce(42),
      );
      expect(contract.hrp, 'custom');
      expect(contract.isSmartContract, isTrue);
    });

    test('isSmartContract detects contract prefix', () {
      final bytes = List<int>.filled(32, 0);
      bytes[8] = 0x05;
      bytes[9] = 0x00;
      expect(Address(bytes).isSmartContract, isTrue);
    });
  });

  group('Balance extended operators', () {
    test('scalar multiplication', () {
      final result = Balance(BigInt.from(10)) * BigInt.from(5);
      expect(result.value, BigInt.from(50));
    });

    test('scalar multiplication rejects negative', () {
      expect(
        () => Balance(BigInt.from(10)) * BigInt.from(-1),
        throwsArgumentError,
      );
    });

    test('integer division', () {
      final result = Balance(BigInt.from(100)) ~/ BigInt.from(3);
      expect(result.value, BigInt.from(33));
    });

    test('integer division rejects zero and negative', () {
      final balance = Balance(BigInt.from(100));
      expect(() => balance ~/ BigInt.zero, throwsArgumentError);
      expect(() => balance ~/ BigInt.from(-1), throwsArgumentError);
    });

    test('modulo', () {
      final result = Balance(BigInt.from(100)) % BigInt.from(7);
      expect(result.value, BigInt.from(2));
    });

    test('ratioTo computes integer ratio', () {
      final a = Balance(BigInt.from(1000));
      final b = Balance(BigInt.from(3));
      expect(a.ratioTo(b), BigInt.from(333));
    });

    test('ratioTo rejects zero denominator', () {
      expect(
        () => Balance(BigInt.from(100)).ratioTo(Balance.zero()),
        throwsArgumentError,
      );
    });

    test('fromEgld handles rounding via toStringAsFixed', () {
      final balance = Balance.fromEgld(1.5);
      expect(balance.value, BigInt.parse('1500000000000000000'));
    });
  });

  group('Nonce edge cases', () {
    test('+ reroutes negative through subtraction', () {
      const nonce = Nonce(5);
      expect((nonce + -3).value, 2);
    });

    test('- throws when result would be negative', () {
      expect(() => const Nonce(1) - 5, throwsArgumentError);
    });
  });

  group('Signature length validation', () {
    test('fromBytes rejects non-64-byte non-empty input', () {
      expect(
        () => Signature.fromBytes(List<int>.filled(32, 0)),
        throwsArgumentError,
      );
    });

    test('fromBytes accepts empty list', () {
      final sig = Signature.fromBytes(<int>[]);
      expect(sig.isEmpty, isTrue);
    });

    test('fromBytes accepts 64-byte signature', () {
      final sig = Signature.fromBytes(List<int>.filled(64, 0xab));
      expect(sig.bytes.length, 64);
    });

    test('fromUint8List enforces same rule', () {
      expect(() => Signature.fromUint8List(Uint8List(10)), throwsArgumentError);
      final sig = Signature.fromUint8List(Uint8List(64));
      expect(sig.bytes.length, 64);
    });
  });

  group('Transaction defensive copy', () {
    test('data getter returns copy', () {
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);
      final tx = Transaction(
        nonce: const Nonce(0),
        sender: Address.zero(),
        receiver: Address.zero(),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1_000_000_000),
        chainId: const ChainId('D'),
        version: const TransactionVersion(2),
        data: bytes,
      );

      final first = tx.data;
      first[0] = 99;
      expect(tx.data[0], 1);
    });
  });
}
