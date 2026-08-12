import 'package:meta/meta.dart';

import '../../utils/sdk_exceptions.dart';

/// The native MultiversX token identifier used in `MultiESDTNFTTransfer`
/// payloads to denote EGLD.
///
/// The bare 4-byte `EGLD` short form is not a valid token identifier in a
/// transfer payload; the wire form must be this full `EGLD-000000` sentinel.
const String egldIdentifier = 'EGLD-000000';

/// Typed wrapper over an ESDT/NFT/SFT/META token identifier string.
///
/// Provides ergonomic equality, validation, and the ability to flow through
/// generic APIs without losing intent. Use [TokenIdentifier.parse] for a
/// validating constructor; use the default constructor for already-trusted
/// strings.
@immutable
class TokenIdentifier {
  /// Creates a typed token identifier without validation.
  const TokenIdentifier(this.value);

  /// Parses and validates an extended/normal identifier and returns a typed
  /// [TokenIdentifier].
  ///
  /// Throws [ValidationException] when the string is empty.
  factory TokenIdentifier.parse(String value) {
    if (value.isEmpty) {
      throw ValidationException(
        'Token identifier cannot be empty',
        parameterName: 'value',
        invalidValue: value,
        constraint: 'non-empty',
      );
    }
    return TokenIdentifier(value);
  }

  /// The underlying identifier string (e.g. `FOO-abcdef`, `EGLD-000000`).
  final String value;

  /// Returns `true` if this identifier is the native EGLD sentinel.
  bool get isEgld => value == egldIdentifier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TokenIdentifier && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Typed wrapper that holds either an ESDT identifier or the EGLD sentinel.
///
/// Accepts both token kinds wherever an endpoint takes either one.
@immutable
class EgldOrEsdtTokenIdentifier extends TokenIdentifier {
  /// Wraps an arbitrary identifier (no canonicalisation).
  const EgldOrEsdtTokenIdentifier(super.value);

  /// Returns the EGLD identifier instance.
  factory EgldOrEsdtTokenIdentifier.egld() =>
      const EgldOrEsdtTokenIdentifier(egldIdentifier);

  /// Parses an identifier, canonicalising the empty string and the legacy
  /// `EGLD` short form into [egldIdentifier].
  factory EgldOrEsdtTokenIdentifier.parse(String value) {
    if (value.isEmpty || value == 'EGLD') {
      return EgldOrEsdtTokenIdentifier.egld();
    }
    return EgldOrEsdtTokenIdentifier(value);
  }
}

/// Plain DTO describing a token instance: its identifier and (optional) nonce.
///
/// Fungible tokens use nonce zero; NFTs/SFTs/META-ESDTs use a positive nonce.
@immutable
class Token {
  /// Creates a token. [nonce] defaults to zero (fungible).
  Token({required this.identifier, BigInt? nonce})
    : nonce = nonce ?? BigInt.zero {
    if (this.nonce.isNegative) {
      throw ValidationException(
        'Token nonce cannot be negative',
        parameterName: 'nonce',
        invalidValue: this.nonce,
        constraint: '>= 0',
      );
    }
  }

  /// Token identifier (e.g. `FOO-abcdef`, `EGLD-000000`).
  final String identifier;

  /// Token nonce. Zero for fungible tokens, positive for NFTs/SFTs/META.
  final BigInt nonce;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Token &&
          other.identifier == identifier &&
          other.nonce == nonce);

  @override
  int get hashCode => Object.hash(identifier, nonce);

  @override
  String toString() => 'Token($identifier, nonce=$nonce)';
}

