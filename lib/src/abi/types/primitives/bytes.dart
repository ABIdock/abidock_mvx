import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../utils/hex_utils.dart';
import '../../core/type_system.dart';

/// Bytes type for variable-length binary data.
///
/// Represents raw byte sequences or UTF-8 strings in smart contracts.
/// Commonly used for strings, binary data, and arbitrary-length buffers.
///
/// #### Example
/// ```dart
/// // From byte array
/// final bytes1 = BytesType.create([0x48, 0x65, 0x6c, 0x6c, 0x6f]);
///
/// // Create from string or hex
/// final bytes2 = BytesValue.fromUTF8('Hello');
/// final bytes3 = BytesValue.fromHex('48656c6c6f');
///
/// print(bytes2.toUTF8()); // Hello
/// print(bytes3.toHex()); // 48656C6C6F
///
/// // Use in struct definitions
/// final structType = StructType(
///   name: 'Payload',
///   fieldDefinitions: [
///     FieldDefinition(name: 'data', type: BytesType.type),
///   ],
/// );
/// ```
@immutable
final class BytesType extends PrimitiveType {
  BytesType._() : super(name: 'bytes');

  static final BytesType _instance = BytesType._();

  @override
  String get className => 'BytesType';

  static const List<String> _classHierarchy = [
    'BytesType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates a BytesValue from a native value.
  ///
  /// #### Parameters
  /// - `nativeValue` - `List<int>` with byte values
  ///
  /// #### Throws
  /// - `ArgumentError` - If nativeValue is not `List<int>`
  ///
  /// #### Example
  /// ```dart
  /// final bytes = BytesType.create([72, 101, 108, 108, 111]);
  /// print(bytes.toUTF8()); // Hello
  /// print(bytes.length); // 5
  /// ```
  static BytesValue create(dynamic nativeValue) {
    if (nativeValue is List<int>) {
      return BytesValue(nativeValue);
    }
    if (nativeValue is String) {
      return BytesValue.fromUTF8(nativeValue);
    }
    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'BytesType requires List<int> or String value',
    );
  }

  /// Creates bytes from hexadecimal string.
  static BytesValue createFromHex(String hex) => BytesValue.fromHex(hex);

  /// Creates empty bytes.
  static BytesValue createEmpty() => BytesValue([]);

  /// Gets the singleton type instance for use in type definitions.
  static BytesType get type => _instance;

  @override
  TypedValue createValue(dynamic nativeValue) => create(nativeValue);
}

/// Bytes value for arbitrary binary data.
///
/// Holds variable-length byte sequences with rich operations for manipulation,
/// conversion, and bitwise operations. Supports UTF-8 and hex conversions.
///
/// #### Example
/// ```dart
/// // From raw bytes
/// final bytes1 = BytesValue([0x48, 0x65, 0x6c, 0x6c, 0x6f]);
///
/// // From string
/// final bytes2 = BytesValue.fromUTF8('Hello World');
/// final bytes3 = BytesValue.fromHex('48656c6c6f');
///
/// // Operations
/// final combined = bytes1 + bytes3; // Concatenate
/// final slice = bytes2.slice(0, 5); // Get first 5 bytes
/// final padded = bytes1.padRight(10, 0x00); // Pad to 10 bytes
///
/// // Conversions
/// print(bytes2.toUTF8()); // Hello World
/// print(bytes1.toHex()); // 48656C6C6F
/// print(bytes1.length); // 5
/// ```
@immutable
final class BytesValue extends TypedValue {
  /// Creates a Bytes value.
  ///
  /// #### Parameters
  /// - `value` - `List<int>` with byte values
  BytesValue(List<int> value)
    : value = List<int>.unmodifiable(value),
      super(BytesType._instance);

  /// Byte data.
  final List<int> value;

  @override
  String get className => 'BytesValue';

  static const List<String> _classHierarchy = ['BytesValue', 'TypedValue'];

  @override
  List<String> get classHierarchy => _classHierarchy;
  @override
  Uint8List get nativeValue =>
      value is Uint8List ? value as Uint8List : Uint8List.fromList(value);

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() => value;

  /// Creates a BytesValue from a UTF-8 encoded string.
  ///
  /// #### Parameters
  /// - `value` - UTF-8 string to encode
  static BytesValue fromUTF8(String value) {
    final List<int> bytes = utf8.encode(value);
    return BytesValue(bytes);
  }

