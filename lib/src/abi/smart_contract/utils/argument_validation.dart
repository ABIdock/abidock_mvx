/// Shared argument validation utilities for smart contract operations.
/// Validates raw arguments (TypedValue/Uint8List) when ABI is not available.

import 'dart:typed_data';

import '../../../utils/hex_utils.dart';
import '../../core/core_types.dart';
import '../../core/type_system.dart';
import '../../serializers/arg_serializer.dart';
import '../../types/special/token_transfer_value.dart';

/// Validates and encodes raw arguments for smart contract operations.
///
/// Used by both [SmartContractCallFactory] and [SmartContractQueryRunner]
/// when operating without an ABI definition.
///
/// #### Example
/// ```dart
/// final validator = RawArgumentValidator(ArgSerializer());
///
/// // Encode TypedValue arguments
/// final encoded = validator.encodeRawArguments([
///   BigUIntValue(BigInt.from(100)),
///   AddressValue.fromBech32('erd1...'),
/// ]);
/// ```
class RawArgumentValidator {
  /// Creates a raw argument validator with the specified serializer.
  const RawArgumentValidator(this._serializer);

  final ArgSerializer _serializer;

  /// Encodes raw arguments to hex strings for transaction/query data.
  ///
  /// Arguments must be either:
  /// - [TypedValue] instances (will be serialized)
  /// - [Uint8List] buffers (will be hex-encoded)
  ///
  /// #### Parameters
  /// - `arguments` - List of arguments to encode
  /// - `context` - Context string for error messages (e.g., 'query', 'call')
  ///
  /// #### Returns
  /// `List<String>` - Hex-encoded argument strings
  ///
  /// #### Throws
  /// - [ArgumentEncodingException] if arguments are invalid types
  List<String> encodeRawArguments(
    List<dynamic> arguments, {
    String context = 'operation',
  }) {
    if (arguments.isEmpty) {
      return <String>[];
    }

    validateNoTokenTransferValues(arguments, context: context);

    if (areArgsTypedValues(arguments)) {
      return _serializer.valuesToStrings(arguments.cast<TypedValue>());
    }

    if (areArgsBuffers(arguments)) {
      return arguments
          .map((arg) => HexUtils.bytesToHex(arg as Uint8List))
          .toList();
    }

    throw ArgumentEncodingException(
      'Cannot encode arguments for $context: '
      'arguments must be TypedValue instances or Uint8List buffers. '
      'Received: ${arguments.map((a) => a.runtimeType).toList()}',
    );
  }

  /// Checks if all arguments are [TypedValue] instances.
  ///
  /// #### Parameters
  /// - `args` - List of arguments to check
  ///
  /// #### Returns
  /// `true` if all arguments are TypedValue, `false` otherwise
  bool areArgsTypedValues(List<dynamic> args) {
    return args.every((arg) => arg is TypedValue);
  }

  /// Checks if all arguments are [Uint8List] buffers.
  ///
  /// #### Parameters
  /// - `args` - List of arguments to check
  ///
  /// #### Returns
  /// `true` if all arguments are Uint8List, `false` otherwise
  bool areArgsBuffers(List<dynamic> args) {
    return args.every((arg) => arg is Uint8List);
  }

  /// Validates that no [TokenTransferValue] is passed in arguments.
  ///
  /// [TokenTransferValue] should be passed via `tokenTransfers` parameter,
  /// not in `arguments`. It cannot be directly encoded as an argument.
  ///
  /// #### Parameters
  /// - `arguments` - List of arguments to validate
  /// - `context` - Context string for error messages
  ///
  /// #### Throws
  /// - [ArgumentEncodingException] if TokenTransferValue found
  void validateNoTokenTransferValues(
    List<dynamic> arguments, {
    String context = 'operation',
  }) {
    for (int i = 0; i < arguments.length; i++) {
      if (arguments[i] is TokenTransferValue) {
        throw ArgumentEncodingException(
          'TokenTransferValue found in arguments at index $i. '
          'Token transfers should be passed via the "tokenTransfers" parameter, '
          'not in "arguments". TokenTransferValue cannot be directly encoded.',
        );
      }
    }
  }
}
