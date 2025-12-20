import 'package:abidock_mvx/abidock_mvx.dart';

/// SwapEvent model.
class SwapEvent {
  const SwapEvent({
    required this.caller,
    required this.tokenIdIn,
    required this.tokenAmountIn,
    required this.tokenIdOut,
    required this.tokenAmountOut,
    required this.feeAmount,
    required this.tokenInReserve,
    required this.tokenOutReserve,
    required this.block,
    required this.epoch,
    required this.timestamp,
  });

  final String caller;
  final String tokenIdIn;
  final BigInt tokenAmountIn;
  final String tokenIdOut;
  final BigInt tokenAmountOut;
  final BigInt feeAmount;
  final BigInt tokenInReserve;
  final BigInt tokenOutReserve;
  final BigInt block;
  final BigInt epoch;
  final BigInt timestamp;

  static final type = StructType(
    name: 'SwapEvent',
    fieldDefinitions: [
      FieldDefinition(name: 'caller', type: AddressType.type),
      FieldDefinition(name: 'token_id_in', type: TokenIdentifierType.type),
      FieldDefinition(name: 'token_amount_in', type: BigUIntType.type),
      FieldDefinition(name: 'token_id_out', type: TokenIdentifierType.type),
      FieldDefinition(name: 'token_amount_out', type: BigUIntType.type),
      FieldDefinition(name: 'fee_amount', type: BigUIntType.type),
      FieldDefinition(name: 'token_in_reserve', type: BigUIntType.type),
      FieldDefinition(name: 'token_out_reserve', type: BigUIntType.type),
      FieldDefinition(name: 'block', type: U64Type.type),
      FieldDefinition(name: 'epoch', type: U64Type.type),
      FieldDefinition(name: 'timestamp', type: U64Type.type),
    ],
  );

  factory SwapEvent.fromAbi(TypedValue value) {
    final struct = value as StructValue;
    return SwapEvent(
      caller: infer<String>(struct.getFieldValue('caller').nativeValue),
      tokenIdIn: infer<String>(struct.getFieldValue('token_id_in').nativeValue),
      tokenAmountIn: infer<BigInt>(
        struct.getFieldValue('token_amount_in').nativeValue,
      ),
      tokenIdOut: infer<String>(
        struct.getFieldValue('token_id_out').nativeValue,
      ),
      tokenAmountOut: infer<BigInt>(
        struct.getFieldValue('token_amount_out').nativeValue,
      ),
      feeAmount: infer<BigInt>(struct.getFieldValue('fee_amount').nativeValue),
      tokenInReserve: infer<BigInt>(
        struct.getFieldValue('token_in_reserve').nativeValue,
      ),
      tokenOutReserve: infer<BigInt>(
        struct.getFieldValue('token_out_reserve').nativeValue,
      ),
      block: infer<BigInt>(struct.getFieldValue('block').nativeValue),
      epoch: infer<BigInt>(struct.getFieldValue('epoch').nativeValue),
      timestamp: infer<BigInt>(struct.getFieldValue('timestamp').nativeValue),
    );
  }

  TypedValue toAbi() {
    return type.createValue({
      'caller': caller,
      'token_id_in': tokenIdIn,
      'token_amount_in': tokenAmountIn,
      'token_id_out': tokenIdOut,
      'token_amount_out': tokenAmountOut,
      'fee_amount': feeAmount,
      'token_in_reserve': tokenInReserve,
      'token_out_reserve': tokenOutReserve,
      'block': block,
      'epoch': epoch,
      'timestamp': timestamp,
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'caller': caller,
      'token_id_in': tokenIdIn,
      'token_amount_in': tokenAmountIn,
      'token_id_out': tokenIdOut,
      'token_amount_out': tokenAmountOut,
      'fee_amount': feeAmount,
      'token_in_reserve': tokenInReserve,
      'token_out_reserve': tokenOutReserve,
      'block': block,
      'epoch': epoch,
      'timestamp': timestamp,
    };
  }
}
