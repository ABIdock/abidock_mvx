import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../core/type_system.dart';

/// TokenIdentifier type for ESDT token identifiers.
///
/// Represents ESDT (eStandard Digital Token) identifiers in format
/// TICKER-hexrandom. Does NOT support EGLD native token.
///
/// #### Example
/// ```dart
/// final type = TokenIdentifierType.type;
///
/// // From string identifier
/// final token1 = type.createValue('WEGLD-bd4d79');
/// final token2 = type.createValue('USDC-c76f1f');
///
/// // From bytes
/// final bytes = 'MYTOKEN-a1b2c3'.codeUnits;
/// final token3 = type.createValue(bytes);
///
/// // Properties
/// print(token1.ticker); // "WEGLD"
/// print(token1.randomPart); // "bd4d79"
/// print(token1.toBytes()); // UTF-8 encoded bytes
///
/// // These throw: invalid format
/// // final invalid1 = type.createValue('EGLD'); // Use EgldOrEsdtTokenIdentifierType
/// // final invalid2 = type.createValue('invalid format');
/// ```
@immutable
final class TokenIdentifierType extends PrimitiveType {
  TokenIdentifierType._() : super(name: 'TokenIdentifier');
  static final TokenIdentifierType _instance = TokenIdentifierType._();

  @override
  String get className => 'TokenIdentifierType';

  @override
  List<String> get classHierarchy => <String>[
    className,
    'PrimitiveType',
    'AbiType',
  ];

  /// Creates TokenIdentifierValue from string or bytes.
  static TokenIdentifierValue create(dynamic nativeValue) {
    if (nativeValue is String) {
      return TokenIdentifierValue(nativeValue);
    }

    if (nativeValue is List<int>) {
      return TokenIdentifierValue.fromBytes(nativeValue);
    }

    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'TokenIdentifier requires String or List<int>',
    );
  }

  /// Gets the singleton type instance for use in type definitions.
  static TokenIdentifierType get type => _instance;

  /// Creates TokenIdentifierValue from string or bytes.
  ///
  /// #### Parameters
  /// - `nativeValue` - String (TICKER-hexrandom) or `List<int>` (UTF-8 bytes)
  ///
  /// #### Returns
  /// `TokenIdentifierValue` - Instance with the identifier
  ///
  /// #### Throws
  /// - `ArgumentError` - If not `String` / `List<int>` or invalid format
  ///
  /// #### Example
  /// ```dart
  /// final value1 = TokenIdentifierType.create('WEGLD-bd4d79');
  /// final value2 = TokenIdentifierType.create('USDC-c76f1f'.codeUnits);
  ///
  /// // These throw: invalid format
  /// // final invalid = TokenIdentifierType.create('EGLD');
  /// ```
  @override
  TokenIdentifierValue createValue(dynamic nativeValue) => create(nativeValue);
}

/// TokenIdentifier value.
///
/// Holds an ESDT token identifier with validation and parsing utilities.
/// Provides access to ticker and random parts.
///
/// #### Example
/// ```dart
/// final value = TokenIdentifierValue('WEGLD-bd4d79');
///
/// print(value.identifier); // "WEGLD-bd4d79"
/// print(value.ticker); // "WEGLD"
/// print(value.randomPart); // "bd4d79"
/// print(value.length); // 12
///
/// final bytes = value.toBytes(); // UTF-8 encoded
/// final fromBytes = TokenIdentifierValue.fromBytes(bytes);
/// ```
@immutable
final class TokenIdentifierValue extends TypedValue {
  /// Creates TokenIdentifier value.
  ///
  /// #### Parameters
  /// - `identifier` - ESDT token identifier (TICKER-hexrandom format)
  ///
  /// #### Throws
  /// - `ArgumentError` - If identifier format is invalid
  ///
  /// #### Example
  /// ```dart
  /// final value1 = TokenIdentifierValue('WEGLD-bd4d79');
  /// final value2 = TokenIdentifierValue('MYTOKEN-a1b2c3');
  ///
  /// // These throw: invalid format
  /// // final invalid1 = TokenIdentifierValue('EGLD');
  /// // final invalid2 = TokenIdentifierValue('invalid');
  /// ```
  TokenIdentifierValue(this.identifier) : super(TokenIdentifierType._instance) {
    _validate(identifier);
  }

