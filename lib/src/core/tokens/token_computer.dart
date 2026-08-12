import 'dart:typed_data';

import '../../utils/sdk_exceptions.dart';
import 'token.dart';

/// Helper for slicing / composing extended token identifiers
/// (`TICKER-randomseq[-noncehex]`) and inspecting [Token] properties.
class TokenComputer {
  /// Creates a token computer.
  const TokenComputer();

  /// Length of the random sequence in a fully qualified identifier
  /// (e.g. the `abcdef` in `FOO-abcdef`).
  static const int tokenRandomSequenceLength = 6;

  /// Maximum length of an optional `prefix-` component (e.g. `nfty-`).
  static const int maxTokenPrefixLength = 4;

  /// Minimum prefix length, when present.
  static const int minTokenPrefixLength = 1;

  /// Minimum ticker length.
  static const int minTickerLength = 3;

  /// Maximum ticker length.
  static const int maxTickerLength = 10;

  /// Returns `true` when the token is fungible (nonce == 0).
  bool isFungible(Token token) => token.nonce == BigInt.zero;

  /// Extracts the integer nonce from an extended identifier like
  /// `FOO-abcdef-0a` (returns `10`). Returns `0` for fungible identifiers.
  int extractNonceFromExtendedIdentifier(String identifier) {
    final List<String> parts = identifier.split('-');
    final _IdentifierParts split = _splitIdentifierIntoComponents(parts);
    _validateExtendedIdentifier(split, parts);

    if (parts.length == 2 || (split.prefix != null && parts.length == 3)) {
      return 0;
    }

    final String hexNonce = parts.last;
    return _decodeUnsignedHex(hexNonce);
  }

  /// Extracts the base identifier (prefix?-ticker-randomSequence) from an
  /// extended identifier, dropping the trailing nonce part if any.
  String extractIdentifierFromExtendedIdentifier(String identifier) {
    final List<String> parts = identifier.split('-');
    final _IdentifierParts split = _splitIdentifierIntoComponents(parts);
    _validateExtendedIdentifier(split, parts);
    if (split.prefix != null) {
      _checkLengthOfPrefix(split.prefix!);
      return '${split.prefix}-${split.ticker}-${split.randomSequence}';
    }
    return '${split.ticker}-${split.randomSequence}';
  }

  /// Extracts just the ticker (e.g. `FOO`) from an extended identifier.
  String extractTickerFromExtendedIdentifier(String identifier) {
    final List<String> parts = identifier.split('-');
    final _IdentifierParts split = _splitIdentifierIntoComponents(parts);
    _validateExtendedIdentifier(split, parts);
    if (split.prefix != null) {
      _checkLengthOfPrefix(split.prefix!);
      return '${split.prefix}-${split.ticker}';
    }
    return split.ticker;
  }

  /// Returns the extended identifier (`identifier-nonceHex`) for a [Token].
  ///
  /// For fungible tokens (nonce == 0) returns the bare identifier unchanged.
  String computeExtendedIdentifier(Token token) {
    final List<String> parts = token.identifier.split('-');
    final _IdentifierParts split = _splitIdentifierIntoComponents(parts);
    _validateExtendedIdentifier(split, parts);

    if (token.nonce.isNegative) {
      throw ValidationException(
        "The token nonce can't be less than 0",
        parameterName: 'nonce',
        invalidValue: token.nonce,
        constraint: '>= 0',
      );
    }
    if (token.nonce == BigInt.zero) {
      return token.identifier;
    }
    final String nonceAsHex = _bigIntToPaddedHex(token.nonce);
    return '${token.identifier}-$nonceAsHex';
  }

  _IdentifierParts _splitIdentifierIntoComponents(List<String> parts) {
    if (parts.length >= 3 && parts[2].length == tokenRandomSequenceLength) {
      return _IdentifierParts(
        prefix: parts[0],
        ticker: parts[1],
        randomSequence: parts[2],
      );
    }
    return _IdentifierParts(
      prefix: null,
      ticker: parts[0],
      randomSequence: parts.length > 1 ? parts[1] : '',
    );
  }

  void _validateExtendedIdentifier(_IdentifierParts split, List<String> parts) {
    _checkExtendedLength(split.prefix, parts);
    _ensureTickerValidity(split.ticker);
    _checkRandomSequenceLength(split.randomSequence);
  }

  void _checkExtendedLength(String? prefix, List<String> parts) {
    const int minLen = 2;
    final int maxLen = prefix != null ? 4 : 3;
    if (parts.length < minLen || parts.length > maxLen) {
      throw ValidationException(
        'Invalid extended token identifier provided',
        parameterName: 'identifier',
        invalidValue: parts.join('-'),
        constraint: 'parts in [$minLen,$maxLen]',
      );
    }
  }

  void _checkRandomSequenceLength(String randomSequence) {
    if (randomSequence.length != tokenRandomSequenceLength) {
      throw ValidationException(
        'Random sequence does not have the right length',
        parameterName: 'randomSequence',
        invalidValue: randomSequence,
        constraint: 'length == $tokenRandomSequenceLength',
      );
    }
  }

  void _checkLengthOfPrefix(String prefix) {
    if (prefix.length < minTokenPrefixLength ||
        prefix.length > maxTokenPrefixLength) {
      throw ValidationException(
        'Token prefix does not have the right length',
        parameterName: 'prefix',
        invalidValue: prefix,
        constraint: 'length in [$minTokenPrefixLength,$maxTokenPrefixLength]',
      );
    }
  }

  void _ensureTickerValidity(String ticker) {
    if (ticker.length < minTickerLength || ticker.length > maxTickerLength) {
      throw ValidationException(
        'Token ticker must be between $minTickerLength and '
        '$maxTickerLength characters',
        parameterName: 'ticker',
        invalidValue: ticker,
        constraint: 'length in [$minTickerLength,$maxTickerLength]',
      );
    }
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(ticker)) {
      throw ValidationException(
        'Token ticker should only contain alphanumeric characters',
        parameterName: 'ticker',
        invalidValue: ticker,
        constraint: 'alphanumeric',
      );
    }
  }

  static int _decodeUnsignedHex(String hex) {
    final String normalized = hex.length.isOdd ? '0$hex' : hex;
    int value = 0;
    for (int i = 0; i < normalized.length; i += 2) {
      final int byte = int.parse(normalized.substring(i, i + 2), radix: 16);
      value = (value << 8) | byte;
    }
    return value;
  }

  static String _bigIntToPaddedHex(BigInt value) {
    if (value == BigInt.zero) {
      return '00';
    }
    final List<int> bytes = <int>[];
    BigInt remaining = value;
    final BigInt mask = BigInt.from(0xff);
    while (remaining > BigInt.zero) {
      bytes.insert(0, (remaining & mask).toInt());
      remaining = remaining >> 8;
    }
    final StringBuffer buf = StringBuffer();
    for (final int b in bytes) {
      buf.write(b.toRadixString(16).padLeft(2, '0'));
    }
    final String hex = buf.toString();
    return hex.length.isOdd ? '0$hex' : hex;
  }
}

/// Internal record returned by `_splitIdentifierIntoComponents`.
class _IdentifierParts {
  const _IdentifierParts({
    required this.prefix,
    required this.ticker,
    required this.randomSequence,
  });

  final String? prefix;
  final String ticker;
  final String randomSequence;
}

/// Type alias retained for completeness; some callers prefer working with
/// raw bytes when round-tripping the on-chain wire form.
typedef TokenNonceBytes = Uint8List;