  /// Creates a BytesValue from a hex-encoded string.
  ///
  /// #### Parameters
  /// - `hexValue` - Hexadecimal string (with or without 0x prefix, spaces allowed)
  ///
  /// #### Throws
  /// - `FormatException` - If hex string has odd length or invalid characters
  static BytesValue fromHex(String hexValue) {
    final Uint8List bytes = HexUtils.hexToBytes(hexValue);
    return BytesValue(bytes);
  }

  /// Concatenates this bytes with another BytesValue.
  BytesValue operator +(BytesValue other) =>
      BytesValue([...value, ...other.value]);

  /// Concatenates this bytes with a `List<int>`.
  BytesValue concat(List<int> other) => BytesValue([...value, ...other]);

  /// Returns a slice of bytes from start to end (exclusive).
  BytesValue slice(int start, [int? end]) {
    final int actualEnd = end ?? value.length;
    return BytesValue(value.sublist(start, actualEnd));
  }

  /// Pads bytes on the left with a value to reach target length.
  BytesValue padLeft(int width, [int padding = 0]) {
    if (value.length >= width) return this;
    final int padCount = width - value.length;
    return BytesValue([...List.filled(padCount, padding), ...value]);
  }

  /// Pads bytes on the right with a value to reach target length.
  BytesValue padRight(int width, [int padding = 0]) {
    if (value.length >= width) return this;
    final int padCount = width - value.length;
    return BytesValue([...value, ...List.filled(padCount, padding)]);
  }

  /// Converts bytes to hexadecimal string.
  @override
  String toHex({bool prefix = false, bool uppercase = true}) {
    final StringBuffer buffer = StringBuffer();
    if (prefix) buffer.write('0x');
    for (final int byte in value) {
      final String hex = byte.toRadixString(16).padLeft(2, '0');
      buffer.write(uppercase ? hex.toUpperCase() : hex);
    }
    return buffer.toString();
  }

  /// Converts bytes to UTF-8 string (if valid UTF-8).
  String toUTF8() => utf8.decode(value);

  /// Bitwise AND with another BytesValue (must be same length).
  BytesValue operator &(BytesValue other) {
    if (value.length != other.value.length) {
      throw ArgumentError('BytesValue lengths must match for bitwise AND');
    }
    return BytesValue(
      List.generate(value.length, (i) => value[i] & other.value[i]),
    );
  }

  /// Bitwise OR with another BytesValue (must be same length).
  BytesValue operator |(BytesValue other) {
    if (value.length != other.value.length) {
      throw ArgumentError('BytesValue lengths must match for bitwise OR');
    }
    return BytesValue(
      List.generate(value.length, (i) => value[i] | other.value[i]),
    );
  }

  /// Bitwise XOR with another BytesValue (must be same length).
  BytesValue operator ^(BytesValue other) {
    if (value.length != other.value.length) {
      throw ArgumentError('BytesValue lengths must match for bitwise XOR');
    }
    return BytesValue(
      List.generate(value.length, (i) => value[i] ^ other.value[i]),
    );
  }

  /// Bitwise NOT (inverts all bits).
  BytesValue operator ~() {
    return BytesValue(List.generate(value.length, (i) => ~value[i] & 0xFF));
  }

  /// Returns true if the bytes are empty.
  bool get isEmpty => value.isEmpty;

  /// Returns true if the bytes are not empty.
  bool get isNotEmpty => value.isNotEmpty;

  /// Returns the length of the byte sequence.
  int get length => value.length;

  /// Returns the byte at the specified index.
  int operator [](int index) => value[index];

  /// Checks if bytes start with a prefix.
  bool startsWith(List<int> prefix) {
    if (prefix.length > value.length) return false;
    for (int i = 0; i < prefix.length; i++) {
      if (value[i] != prefix[i]) return false;
    }
    return true;
  }

  /// Checks if bytes end with a suffix.
  bool endsWith(List<int> suffix) {
    if (suffix.length > value.length) return false;
    final int offset = value.length - suffix.length;
    for (int i = 0; i < suffix.length; i++) {
      if (value[offset + i] != suffix[i]) return false;
    }
    return true;
  }

  /// Finds the index of the first occurrence of a byte sequence, or -1.
  int indexOf(List<int> pattern, [int start = 0]) {
    if (pattern.isEmpty) return start;
    if (pattern.length > value.length - start) return -1;

    for (int i = start; i <= value.length - pattern.length; i++) {
      bool found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (value[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  /// Reverses the byte order.
  BytesValue reverse() => BytesValue(value.reversed.toList());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BytesValue &&
          value.length == other.value.length &&
          _listsEqual(value, other.value);

  bool _listsEqual(List<int> a, List<int> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(value);

  @override
  String toString() => toHex(prefix: true);
}
