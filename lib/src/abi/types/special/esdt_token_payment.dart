import 'package:meta/meta.dart';

import '../../../core/tokens/token.dart';
import '../composite/fields.dart';
import '../composite/struct.dart';
import '../primitives/numerical.dart';
import 'token_identifier.dart';

/// ABI struct type for `EsdtTokenPayment`, whose fields encode in the on-wire
/// order `(identifier, nonce, amount)`.
///
/// Use [EsdtTokenPaymentType.type] when defining contract ABIs by hand or
/// when you need to encode/decode `EsdtTokenPayment` values through the
/// generic struct codec.
@immutable
final class EsdtTokenPaymentType {
  EsdtTokenPaymentType._();

  /// Singleton struct type instance.
  static final StructType type = StructType(
    name: 'EsdtTokenPayment',
    fieldDefinitions: <FieldDefinition>[
      FieldDefinition(name: 'token_identifier', type: TokenIdentifierType.type),
      FieldDefinition(name: 'token_nonce', type: U64Type.type),
      FieldDefinition(name: 'amount', type: BigUIntType.type),
    ],
  );

  /// Builds an ABI `StructValue` from a Dart [EsdtTokenPayment] DTO.
  static StructValue toStructValue(EsdtTokenPayment payment) {
    final Fields fields = Fields(<Field>[
      Field(
        name: 'token_identifier',
        value: TokenIdentifierValue(payment.tokenIdentifier.value),
      ),
      Field(name: 'token_nonce', value: U64Value(payment.tokenNonce)),
      Field(name: 'amount', value: BigUIntValue(payment.amount)),
    ]);
    return StructValue(type, fields);
  }

  /// Reads back an [EsdtTokenPayment] from an ABI `StructValue`.
  static EsdtTokenPayment fromStructValue(StructValue value) {
    final TokenIdentifierValue id =
        value.fields.getByName('token_identifier').value
            as TokenIdentifierValue;
    final U64Value nonce =
        value.fields.getByName('token_nonce').value as U64Value;
    final BigUIntValue amount =
        value.fields.getByName('amount').value as BigUIntValue;

    return EsdtTokenPayment(
      tokenIdentifier: TokenIdentifier(id.identifier),
      tokenNonce: nonce.value,
      amount: amount.value,
    );
  }
}
