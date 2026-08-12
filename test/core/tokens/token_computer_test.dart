/// Tests for [TokenComputer] — extended-identifier parsing + composition.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  const TokenComputer computer = TokenComputer();

  group('TokenComputer.isFungible', () {
    test('true when nonce is zero', () {
      expect(computer.isFungible(Token(identifier: 'WEGLD-bd4d79')), isTrue);
    });

    test('false when nonce is positive', () {
      final Token t = Token(identifier: 'NFT-abcdef', nonce: BigInt.from(7));
      expect(computer.isFungible(t), isFalse);
    });
  });

  group('TokenComputer.extractNonceFromExtendedIdentifier', () {
    test('returns 0 for bare identifier', () {
      expect(
        computer.extractNonceFromExtendedIdentifier('WEGLD-bd4d79'),
        equals(0),
      );
    });

    test('decodes hex nonce from extended identifier', () {
      expect(
        computer.extractNonceFromExtendedIdentifier('NFT-abcdef-0a'),
        equals(10),
      );
    });

    test('decodes multi-byte hex nonce', () {
      expect(
        computer.extractNonceFromExtendedIdentifier('NFT-abcdef-012a'),
        equals(298),
      );
    });
  });

  group('TokenComputer.extractIdentifierFromExtendedIdentifier', () {
    test('drops the trailing nonce part', () {
      expect(
        computer.extractIdentifierFromExtendedIdentifier('NFT-abcdef-0a'),
        equals('NFT-abcdef'),
      );
    });

    test('returns input unchanged when no nonce', () {
      expect(
        computer.extractIdentifierFromExtendedIdentifier('WEGLD-bd4d79'),
        equals('WEGLD-bd4d79'),
      );
    });
  });

  group('TokenComputer.extractTickerFromExtendedIdentifier', () {
    test('returns ticker only', () {
      expect(
        computer.extractTickerFromExtendedIdentifier('NFT-abcdef-0a'),
        equals('NFT'),
      );
    });
  });

  group('TokenComputer.computeExtendedIdentifier', () {
    test('returns bare identifier when fungible', () {
      final Token t = Token(identifier: 'WEGLD-bd4d79');
      expect(computer.computeExtendedIdentifier(t), equals('WEGLD-bd4d79'));
    });

    test('appends hex nonce when non-fungible', () {
      final Token t = Token(identifier: 'NFT-abcdef', nonce: BigInt.from(10));
      expect(computer.computeExtendedIdentifier(t), equals('NFT-abcdef-0a'));
    });

    test('zero-pads single-digit hex nonces to even length', () {
      final Token t = Token(identifier: 'NFT-abcdef', nonce: BigInt.from(5));
      expect(computer.computeExtendedIdentifier(t), equals('NFT-abcdef-05'));
    });
  });
}
