import 'package:meta/meta.dart';

import '../../../core/tokens/token.dart';
import '../composite/fields.dart';
import '../composite/struct.dart';
import '../primitives/numerical.dart';
import 'token_identifier.dart';

/// ABI struct type for `EgldOrEsdtTokenPayment`, whose fields encode in the
/// on-wire order `(identifier, nonce, amount)`.
@immutable
final class EgldOrEsdtTokenPaymentType {
  EgldOrEsdtTokenPaymentType._();

  /// Singleton struct type instance.
  static final StructType type = StructType(
    name: 'EgldOrEsdtTokenPayment',
    fieldDefinitions: <FieldDefinition>[
      FieldDefinition(
        name: 'token_identifier',
        type: EgldOrEsdtTokenIdentifierType.type,
      ),
      FieldDefinition(name: 'token_nonce', type: U64Type.type),
      FieldDefinition(name: 'amount', type: BigUIntType.type),
    ],
  );

  /// Builds an ABI `StructValue` from a Dart [EgldOrEsdtTokenPayment] DTO.
  static StructValue toStructValue(EgldOrEsdtTokenPayment payment) {
    final Fields fields = Fields(<Field>[
      Field(
        name: 'token_identifier',
        value: EgldOrEsdtTokenIdentifierValue(payment.tokenIdentifier.value),
      ),
      Field(name: 'token_nonce', value: U64Value(payment.tokenNonce)),
      Field(name: 'amount', value: BigUIntValue(payment.amount)),
    ]);
    return StructValue(type, fields);
  }

  /// Reads back an [EgldOrEsdtTokenPayment] from an ABI `StructValue`.
  static EgldOrEsdtTokenPayment fromStructValue(StructValue value) {
    final EgldOrEsdtTokenIdentifierValue id =
        value.fields.getByName('token_identifier').value
            as EgldOrEsdtTokenIdentifierValue;
    final U64Value nonce =
        value.fields.getByName('token_nonce').value as U64Value;
    final BigUIntValue amount =
        value.fields.getByName('amount').value as BigUIntValue;

    return EgldOrEsdtTokenPayment(
      tokenIdentifier: EgldOrEsdtTokenIdentifier.parse(id.identifier),
      tokenNonce: nonce.value,
      amount: amount.value,
    );
  }
}
