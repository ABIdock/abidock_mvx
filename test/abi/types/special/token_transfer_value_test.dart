import 'package:abidock_mvx/src/abi/types/primitives/numerical.dart';
import 'package:abidock_mvx/src/abi/types/special/token_identifier.dart';
import 'package:abidock_mvx/src/abi/types/special/token_transfer_value.dart';
import 'package:test/test.dart';

void main() {
  group('TokenTransferValue', () {
    group('constructor', () {
      test('creates fungible token transfer', () {
        final transfer = TokenTransferValue(
          tokenIdentifier: EgldOrEsdtTokenIdentifierValue('MYTOKEN-a1b2c3'),
          amount: BigUIntValue(BigInt.from(1000)),
        );
        expect(transfer.tokenIdentifier.identifier, equals('MYTOKEN-a1b2c3'));
        expect(transfer.amount.value, equals(BigInt.from(1000)));
        expect(transfer.nonce, isNull);
        expect(transfer.isFungible, isTrue);
        expect(transfer.isNft, isFalse);
      });

      test('creates NFT transfer with nonce', () {
        final transfer = TokenTransferValue(
          tokenIdentifier: EgldOrEsdtTokenIdentifierValue('MYNFT-a1b2c3'),
          amount: BigUIntValue(BigInt.one),
          nonce: U64Value(BigInt.from(42)),
        );
        expect(transfer.nonce, isNotNull);
        expect(transfer.nonce!.value, equals(BigInt.from(42)));
        expect(transfer.isFungible, isFalse);
        expect(transfer.isNft, isTrue);
      });

      test('throws on empty token identifier', () {
        expect(
          () => TokenTransferValue(
            tokenIdentifier: EgldOrEsdtTokenIdentifierValue(''),
            amount: BigUIntValue(BigInt.from(100)),
          ),
          throwsArgumentError,
        );
      });

      test('throws on negative amount', () {
        expect(
          () => TokenTransferValue(
            tokenIdentifier: EgldOrEsdtTokenIdentifierValue('TOKEN-abc123'),
            amount: BigUIntValue(BigInt.from(-1)),
          ),
          throwsArgumentError,
        );
      });

      test('throws on zero nonce', () {
        expect(
          () => TokenTransferValue(
            tokenIdentifier: EgldOrEsdtTokenIdentifierValue('TOKEN-abc123'),
            amount: BigUIntValue(BigInt.from(100)),
            nonce: U64Value(BigInt.zero),
          ),
          throwsArgumentError,
        );
      });
    });

    group('fromPrimitives', () {
      test('creates from string and BigInt', () {
        final transfer = TokenTransferValue.fromPrimitives(
          tokenIdentifier: 'WEGLD-abc123',
          amount: BigInt.from(5000000000000000000),
        );
        expect(transfer.tokenIdentifier.identifier, equals('WEGLD-abc123'));
        expect(transfer.amount.value, equals(BigInt.from(5000000000000000000)));
      });

      test('creates NFT from primitives', () {
        final transfer = TokenTransferValue.fromPrimitives(
          tokenIdentifier: 'LKMEX-abc123',
          amount: BigInt.one,
          nonce: BigInt.from(100),
        );
        expect(transfer.isNft, isTrue);
        expect(transfer.nonce!.value, equals(BigInt.from(100)));
      });

      test('throws on empty identifier', () {
        expect(
          () => TokenTransferValue.fromPrimitives(
            tokenIdentifier: '',
            amount: BigInt.from(100),
          ),
          throwsArgumentError,
        );
      });

      test('throws on negative amount', () {
        expect(
          () => TokenTransferValue.fromPrimitives(
            tokenIdentifier: 'TOKEN-abc123',
            amount: BigInt.from(-100),
          ),
          throwsArgumentError,
        );
      });

      test('throws on zero nonce', () {
        expect(
          () => TokenTransferValue.fromPrimitives(
            tokenIdentifier: 'TOKEN-abc123',
            amount: BigInt.from(100),
            nonce: BigInt.zero,
          ),
          throwsArgumentError,
        );
      });
    });

    group('properties', () {
      test('isEgld returns true for EGLD', () {
        final transfer = TokenTransferValue.fromPrimitives(
          tokenIdentifier: 'EGLD',
          amount: BigInt.from(1000000000000000000),
        );
        expect(transfer.isEgld, isTrue);
      });

      test('isEgld returns false for ESDT', () {
        final transfer = TokenTransferValue.fromPrimitives(
          tokenIdentifier: 'USDC-abc123',
          amount: BigInt.from(1000000),
        );
        expect(transfer.isEgld, isFalse);
      });

      test('handles large amounts', () {
        final largeAmount = BigInt.parse('999999999999999999999999999999');
        final transfer = TokenTransferValue.fromPrimitives(
          tokenIdentifier: 'TOKEN-abc123',
          amount: largeAmount,
        );
        expect(transfer.amount.value, equals(largeAmount));
      });

      test('handles zero amount', () {
        final transfer = TokenTransferValue.fromPrimitives(
          tokenIdentifier: 'TOKEN-abc123',
          amount: BigInt.zero,
        );
        expect(transfer.amount.value, equals(BigInt.zero));
      });
    });
  });

  group('EgldOrEsdtTokenIdentifierValue', () {
    test('creates EGLD identifier', () {
      final id = EgldOrEsdtTokenIdentifierValue('EGLD');
      expect(id.identifier, equals('EGLD'));
      expect(id.isEgld, isTrue);
    });

    test('creates ESDT identifier', () {
      final id = EgldOrEsdtTokenIdentifierValue('USDC-c76f1f');
      expect(id.identifier, equals('USDC-c76f1f'));
      expect(id.isEgld, isFalse);
    });

    test('handles various token formats', () {
      final tokens = [
        'WEGLD-bd4d79',
        'USDC-c76f1f',
        'MEX-455c57',
        'LKMEX-aab910',
        'RIDE-7d18e9',
      ];
      for (final token in tokens) {
        final id = EgldOrEsdtTokenIdentifierValue(token);
        expect(id.identifier, equals(token));
        expect(id.isEgld, isFalse);
      }
    });
  });

  group('TokenTransferType', () {
    test('type name is correct', () {
      expect(TokenTransferType.type.name, equals('TokenTransfer'));
    });
  });
}