  /// Creates TokenIdentifier from UTF-8 bytes.
  ///
  /// #### Parameters
  /// - `bytes` - UTF-8 encoded token identifier bytes
  ///
  /// #### Example
  /// ```dart
  /// final bytes = 'WEGLD-bd4d79'.codeUnits;
  /// final value = TokenIdentifierValue.fromBytes(bytes);
  /// print(value.identifier); // "WEGLD-bd4d79"
  /// ```
  factory TokenIdentifierValue.fromBytes(List<int> bytes) {
    final String identifier = String.fromCharCodes(bytes);
    return TokenIdentifierValue(identifier);
  }

  /// Token identifier string.
  final String identifier;

  static void _validate(String identifier) {
    if (identifier.isEmpty) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'TokenIdentifier cannot be empty',
      );
    }

    if (!RegExp(r'^[A-Za-z0-9]+-[a-f0-9]{6}$').hasMatch(identifier)) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'TokenIdentifier must match format: TICKER-hexrandom (6-char hex suffix, use EgldOrEsdtTokenIdentifierType for EGLD)',
      );
    }
  }

  @override
  String get className => 'TokenIdentifierValue';

  @override
  List<String> get classHierarchy => <String>[className, 'TypedValue'];

  @override
  String get nativeValue => identifier;

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() => Uint8List.fromList(utf8.encode(identifier));

  /// Ticker part (before dash).
  String get ticker {
    final int dashIndex = identifier.indexOf('-');
    return dashIndex > 0 ? identifier.substring(0, dashIndex) : identifier;
  }

  /// Random part (after dash).
  String? get randomPart {
    final int dashIndex = identifier.indexOf('-');
    return dashIndex > 0 && dashIndex < identifier.length - 1
        ? identifier.substring(dashIndex + 1)
        : null;
  }

  /// Returns the length of the identifier string.
  int get length => identifier.length;

  @override
  String toString() => identifier;
}

/// EgldOrEsdtTokenIdentifier type for EGLD or ESDT tokens.
///
/// Represents either EGLD native token or ESDT tokens. More flexible
/// than TokenIdentifierType as it accepts "EGLD" and empty identifiers.
///
/// #### Example
/// ```dart
/// // EGLD native token
/// final egld = EgldOrEsdtTokenIdentifierType.create('EGLD');
/// print(egld.isEgld); // true
///
/// // ESDT token
/// final esdt = EgldOrEsdtTokenIdentifierType.create('MYTOKEN-a1b2c3');
/// print(esdt.isEsdt); // true
/// ```
@immutable
final class EgldOrEsdtTokenIdentifierType extends PrimitiveType {
  EgldOrEsdtTokenIdentifierType._() : super(name: 'EgldOrEsdtTokenIdentifier');
  static final EgldOrEsdtTokenIdentifierType _instance =
      EgldOrEsdtTokenIdentifierType._();

  @override
  int? get sizeInBytes => null;

  @override
  String get className => 'EgldOrEsdtTokenIdentifierType';

  @override
  List<String> get classHierarchy => <String>[
    className,
    'PrimitiveType',
    'AbiType',
  ];

  /// Creates EgldOrEsdtTokenIdentifierValue from string or bytes.
  static EgldOrEsdtTokenIdentifierValue create(dynamic nativeValue) {
    if (nativeValue is String) {
      return EgldOrEsdtTokenIdentifierValue(nativeValue);
    }

    if (nativeValue is List<int>) {
      return EgldOrEsdtTokenIdentifierValue.fromBytes(nativeValue);
    }

    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'EgldOrEsdtTokenIdentifier requires String or List<int>',
    );
  }

  /// Gets the singleton type instance for use in type definitions.
  static EgldOrEsdtTokenIdentifierType get type => _instance;

  /// Creates EgldOrEsdtTokenIdentifierValue from string or bytes.
  ///
  /// #### Parameters
  /// - `nativeValue` - `String` (EGLD/TICKER-hexrandom) or `List<int>` (UTF-8 bytes)
  ///
  /// #### Returns
  /// `EgldOrEsdtTokenIdentifierValue` - Instance with the identifier
  ///
  /// #### Throws
  /// - `ArgumentError` - If not `String` / `List<int>` or invalid format
  ///
  /// #### Example
  /// ```dart
  /// final egld = EgldOrEsdtTokenIdentifierType.create('EGLD');
  /// final esdt = EgldOrEsdtTokenIdentifierType.create('WEGLD-bd4d79');
  /// final empty = EgldOrEsdtTokenIdentifierType.create('');
  /// ```
  @override
  EgldOrEsdtTokenIdentifierValue createValue(dynamic nativeValue) =>
      create(nativeValue);
}

