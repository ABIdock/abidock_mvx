/// Tests for [EsdtTokenPaymentType] StructValue round-trip + field order.
///
/// The struct's fields encode in the order
/// `(token_identifier, token_nonce, amount)`. Any reordering silently
/// misdecodes payments returned by NFT/DEX/marketplace contracts.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('EsdtTokenPaymentType', () {
    test('struct fields are in canonical wire order', () {
      final List<String> names = EsdtTokenPaymentType.type.fieldDefinitions
          .map((FieldDefinition f) => f.name)
          .toList();
      expect(
        names,
        orderedEquals(<String>['token_identifier', 'token_nonce', 'amount']),
      );
    });

    test(
      'round-trips a fungible payment via toStructValue/fromStructValue',
      () {
        final EsdtTokenPayment original = EsdtTokenPayment(
          tokenIdentifier: const TokenIdentifier('WEGLD-bd4d79'),
          tokenNonce: BigInt.zero,
          amount: BigInt.from(1000000000000000000),
        );
        final StructValue struct = EsdtTokenPaymentType.toStructValue(original);
        final EsdtTokenPayment back = EsdtTokenPaymentType.fromStructValue(
          struct,
        );
        expect(
          back.tokenIdentifier.value,
          equals(original.tokenIdentifier.value),
        );
        expect(back.tokenNonce, equals(original.tokenNonce));
        expect(back.amount, equals(original.amount));
      },
    );

    test('round-trips an NFT payment (nonce > 0)', () {
      final EsdtTokenPayment nft = EsdtTokenPayment(
        tokenIdentifier: const TokenIdentifier('MEDIA-fa4d1c'),
        tokenNonce: BigInt.from(42),
        amount: BigInt.one,
      );
      final StructValue struct = EsdtTokenPaymentType.toStructValue(nft);
      final EsdtTokenPayment back = EsdtTokenPaymentType.fromStructValue(
        struct,
      );
      expect(back.tokenIdentifier.value, equals('MEDIA-fa4d1c'));
      expect(back.tokenNonce, equals(BigInt.from(42)));
      expect(back.amount, equals(BigInt.one));
    });
  });
}
