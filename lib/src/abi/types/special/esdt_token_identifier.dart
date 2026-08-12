import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../core/type_system.dart';
import 'token_identifier.dart';

/// EsdtTokenIdentifier type — the `EsdtTokenIdentifier` spelling of a token
/// identifier as it appears in ABI JSON.
///
/// Wire format and validation rules are identical to
/// [TokenIdentifierType]; the only difference is the type name
/// (`EsdtTokenIdentifier`) so ABI strings can be re-serialised
/// losslessly. Functionally it accepts the same `TICKER-hexrandom`
/// identifiers and rejects the bare `EGLD` legacy form.
///
/// #### Example
/// ```dart
/// final type = EsdtTokenIdentifierType.type;
/// final token = type.createValue('WEGLD-bd4d79');
/// print(token.identifier); // "WEGLD-bd4d79"
/// ```
@immutable
final class EsdtTokenIdentifierType extends PrimitiveType {
  EsdtTokenIdentifierType._() : super(name: 'EsdtTokenIdentifier');
  static final EsdtTokenIdentifierType _instance = EsdtTokenIdentifierType._();

  /// Gets the singleton type instance for use in type definitions.
  static EsdtTokenIdentifierType get type => _instance;

  @override
  String get className => 'EsdtTokenIdentifierType';

  @override
  List<String> get classHierarchy => <String>[
    className,
    'PrimitiveType',
    'AbiType',
  ];

  /// Creates an [EsdtTokenIdentifierValue] from a string or UTF-8 bytes.
  ///
  /// #### Parameters
  /// - `nativeValue` - `String` (TICKER-hexrandom) or `List<int>` UTF-8 bytes
  ///
  /// #### Returns
  /// `EsdtTokenIdentifierValue` - Instance with the identifier
  ///
  /// #### Throws
  /// - `ArgumentError` - If not `String` / `List<int>` or invalid format
  ///
  /// #### Example
  /// ```dart
  /// final value = EsdtTokenIdentifierType.create('USDC-c76f1f');
  /// ```
  static EsdtTokenIdentifierValue create(dynamic nativeValue) {
    if (nativeValue is String) {
      return EsdtTokenIdentifierValue(nativeValue);
    }

    if (nativeValue is List<int>) {
      return EsdtTokenIdentifierValue.fromBytes(nativeValue);
    }

    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'EsdtTokenIdentifier requires String or List<int>',
    );
  }

  @override
  EsdtTokenIdentifierValue createValue(dynamic nativeValue) =>
      create(nativeValue);
}

/// EsdtTokenIdentifier value.
///
/// Holds an ESDT identifier (e.g. `WEGLD-bd4d79`) with the same
/// validation as [TokenIdentifierValue]. Provides ticker and random
/// part accessors and a UTF-8 byte representation.
///
/// #### Example
/// ```dart
/// final value = EsdtTokenIdentifierValue('WEGLD-bd4d79');
/// print(value.ticker); // "WEGLD"
/// print(value.randomPart); // "bd4d79"
/// ```
@immutable
final class EsdtTokenIdentifierValue extends TypedValue {
  /// Creates an EsdtTokenIdentifier value.
  ///
  /// #### Parameters
  /// - `identifier` - ESDT token identifier (TICKER-hexrandom format)
  ///
  /// #### Throws
  /// - `ArgumentError` - If identifier format is invalid
  EsdtTokenIdentifierValue(this.identifier)
    : super(EsdtTokenIdentifierType._instance) {
    _validate(identifier);
  }

  /// Creates EsdtTokenIdentifier from UTF-8 bytes.
  ///
  /// #### Parameters
  /// - `bytes` - UTF-8 encoded token identifier bytes
  factory EsdtTokenIdentifierValue.fromBytes(List<int> bytes) {
    final String identifier = String.fromCharCodes(bytes);
    return EsdtTokenIdentifierValue(identifier);
  }

  /// Token identifier string.
  final String identifier;

  static final RegExp _pattern = RegExp(r'^[A-Za-z0-9]+-[a-f0-9]{6}$');

  static void _validate(String identifier) {
    if (identifier.isEmpty) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'EsdtTokenIdentifier cannot be empty',
      );
    }

    if (!_pattern.hasMatch(identifier)) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'EsdtTokenIdentifier must match format: TICKER-hexrandom '
            '(6-char hex suffix)',
      );
    }
  }

  @override
  String get className => 'EsdtTokenIdentifierValue';

  @override
  List<String> get classHierarchy => <String>[className, 'TypedValue'];

  @override
  String get nativeValue => identifier;

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() => Uint8List.fromList(utf8.encode(identifier));

  /// Ticker portion of the identifier (before the dash).
  String get ticker {
    final int dashIndex = identifier.indexOf('-');
    return dashIndex > 0 ? identifier.substring(0, dashIndex) : identifier;
  }

  /// Random part of the identifier (after the dash), or `null` if absent.
  String? get randomPart {
    final int dashIndex = identifier.indexOf('-');
    return dashIndex > 0 && dashIndex < identifier.length - 1
        ? identifier.substring(dashIndex + 1)
        : null;
  }

  /// Length of the identifier string.
  int get length => identifier.length;

  @override
  String toString() => identifier;
}