/// EgldOrEsdtTokenIdentifier value.
///
/// Holds either EGLD native token or ESDT token identifier with type checking.
/// Provides utilities for distinguishing between EGLD and ESDT tokens.
///
/// #### Example
/// ```dart
/// final egld = EgldOrEsdtTokenIdentifierValue('EGLD');
/// print(egld.isEgld); // true
/// print(egld.isEsdt); // false
/// print(egld.ticker); // "EGLD"
///
/// final esdt = EgldOrEsdtTokenIdentifierValue('WEGLD-bd4d79');
/// print(esdt.isEgld); // false
/// print(esdt.isEsdt); // true
/// print(esdt.ticker); // "WEGLD"
/// print(esdt.randomPart); // "bd4d79"
///
/// final empty = EgldOrEsdtTokenIdentifierValue('');
/// print(empty.isEgld); // false
/// print(empty.isEsdt); // false
/// ```
@immutable
final class EgldOrEsdtTokenIdentifierValue extends TypedValue {
  /// Creates EgldOrEsdtTokenIdentifier value.
  ///
  /// #### Parameters
  /// - `identifier` - Token identifier (EGLD, TICKER-hexrandom, or empty)
  ///
  /// #### Throws
  /// - `ArgumentError` - If identifier format is invalid
  ///
  /// #### Example
  /// ```dart
  /// final egld = EgldOrEsdtTokenIdentifierValue('EGLD');
  /// final esdt = EgldOrEsdtTokenIdentifierValue('WEGLD-bd4d79');
  /// final empty = EgldOrEsdtTokenIdentifierValue(''); // Allowed
  /// ```
  EgldOrEsdtTokenIdentifierValue(this.identifier)
    : super(EgldOrEsdtTokenIdentifierType._instance) {
    _validate(identifier);
  }

  /// Creates EgldOrEsdtTokenIdentifier from UTF-8 bytes.
  factory EgldOrEsdtTokenIdentifierValue.fromBytes(List<int> bytes) {
    final String identifier = String.fromCharCodes(bytes);
    return EgldOrEsdtTokenIdentifierValue(identifier);
  }

  /// Creates EGLD native token.
  factory EgldOrEsdtTokenIdentifierValue.egld() {
    return EgldOrEsdtTokenIdentifierValue('EGLD');
  }

  /// Creates ESDT token.
  factory EgldOrEsdtTokenIdentifierValue.esdt(String identifier) {
    return EgldOrEsdtTokenIdentifierValue(identifier);
  }

  /// Token identifier string.
  final String identifier;

  static void _validate(String identifier) {
    if (identifier.isEmpty) {
      return;
    }

    if (identifier == 'EGLD' || identifier == 'EGLD-000000') {
      return;
    }

    if (!RegExp(r'^[A-Za-z0-9]+-[a-f0-9]{6}$').hasMatch(identifier)) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'EgldOrEsdtTokenIdentifier must be either "EGLD" or match format: TICKER-hexrandom (6-char hex suffix)',
      );
    }
  }

  /// Indicates if the identifier represents the EGLD native token.
  bool get isEgld => identifier == 'EGLD' || identifier == 'EGLD-000000';

  /// Indicates if the identifier represents an ESDT token.
  bool get isEsdt => !isEgld && identifier.isNotEmpty;

  @override
  String get className => 'EgldOrEsdtTokenIdentifierValue';

  @override
  List<String> get classHierarchy => <String>[className, 'TypedValue'];

  @override
  String get nativeValue => identifier;

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() => Uint8List.fromList(utf8.encode(identifier));

  String get ticker {
    if (isEgld) return 'EGLD';
    final int dashIndex = identifier.indexOf('-');
    return dashIndex > 0 ? identifier.substring(0, dashIndex) : identifier;
  }

  String? get randomPart {
    if (isEgld) return null;
    final int dashIndex = identifier.indexOf('-');
    return dashIndex > 0 && dashIndex < identifier.length - 1
        ? identifier.substring(dashIndex + 1)
        : null;
  }

  /// Returns the length of the identifier string.
  int get length => identifier.length;

  @override
  String toString() => identifier;
}
