import 'package:abidock_mvx/abidock_mvx.dart';

/// TokenPair model.
class TokenPair {
  const TokenPair({required this.firstToken, required this.secondToken});

  final String firstToken;
  final String secondToken;

  static final type = StructType(
    name: 'TokenPair',
    fieldDefinitions: [
      FieldDefinition(name: 'first_token', type: TokenIdentifierType.type),
      FieldDefinition(name: 'second_token', type: TokenIdentifierType.type),
    ],
  );

  factory TokenPair.fromAbi(TypedValue value) {
    final struct = value as StructValue;
    return TokenPair(
      firstToken: infer<String>(
        struct.getFieldValue('first_token').nativeValue,
      ),
      secondToken: infer<String>(
        struct.getFieldValue('second_token').nativeValue,
      ),
    );
  }

  TypedValue toAbi() {
    return type.createValue({
      'first_token': firstToken,
      'second_token': secondToken,
    });
  }

  Map<String, dynamic> toJson() {
    return {'first_token': firstToken, 'second_token': secondToken};
  }
}
