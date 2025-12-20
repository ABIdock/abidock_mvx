import 'package:meta/meta.dart';

import '../../core/type_system.dart';
import '../primitives/numerical.dart';
import 'token_identifier.dart';

/// Token transfer as ABI type.
///
/// Represents an ESDT/EGLD token transfer with amount and optional
/// nonce (for NFTs/SFTs). Used for multi-token contract calls. Cannot be encoded
/// to bytes directly - must use ArgumentEncoder.

@immutable
final class TokenTransferValue extends TypedValue {
  /// Creates token transfer with ABI typed values.
  ///
  /// #### Parameters
  /// - `tokenIdentifier` - EgldOrEsdtTokenIdentifierValue (EGLD or ESDT)
  /// - `amount` - BigUIntValue transfer amount (atomic units)
  /// - `nonce` - Optional U64Value for NFTs/SFTs (null for fungible)
  ///
  /// #### Throws
  /// - `ArgumentError` - If tokenIdentifier is empty
  /// - `ArgumentError` - If amount is negative
  /// - `ArgumentError` - If nonce is zero (should be null for fungible)
  ///
  /// #### Example
  /// ```dart
  /// final transfer = TokenTransferValue(
  ///   tokenIdentifier: EgldOrEsdtTokenIdentifierValue('MYTOKEN-a1b2c3'),
  ///   amount: BigUIntValue(BigInt.from(1000)),
  ///   nonce: U64Value(BigInt.from(42)), // For NFT
  /// );
  /// ```
  factory TokenTransferValue({
    required EgldOrEsdtTokenIdentifierValue tokenIdentifier,
    required BigUIntValue amount,
    U64Value? nonce,
  }) {
    if (tokenIdentifier.identifier.isEmpty) {
      throw ArgumentError.value(
        tokenIdentifier.identifier,
        'tokenIdentifier',
        'Token identifier cannot be empty',
      );
    }
    if (amount.value < BigInt.zero) {
      throw ArgumentError.value(
        amount.value,
        'amount',
        'Amount cannot be negative',
      );
    }
    if (nonce != null && nonce.value == BigInt.zero) {
      throw ArgumentError.value(
        nonce.value,
        'nonce',
        'Nonce should be null for fungible tokens, not zero',
      );
    }

    return TokenTransferValue._internal(
      tokenIdentifier: tokenIdentifier,
      amount: amount,
      nonce: nonce,
    );
  }
  TokenTransferValue._internal({
    required this.tokenIdentifier,
    required this.amount,
    this.nonce,
  }) : super(TokenTransferType.type);

  /// Creates token transfer from primitive types.
  ///
  /// #### Parameters
  /// - `tokenIdentifier` - String token identifier (EGLD or ESDT)
  /// - `amount` - BigInt amount (atomic units)
  /// - `nonce` - Optional BigInt nonce for NFTs/SFTs
  ///
  /// #### Throws
  /// - `ArgumentError` - If tokenIdentifier is empty
  /// - `ArgumentError` - If amount is negative
  /// - `ArgumentError` - If nonce is zero (should be null for fungible)
  ///
  /// #### Example
  /// ```dart
  /// // Fungible token
  /// final fungible = TokenTransferValue.fromPrimitives(
  ///   tokenIdentifier: 'MYTOKEN-a1b2c3',
  ///   amount: BigInt.from(1000),
  /// );
  ///
  /// // NFT with nonce
  /// final nft = TokenTransferValue.fromPrimitives(
  ///   tokenIdentifier: 'MYNFT-a1b2c3',
  ///   amount: BigInt.one,
  ///   nonce: BigInt.from(10),
  /// );
  /// ```
  factory TokenTransferValue.fromPrimitives({
    required String tokenIdentifier,
    required BigInt amount,
    BigInt? nonce,
  }) {
    if (tokenIdentifier.isEmpty) {
      throw ArgumentError.value(
        tokenIdentifier,
        'tokenIdentifier',
        'Token identifier cannot be empty',
      );
    }

    if (amount < BigInt.zero) {
      throw ArgumentError.value(amount, 'amount', 'Amount cannot be negative');
    }

    if (nonce != null && nonce == BigInt.zero) {
      throw ArgumentError.value(
        nonce,
        'nonce',
        'Nonce should be null for fungible tokens, not zero',
      );
    }

    return TokenTransferValue(
      tokenIdentifier: EgldOrEsdtTokenIdentifierValue(tokenIdentifier),
      amount: BigUIntValue(amount),
      nonce: nonce != null ? U64Value(nonce) : null,
    );
  }

