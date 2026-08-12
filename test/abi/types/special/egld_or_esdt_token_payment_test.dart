/// Tests for [EgldOrEsdtTokenPaymentType] StructValue round-trip + field order.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('EgldOrEsdtTokenPaymentType', () {
    test('struct fields are in canonical wire order', () {
      final List<String> names = EgldOrEsdtTokenPaymentType
          .type
          .fieldDefinitions
          .map((FieldDefinition f) => f.name)
          .toList();
      expect(
        names,
        orderedEquals(<String>['token_identifier', 'token_nonce', 'amount']),
      );
    });

    test('round-trips a native EGLD payment', () {
      final EgldOrEsdtTokenPayment original = EgldOrEsdtTokenPayment(
        tokenIdentifier: EgldOrEsdtTokenIdentifier.egld(),
        tokenNonce: BigInt.zero,
        amount: BigInt.from(5000000000000000000),
      );
      final StructValue struct = EgldOrEsdtTokenPaymentType.toStructValue(
        original,
      );
      final EgldOrEsdtTokenPayment back =
          EgldOrEsdtTokenPaymentType.fromStructValue(struct);
      expect(back.tokenIdentifier.value, equals('EGLD-000000'));
      expect(back.tokenNonce, equals(BigInt.zero));
      expect(back.amount, equals(original.amount));
    });

    test('round-trips an ESDT payment with nonce', () {
      final EgldOrEsdtTokenPayment payment = EgldOrEsdtTokenPayment(
        tokenIdentifier: const EgldOrEsdtTokenIdentifier('NFT-123456'),
        tokenNonce: BigInt.from(7),
        amount: BigInt.one,
      );
      final StructValue struct = EgldOrEsdtTokenPaymentType.toStructValue(
        payment,
      );
      final EgldOrEsdtTokenPayment back =
          EgldOrEsdtTokenPaymentType.fromStructValue(struct);
      expect(back.tokenIdentifier.value, equals('NFT-123456'));
      expect(back.tokenNonce, equals(BigInt.from(7)));
      expect(back.amount, equals(BigInt.one));
    });
  });
}