/// Payment of an ESDT token (identifier + nonce + amount).
///
/// Fields encode in the fixed on-chain order `(identifier, nonce, amount)`.
@immutable
class EsdtTokenPayment {
  /// Creates an ESDT payment.
  EsdtTokenPayment({
    required this.tokenIdentifier,
    BigInt? tokenNonce,
    required this.amount,
  }) : tokenNonce = tokenNonce ?? BigInt.zero {
    if (this.tokenNonce.isNegative) {
      throw ValidationException(
        'EsdtTokenPayment nonce cannot be negative',
        parameterName: 'tokenNonce',
        invalidValue: this.tokenNonce,
        constraint: '>= 0',
      );
    }
    if (amount.isNegative) {
      throw ValidationException(
        'EsdtTokenPayment amount cannot be negative',
        parameterName: 'amount',
        invalidValue: amount,
        constraint: '>= 0',
      );
    }
  }

  /// Convenience constructor from a [Token] DTO.
  factory EsdtTokenPayment.fromToken({
    required Token token,
    required BigInt amount,
  }) => EsdtTokenPayment(
    tokenIdentifier: TokenIdentifier(token.identifier),
    tokenNonce: token.nonce,
    amount: amount,
  );

  /// Typed token identifier (e.g. `FOO-abcdef`).
  final TokenIdentifier tokenIdentifier;

  /// Token nonce. Zero for fungible tokens.
  final BigInt tokenNonce;

  /// Amount in the token's smallest unit.
  final BigInt amount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EsdtTokenPayment &&
          other.tokenIdentifier == tokenIdentifier &&
          other.tokenNonce == tokenNonce &&
          other.amount == amount);

  @override
  int get hashCode => Object.hash(tokenIdentifier, tokenNonce, amount);

  @override
  String toString() =>
      'EsdtTokenPayment($tokenIdentifier, nonce=$tokenNonce, amount=$amount)';
}

/// Payment that may carry either EGLD or an ESDT.
///
/// Fields encode in the fixed on-chain order `(identifier, nonce, amount)`.
@immutable
class EgldOrEsdtTokenPayment {
  /// Creates an EGLD-or-ESDT payment.
  EgldOrEsdtTokenPayment({
    required this.tokenIdentifier,
    BigInt? tokenNonce,
    required this.amount,
  }) : tokenNonce = tokenNonce ?? BigInt.zero {
    if (this.tokenNonce.isNegative) {
      throw ValidationException(
        'EgldOrEsdtTokenPayment nonce cannot be negative',
        parameterName: 'tokenNonce',
        invalidValue: this.tokenNonce,
        constraint: '>= 0',
      );
    }
    if (amount.isNegative) {
      throw ValidationException(
        'EgldOrEsdtTokenPayment amount cannot be negative',
        parameterName: 'amount',
        invalidValue: amount,
        constraint: '>= 0',
      );
    }
  }

  /// Creates an EGLD payment with the canonical [egldIdentifier].
  factory EgldOrEsdtTokenPayment.egld(BigInt amount) => EgldOrEsdtTokenPayment(
    tokenIdentifier: EgldOrEsdtTokenIdentifier.egld(),
    amount: amount,
  );

  /// Convenience constructor from a [Token] DTO.
  factory EgldOrEsdtTokenPayment.fromToken({
    required Token token,
    required BigInt amount,
  }) => EgldOrEsdtTokenPayment(
    tokenIdentifier: EgldOrEsdtTokenIdentifier.parse(token.identifier),
    tokenNonce: token.nonce,
    amount: amount,
  );

  /// Typed identifier (may be EGLD or an ESDT identifier).
  final EgldOrEsdtTokenIdentifier tokenIdentifier;

  /// Token nonce. Zero for fungible tokens / EGLD.
  final BigInt tokenNonce;

  /// Amount in the token's smallest unit.
  final BigInt amount;

  /// Returns `true` if this payment carries the EGLD sentinel.
  bool get isEgld => tokenIdentifier.isEgld;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EgldOrEsdtTokenPayment &&
          other.tokenIdentifier == tokenIdentifier &&
          other.tokenNonce == tokenNonce &&
          other.amount == amount);

  @override
  int get hashCode => Object.hash(tokenIdentifier, tokenNonce, amount);

  @override
  String toString() =>
      'EgldOrEsdtTokenPayment($tokenIdentifier, nonce=$tokenNonce, '
      'amount=$amount)';
}