  /// Token identifier (EGLD or ESDT).
  final EgldOrEsdtTokenIdentifierValue tokenIdentifier;

  /// Token nonce (for NFTs/SFTs, null for fungible).
  final U64Value? nonce;

  /// Amount to transfer (atomic units).
  final BigUIntValue amount;

  /// Whether this is fungible token (no nonce).
  bool get isFungible => nonce == null;

  /// Whether this is NFT/SFT (has nonce).
  bool get isNft => nonce != null;

  /// Whether this is EGLD.
  bool get isEgld => tokenIdentifier.isEgld;

  @override
  TokenTransferType get type => TokenTransferType.type;

  @override
  String get className => 'TokenTransferValue';

  static const List<String> _classHierarchy = [
    'TokenTransferValue',
    'TypedValue',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  dynamic get nativeValue => this;

  /// Throws UnsupportedError - use ArgumentEncoder instead.
  ///
  /// #### Throws
  /// - `UnsupportedError` - Always thrown
  ///
  /// #### Example
  /// ```dart
  /// final transfer = TokenTransferValue.fromPrimitives(
  ///   tokenIdentifier: 'MYTOKEN-a1b2c3',
  ///   amount: BigInt.from(1000),
  /// );
  ///
  /// // transfer.toBytes(); // Throws UnsupportedError
  ///
  /// // Instead use:
  /// // ArgumentEncoder().encodeForEndpointWithTokens(...)
  /// ```
  @override
  List<int> toBytes() {
    throw UnsupportedError(
      'TokenTransferValue does not have direct byte encoding. '
      'Use ArgumentEncoder.encodeForEndpointWithTokens() instead.',
    );
  }

  @override
  String toString() {
    if (isNft) {
      return 'TokenTransferValue(${tokenIdentifier.identifier}-${nonce!.value}: ${amount.value})';
    }
    return 'TokenTransferValue(${tokenIdentifier.identifier}: ${amount.value})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenTransferValue &&
          runtimeType == other.runtimeType &&
          tokenIdentifier.identifier == other.tokenIdentifier.identifier &&
          nonce?.value == other.nonce?.value &&
          amount.value == other.amount.value;

  @override
  int get hashCode =>
      Object.hash(tokenIdentifier.identifier, nonce?.value, amount.value);
}

/// ABI type for token transfers.
///
/// Singleton type representing TokenTransferValue. Used internally
/// by the ABI system.
///
/// #### Example
/// ```dart
/// final type = TokenTransferType.type;
/// print(type.name); // TokenTransfer
/// ```
@immutable
final class TokenTransferType extends AbiType {
  TokenTransferType._() : super(name: 'TokenTransfer');

  /// Singleton instance.
  static final TokenTransferType _instance = TokenTransferType._();

  /// Gets the singleton TokenTransferType instance.
  static TokenTransferType get type => _instance;

  /// Creates TokenTransferValue from native value.
  ///
  /// #### Example
  /// ```dart
  /// final transfer = TokenTransferValue.fromPrimitives(
  ///   tokenIdentifier: 'MYTOKEN-a1b2c3',
  ///   amount: BigInt.from(1000),
  /// );
  /// final value = TokenTransferType.create(transfer);
  /// ```
  static TokenTransferValue create(dynamic nativeValue) =>
      _instance.createValue(nativeValue) as TokenTransferValue;

  /// Creates TokenTransferValue from native value.
  ///
  /// #### Parameters
  /// - `nativeValue` - Must be TokenTransferValue instance
  ///
  /// #### Returns
  /// `TokenTransferValue` - The instance
  ///
  /// #### Throws
  /// - `ArgumentError` - If nativeValue is not TokenTransferValue
  ///
  /// #### Example
  /// ```dart
  /// final transfer = TokenTransferValue.fromPrimitives(
  ///   tokenIdentifier: 'MYTOKEN-a1b2c3',
  ///   amount: BigInt.from(1000),
  /// );
  /// final value = TokenTransferType.create(transfer);
  /// ```
  @override
  TypedValue createValue(dynamic nativeValue) {
    if (nativeValue is TokenTransferValue) {
      return nativeValue;
    }

    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'TokenTransferType requires TokenTransferValue instance',
    );
  }

  @override
  String get className => 'TokenTransferType';

  static const List<String> _classHierarchy = ['TokenTransferType', 'AbiType'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenTransferType && runtimeType == other.runtimeType;

  @override
  int get hashCode => name.hashCode;
}

/// Transfer type based on tokens.
///
/// Enum determining which MultiversX built-in function to use for
/// token transfers in contract calls.
enum TransferType {
  /// Regular call (no token transfers).
  regular,

  /// ESDTTransfer (single fungible token).
  esdtTransfer,

  /// ESDTNFTTransfer (single NFT/SFT).
  esdtNftTransfer,

  /// MultiESDTNFTTransfer (multiple tokens or EGLD as token).
  multiEsdtNftTransfer,
}

/// Determines transfer type for given tokens.
///
/// #### Parameters
/// - `transfers` - Optional list of TokenTransferValue instances
///
/// #### Returns
/// `TransferType` - Enum value
///
/// #### Throws
/// - `ArgumentError` - If any transfer has empty identifier or zero amount
///
/// #### Example
/// ```dart
/// // No transfers
/// final type1 = determineTransferType(null);
/// print(type1); // TransferType.regular
///
/// // Single fungible
/// final type2 = determineTransferType([
///   TokenTransferValue.fromPrimitives(
///     tokenIdentifier: 'MYTOKEN-a1b2c3',
///     amount: BigInt.from(1000),
///   ),
/// ]);
/// print(type2); // TransferType.esdtTransfer
///
/// // Single NFT
/// final type3 = determineTransferType([
///   TokenTransferValue.fromPrimitives(
///     tokenIdentifier: 'MYNFT-a1b2c3',
///     amount: BigInt.one,
///     nonce: BigInt.from(42),
///   ),
/// ]);
/// print(type3); // TransferType.esdtNftTransfer
///
/// // Multiple tokens or EGLD
/// final type4 = determineTransferType([
///   TokenTransferValue.fromPrimitives(
///     tokenIdentifier: 'EGLD',
///     amount: BigInt.parse('1000000000000000000'),
///   ),
/// ]);
/// print(type4); // TransferType.multiEsdtNftTransfer
/// ```
TransferType determineTransferType(List<TokenTransferValue>? transfers) {
  if (transfers == null || transfers.isEmpty) {
    return TransferType.regular;
  }
  for (final TokenTransferValue transfer in transfers) {
    if (transfer.tokenIdentifier.identifier.isEmpty) {
      throw ArgumentError(
        'Transfer has empty token identifier at index ${transfers.indexOf(transfer)}',
      );
    }

    if (transfer.amount.value == BigInt.zero) {
      throw ArgumentError(
        'Transfer has zero amount at index ${transfers.indexOf(transfer)} '
        '(token: ${transfer.tokenIdentifier.identifier})',
      );
    }
  }

  if (transfers.length == 1) {
    final TokenTransferValue transfer = transfers[0];

    if (transfer.isEgld) {
      return TransferType.multiEsdtNftTransfer;
    }

    if (transfer.isFungible) {
      return TransferType.esdtTransfer;
    }

    return TransferType.esdtNftTransfer;
  }

  return TransferType.multiEsdtNftTransfer;
}
