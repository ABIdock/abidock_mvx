/// Tests for the [Token] / [TokenIdentifier] / [EgldOrEsdtTokenIdentifier]
/// DTO surface.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('TokenIdentifier', () {
    test('stores raw identifier string', () {
      const TokenIdentifier id = TokenIdentifier('WEGLD-bd4d79');
      expect(id.value, equals('WEGLD-bd4d79'));
    });

    test('parse accepts canonical TICKER-hexrandom', () {
      final TokenIdentifier id = TokenIdentifier.parse('USDC-c76f1f');
      expect(id.value, equals('USDC-c76f1f'));
    });

    test('value equality on .value', () {
      const TokenIdentifier a = TokenIdentifier('WEGLD-bd4d79');
      const TokenIdentifier b = TokenIdentifier('WEGLD-bd4d79');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('EgldOrEsdtTokenIdentifier', () {
    test('.egld() yields the canonical EGLD-000000 sentinel', () {
      final EgldOrEsdtTokenIdentifier egld = EgldOrEsdtTokenIdentifier.egld();
      expect(egld.value, equals('EGLD-000000'));
    });

    test('accepts a regular ESDT identifier', () {
      const EgldOrEsdtTokenIdentifier id = EgldOrEsdtTokenIdentifier(
        'NFT-abc123',
      );
      expect(id.value, equals('NFT-abc123'));
    });

    test('parse normalises the legacy bare "EGLD" sentinel', () {
      final EgldOrEsdtTokenIdentifier id = EgldOrEsdtTokenIdentifier.parse(
        'EGLD',
      );
      expect(id.value, equals('EGLD-000000'));
    });

    test('parse normalises empty string to EGLD-000000', () {
      final EgldOrEsdtTokenIdentifier id = EgldOrEsdtTokenIdentifier.parse('');
      expect(id.value, equals('EGLD-000000'));
    });
  });

  group('EsdtTokenPayment DTO', () {
    test('constructs a fungible payment with nonce defaulting to zero', () {
      final EsdtTokenPayment p = EsdtTokenPayment(
        tokenIdentifier: const TokenIdentifier('WEGLD-bd4d79'),
        amount: BigInt.from(100),
      );
      expect(p.tokenNonce, equals(BigInt.zero));
      expect(p.amount, equals(BigInt.from(100)));
    });

    test('rejects a negative amount at construction time', () {
      expect(
        () => EsdtTokenPayment(
          tokenIdentifier: const TokenIdentifier('WEGLD-bd4d79'),
          amount: BigInt.from(-1),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects a negative nonce at construction time', () {
      expect(
        () => EsdtTokenPayment(
          tokenIdentifier: const TokenIdentifier('WEGLD-bd4d79'),
          tokenNonce: BigInt.from(-1),
          amount: BigInt.one,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
