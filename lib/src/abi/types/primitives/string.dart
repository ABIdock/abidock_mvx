import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../utils/hex_utils.dart';
import '../../core/type_system.dart';

/// UTF-8 string type for variable-length encoded strings.
///
/// Represents UTF-8 encoded text strings in smart contracts.
/// Functionally similar to BytesType but semantically indicates text content.
///
/// #### Example
/// ```dart
/// final str1 = StringType.create('Hello World');
/// final str2 = StringValue.fromUTF8('Test String');
/// final str3 = StringValue.fromHex('48656c6c6f'); // "Hello"
///
/// print(str1.nativeValue); // Hello World
/// print(str2.toBytes()); // UTF-8 bytes [84, 101, 115, 116, 32, 83, 116, 114, 105, 110, 103]
/// print(str3.nativeValue); // Hello
///
/// // Use in struct definitions
/// final structType = StructType(
///   name: 'Profile',
///   fieldDefinitions: [
///     FieldDefinition(name: 'name', type: StringType.type),
///   ],
/// );
/// ```
@immutable
final class StringType extends PrimitiveType {
  StringType._() : super(name: 'string');

  static final StringType _instance = StringType._();

  @override
  String get className => 'StringType';

  static const List<String> _classHierarchy = [
    'StringType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates a StringValue from native Dart string.
  ///
  /// #### Parameters
  /// - `nativeValue` - Dart String (UTF-8 compatible)
  ///
  /// #### Throws
  /// - `ArgumentError` - If nativeValue is not String
  ///
  /// #### Example
  /// ```dart
  /// final str = StringType.create('Hello World');
  /// print(str.nativeValue); // Hello World
  /// print(str.length); // 11
  /// ```
  static StringValue create(dynamic nativeValue) {
    if (nativeValue is! String) {
      throw ArgumentError.value(
        nativeValue,
        'nativeValue',
        'StringType requires String value',
      );
    }
    return StringValue(nativeValue);
  }

  /// Gets the singleton type instance for use in type definitions.
  static StringType get type => _instance;

  @override
  TypedValue createValue(dynamic nativeValue) => create(nativeValue);
}

/// UTF-8 string value.
///
/// Holds a UTF-8 encoded text string. Provides factory methods for
/// creating from UTF-8 strings or hexadecimal representations.
///
/// #### Example
/// ```dart
/// // From string
/// final str1 = StringValue('Hello World');
/// print(str1.toBytes()); // UTF-8 bytes
///
/// // From UTF-8 factory
/// final str2 = StringValue.fromUTF8('Hello');
///
/// // From hex
/// final str3 = StringValue.fromHex('48656c6c6f'); // "Hello"
/// print(str3.nativeValue); // Hello
/// ```
@immutable
final class StringValue extends TypedValue {
  /// Creates a String value.
  ///
  /// #### Parameters
  /// - `value` - Dart String to encode
  StringValue(this.value) : super(StringType._instance);

  /// String value.
  final String value;

  @override
  String get className => 'StringValue';

  static const List<String> _classHierarchy = ['StringValue', 'TypedValue'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  String get nativeValue => value;

  /// Encodes string as UTF-8 bytes.
  ///
  /// #### Returns
  /// `List<int>` - UTF-8 encoded byte array
  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() => utf8.encode(value);

  /// Creates a StringValue from a UTF-8 string.
  ///
  /// #### Parameters
  /// - `value` - UTF-8 string
  static StringValue fromUTF8(String value) => StringValue(value);

  /// Creates a StringValue from a hex-encoded string.
  ///
  /// #### Parameters
  /// - `hexValue` - Hexadecimal string (UTF-8 bytes encoded as hex)
  /// - `allowMalformed` - If true, replaces invalid UTF-8 sequences with
  ///   replacement character (U+FFFD) instead of throwing
  ///
  /// #### Throws
  /// - `FormatException` - If hex string has odd length or invalid characters,
  ///   or if `allowMalformed` is false and bytes contain invalid UTF-8
  static StringValue fromHex(String hexValue, {bool allowMalformed = false}) {
    final Uint8List bytes = HexUtils.hexToBytes(hexValue);
    final String decoded = utf8.decode(bytes, allowMalformed: allowMalformed);
    return StringValue(decoded);
  }

  /// Concatenates this string with another StringValue.
  StringValue operator +(StringValue other) => StringValue(value + other.value);

  /// Concatenates this string with a Dart String.
  StringValue concat(String other) => StringValue(value + other);

  /// Returns a substring from start to end (exclusive).
  StringValue substring(int start, [int? end]) =>
      StringValue(value.substring(start, end));

  /// Splits the string by a delimiter.
  List<StringValue> split(String delimiter) =>
      value.split(delimiter).map((s) => StringValue(s)).toList();

  /// Trims whitespace from both ends.
  StringValue trim() => StringValue(value.trim());

  /// Trims whitespace from the left side.
  StringValue trimLeft() => StringValue(value.trimLeft());

  /// Trims whitespace from the right side.
  StringValue trimRight() => StringValue(value.trimRight());

  /// Converts to uppercase.
  StringValue toUpperCase() => StringValue(value.toUpperCase());

  /// Converts to lowercase.
  StringValue toLowerCase() => StringValue(value.toLowerCase());

  /// Checks if string starts with a prefix.
  bool startsWith(String prefix, [int index = 0]) =>
      value.startsWith(prefix, index);

  /// Checks if string ends with a suffix.
  bool endsWith(String suffix) => value.endsWith(suffix);

  /// Checks if string contains a substring.
  bool contains(String other, [int startIndex = 0]) =>
      value.contains(other, startIndex);

  /// Returns the index of the first occurrence of a substring, or -1.
  int indexOf(String substring, [int start = 0]) =>
      value.indexOf(substring, start);

  /// Returns the index of the last occurrence of a substring, or -1.
  int lastIndexOf(String substring, [int? start]) =>
      value.lastIndexOf(substring, start);

  /// Replaces all occurrences of a pattern with a replacement.
  StringValue replaceAll(String from, String replace) =>
      StringValue(value.replaceAll(from, replace));

  /// Replaces the first occurrence of a pattern with a replacement.
  StringValue replaceFirst(String from, String replace, [int startIndex = 0]) =>
      StringValue(value.replaceFirst(from, replace, startIndex));

  /// Pads string on the left to reach a target length.
  StringValue padLeft(int width, [String padding = ' ']) =>
      StringValue(value.padLeft(width, padding));

  /// Pads string on the right to reach a target length.
  StringValue padRight(int width, [String padding = ' ']) =>
      StringValue(value.padRight(width, padding));

  /// Returns true if the string is empty.
  bool get isEmpty => value.isEmpty;

  /// Returns true if the string is not empty.
  bool get isNotEmpty => value.isNotEmpty;

  /// Returns the length of the string in characters.
  int get length => value.length;

  /// Returns the character at the specified index.
  String charAt(int index) => value[index];

  /// Returns the character codes of the string.
  List<int> get codeUnits => value.codeUnits;

  /// Returns the Unicode code points as an iterable.
  Iterable<int> get runes => value.runes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StringValue && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
