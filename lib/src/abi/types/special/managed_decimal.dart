import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../core/type_system.dart';

/// ManagedDecimal type for fixed-point decimals with scale metadata.
///
/// Represents fixed-point decimal numbers with a specified scale
/// (number of decimal places). Commonly used for token amounts, prices, and
/// financial calculations where precision is critical.
@immutable
final class ManagedDecimalType extends CustomType {
  ManagedDecimalType._({
    required this.scale,
    this.isSigned = false,
    this.isVariable = false,
  }) : super(
         name: isSigned
             ? (isVariable
                   ? 'ManagedDecimalSigned<usize>'
                   : 'ManagedDecimalSigned<$scale>')
             : (isVariable
                   ? 'ManagedDecimal<usize>'
                   : 'ManagedDecimal<$scale>'),
       ) {
    if (!isVariable && (scale < 0 || scale > 255)) {
      throw ArgumentError.value(
        scale,
        'scale',
        'Scale must be between 0 and 255',
      );
    }
  }

  /// Creates unsigned ManagedDecimal type with fixed scale.
  ///
  /// #### Example
  /// ```dart
  /// final tokenType = ManagedDecimalType.of(18);
  /// ```
  factory ManagedDecimalType.of(int scale) =>
      ManagedDecimalType._(scale: scale);

  /// Creates signed ManagedDecimal type with fixed scale.
  ///
  /// #### Example
  /// ```dart
  /// final signedType = ManagedDecimalType.signed(4);
  /// ```
  factory ManagedDecimalType.signed(int scale) =>
      ManagedDecimalType._(scale: scale, isSigned: true);

  /// Creates variable-scale ManagedDecimal type.
  ///
  /// #### Example
  /// ```dart
  /// final varType = ManagedDecimalType.variable(2);
  /// ```
  factory ManagedDecimalType.variable(int scale, {bool isSigned = false}) =>
      ManagedDecimalType._(scale: scale, isSigned: isSigned, isVariable: true);

  /// Creates ManagedDecimalValue from native value.
  ///
  /// #### Example
  /// ```dart
  /// final value = ManagedDecimalType.create(18, 19.99);
  /// ```
  static ManagedDecimalValue create(
    int scale,
    dynamic nativeValue, {
    bool isSigned = false,
  }) {
    final type = ManagedDecimalType.of(scale);
    return type.createValue(nativeValue) as ManagedDecimalValue;
  }

  /// Scale (number of decimal places) when isVariable is false.
  final int scale;

  /// Whether this is a signed decimal.
  final bool isSigned;

  /// Whether the scale is variable (runtime-determined, encoded as U32).
  final bool isVariable;

  @override
  String get className =>
      isSigned ? 'ManagedDecimalSignedType' : 'ManagedDecimalType';

  static const List<String> _classHierarchySigned = [
    'ManagedDecimalSignedType',
    'CustomType',
    'AbiType',
  ];

  static const List<String> _classHierarchyUnsigned = [
    'ManagedDecimalType',
    'CustomType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy =>
      isSigned ? _classHierarchySigned : _classHierarchyUnsigned;

  @override
  TypeCardinality get cardinality => TypeCardinalityExtension.variable();

  /// Creates a ManagedDecimalValue from native value.
  ///
  /// #### Parameters
  /// - `nativeValue` - num (double/int), BigInt, or String representation
  ///
  /// #### Returns
  /// `ManagedDecimalValue` - Instance with the data
  ///
  /// #### Throws
  /// - `ArgumentError` - If nativeValue is not num, BigInt, or String
  ///
  /// #### Example
  /// ```dart
  /// final type = ManagedDecimalType.of(2);
  ///
  /// // From double
  /// final val1 = type.createValue(19.99);
  ///
  /// // From BigInt (raw value)
  /// final val2 = type.createValue(BigInt.from(1999)); // 19.99
  ///
  /// // From string
  /// final val3 = type.createValue('19.99');
  /// ```
  @override
  TypedValue createValue(dynamic nativeValue) {
    if (nativeValue is num) {
      return ManagedDecimalValue.fromDouble(
        nativeValue.toDouble(),
        scale: scale,
        isSigned: isSigned,
        isVariable: isVariable,
      );
    }

    if (nativeValue is BigInt) {
      return ManagedDecimalValue(
        nativeValue,
        scale: scale,
        isSigned: isSigned,
        isVariable: isVariable,
      );
    }

    if (nativeValue is String) {
      return ManagedDecimalValue.fromString(
        nativeValue,
        scale: scale,
        isSigned: isSigned,
        isVariable: isVariable,
      );
    }

    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'ManagedDecimal requires num, BigInt, or String',
    );
  }
}

/// ManagedDecimal value representing a fixed-point decimal.
///
/// Holds a fixed-point decimal number as a raw BigInt value with
/// scale metadata. Provides conversions to/from double and decimal strings.
///
/// #### Example
/// ```dart
/// // From double
/// final price = ManagedDecimalValue.fromDouble(19.99, scale: 2);
/// print(price.toDecimalString()); // 19.99
/// print(price.nativeValue); // BigInt(1999) - raw value
/// print(price.toDouble()); // 19.99
///
/// // From string
/// final amount = ManagedDecimalValue.fromString('123.456', scale: 3);
/// print(amount.toDecimalString()); // 123.456
///
/// // From raw BigInt
/// final raw = ManagedDecimalValue(BigInt.from(1999), scale: 2);
/// print(raw.toDecimalString()); // 19.99
/// ```
@immutable
final class ManagedDecimalValue extends TypedValue {
  /// Creates a ManagedDecimal value.
  ///
  /// #### Parameters
  /// - `value` - Raw BigInt value (without decimal point)
  /// - `scale` - Number of decimal places (0-255 when isVariable=false)
  /// - `isSigned` - Whether this is signed (default: false)
  /// - `isVariable` - Whether scale is variable (default: false)
  ///
  /// #### Throws
  /// - `ArgumentError` - If scale out of range
  /// - `ArgumentError` - If unsigned value is negative
  ///
  /// #### Example
  /// ```dart
  /// // 19.99 with scale 2 = raw value 1999
  /// final value = ManagedDecimalValue(BigInt.from(1999), scale: 2);
  /// ```
  ManagedDecimalValue(
    this.value, {
    required this.scale,
    this.isSigned = false,
    this.isVariable = false,
  }) : super(
         ManagedDecimalType._(
           scale: scale,
           isSigned: isSigned,
           isVariable: isVariable,
         ),
       ) {
    if (!isVariable && (scale < 0 || scale > 255)) {
      throw ArgumentError.value(
        scale,
        'scale',
        'Scale must be between 0 and 255',
      );
    }

    if (!isSigned && value.isNegative) {
      throw ArgumentError.value(
        value,
        'value',
        'Unsigned ManagedDecimal cannot have negative value',
      );
    }
  }

  /// Creates a ManagedDecimal from a double value.
  ///
  /// #### Parameters
  /// - `value` - Double value to convert
  /// - `scale` - Number of decimal places
  /// - `isSigned` - Whether signed (default: false)
  /// - `isVariable` - Whether scale is variable (default: false)
  ///
  /// #### Example
  /// ```dart
  /// final price = ManagedDecimalValue.fromDouble(19.99, scale: 2);
  /// print(price.nativeValue); // BigInt(1999)
  /// print(price.toDecimalString()); // 19.99
  ///
  /// final negative = ManagedDecimalValue.fromDouble(
  ///   -123.45,
  ///   scale: 2,
  ///   isSigned: true,
  /// );
  /// ```
  factory ManagedDecimalValue.fromDouble(
    double value, {
    required int scale,
    bool isSigned = false,
    bool isVariable = false,
  }) {
    String valueStr = value.toString();

    if (valueStr.contains('e') || valueStr.contains('E')) {
      valueStr = value.toStringAsFixed(scale);
    }

    return ManagedDecimalValue.fromString(
      valueStr,
      scale: scale,
      isSigned: isSigned,
      isVariable: isVariable,
    );
  }

  /// Creates a ManagedDecimal from a string representation.
  ///
  /// #### Parameters
  /// - `value` - Decimal string (e.g., "123.456")
  /// - `scale` - Number of decimal places
  /// - `isSigned` - Whether signed (default: false)
  /// - `isVariable` - Whether scale is variable (default: false)
  ///
  /// #### Throws
  /// - `ArgumentError` - If string format is invalid
  /// - `ArgumentError` - If fractional part exceeds scale
  ///
  /// #### Example
  /// ```dart
  /// final amount = ManagedDecimalValue.fromString('19.99', scale: 2);
  /// print(amount.nativeValue); // BigInt(1999)
  ///
  /// final precise = ManagedDecimalValue.fromString('0.123456', scale: 6);
  /// print(precise.toDecimalString()); // 0.123456
  /// ```
  factory ManagedDecimalValue.fromString(
    String value, {
    required int scale,
    bool isSigned = false,
    bool isVariable = false,
  }) {
    final List<String> parts = value.split('.');
    if (parts.length > 2) {
      throw ArgumentError.value(value, 'value', 'Invalid decimal format');
    }

    final String integerStr = parts[0].isEmpty ? '0' : parts[0];
    final BigInt integerPart = BigInt.parse(integerStr);
    final bool isNegative = integerPart.isNegative || value.startsWith('-');
    final BigInt absIntegerPart = integerPart.abs();

    BigInt fractionalPart = BigInt.zero;
    if (parts.length == 2) {
      if (scale == 0) {
        // When scale is 0, a fractional part is only valid if it's all zeros
        final bool allZeros = parts[1].split('').every((String c) => c == '0');
        if (!allZeros) {
          throw ArgumentError.value(
            value,
            'value',
            'Fractional part exceeds scale of $scale',
          );
        }
        // fractionalPart remains BigInt.zero
      } else {
        final String fractionalStr = parts[1].padRight(scale, '0');
        if (fractionalStr.length > scale) {
          throw ArgumentError.value(
            value,
            'value',
            'Fractional part exceeds scale of $scale',
          );
        }
        fractionalPart = BigInt.parse(fractionalStr);
      }
    }

    final BigInt multiplier = BigInt.from(10).pow(scale);
    BigInt rawValue = absIntegerPart * multiplier + fractionalPart;

    if (isNegative) {
      rawValue = -rawValue;
    }

    return ManagedDecimalValue(
      rawValue,
      scale: scale,
      isSigned: isSigned,
      isVariable: isVariable,
    );
  }

  /// Underlying integer value (raw value without decimal point).
  final BigInt value;

  /// Scale (number of decimal places).
  final int scale;

  /// Whether this is a signed decimal.
  final bool isSigned;

  /// Whether the scale is variable (encoded as U32 in data).
  final bool isVariable;

  @override
  String get className =>
      isSigned ? 'ManagedDecimalSignedValue' : 'ManagedDecimalValue';

  static const List<String> _classHierarchySigned = [
    'ManagedDecimalSignedValue',
    'TypedValue',
  ];

  static const List<String> _classHierarchyUnsigned = [
    'ManagedDecimalValue',
    'TypedValue',
  ];

  @override
  List<String> get classHierarchy =>
      isSigned ? _classHierarchySigned : _classHierarchyUnsigned;

  @override
  BigInt get nativeValue => value;

  /// Converts to a string with proper decimal formatting.
  ///
  /// #### Returns
  /// Decimal string with trailing zeros removed
  ///
  /// #### Example
  /// ```dart
  /// final val1 = ManagedDecimalValue.fromDouble(19.99, scale: 2);
  /// print(val1.toDecimalString()); // 19.99
  ///
  /// final val2 = ManagedDecimalValue.fromDouble(20.00, scale: 2);
  /// print(val2.toDecimalString()); // 20 (trailing zeros removed)
  ///
  /// final val3 = ManagedDecimalValue.fromString('0.123000', scale: 6);
  /// print(val3.toDecimalString()); // 0.123
  /// ```
  String toDecimalString() {
    final BigInt divisor = BigInt.from(10).pow(scale);
    final BigInt integerPart = value ~/ divisor;
    final String fractionalPart = (value.abs() % divisor).toString().padLeft(
      scale,
      '0',
    );

    if (scale == 0) {
      return integerPart.toString();
    }
    String trimmedFractional = fractionalPart;
    while (trimmedFractional.endsWith('0') && trimmedFractional.length > 1) {
      trimmedFractional = trimmedFractional.substring(
        0,
        trimmedFractional.length - 1,
      );
    }

    if (trimmedFractional == '0') {
      return integerPart.toString();
    }

    return '$integerPart.$trimmedFractional';
  }

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() {
    final List<int> valueBytes = isSigned
        ? _encodeBigInt(value)
        : _encodeUnsignedBigInt(value);

    if (!isVariable) {
      return valueBytes;
    }

    final BytesBuilder builder = BytesBuilder(copy: false);
    builder.add(valueBytes);
    final List<int> scaleBytes = <int>[
      (scale >> 24) & 0xFF,
      (scale >> 16) & 0xFF,
      (scale >> 8) & 0xFF,
      scale & 0xFF,
    ];
    builder.add(scaleBytes);
    return builder.takeBytes();
  }

  /// Encodes a signed BigInt.
  static List<int> _encodeBigInt(BigInt value) {
    if (value == BigInt.zero) {
      return <int>[];
    }

    final bool isNegative = value.isNegative;
    final BigInt absValue = value.abs();
    final List<int> bytes = <int>[];
    BigInt temp = absValue;
    while (temp > BigInt.zero) {
      bytes.insert(0, (temp & BigInt.from(0xFF)).toInt());
      temp = temp >> 8;
    }

    if (bytes.isEmpty) {
      return <int>[];
    }
    if (isNegative) {
      for (int i = 0; i < bytes.length; i++) {
        bytes[i] = ~bytes[i] & 0xFF;
      }
      int carry = 1;
      for (int i = bytes.length - 1; i >= 0 && carry > 0; i--) {
        final int sum = bytes[i] + carry;
        bytes[i] = sum & 0xFF;
        carry = sum >> 8;
      }
      if ((bytes[0] & 0x80) == 0) {
        bytes.insert(0, 0xFF);
      }
    } else {
      if ((bytes[0] & 0x80) != 0) {
        bytes.insert(0, 0x00);
      }
    }

    return bytes;
  }

  /// Encodes an unsigned BigInt.
  static List<int> _encodeUnsignedBigInt(BigInt value) {
    if (value == BigInt.zero) {
      return <int>[];
    }

    if (value.isNegative) {
      throw ArgumentError.value(
        value,
        'value',
        'Cannot encode negative value as unsigned',
      );
    }

    final List<int> bytes = <int>[];
    BigInt temp = value;
    while (temp > BigInt.zero) {
      bytes.insert(0, (temp & BigInt.from(0xFF)).toInt());
      temp = temp >> 8;
    }

    return bytes;
  }

  @override
  String toString() => toDecimalString();
}

/// Convenience type for signed ManagedDecimal.
@immutable
final class ManagedDecimalSignedType extends ManagedDecimalType {
  /// Creates a signed ManagedDecimal type.
  ManagedDecimalSignedType({required super.scale, super.isVariable})
    : super._(isSigned: true);
}

/// Convenience value for signed ManagedDecimal.
@immutable
final class ManagedDecimalSignedValue extends ManagedDecimalValue {
  /// Creates a signed ManagedDecimal value.
  ManagedDecimalSignedValue(
    super.value, {
    required super.scale,
    super.isVariable,
  }) : super(isSigned: true);

  /// Creates a signed ManagedDecimal from a double.
  factory ManagedDecimalSignedValue.fromDouble(
    double value, {
    required int scale,
    bool isVariable = false,
  }) {
    final ManagedDecimalValue parsed = ManagedDecimalValue.fromDouble(
      value,
      scale: scale,
      isSigned: true,
      isVariable: isVariable,
    );
    return ManagedDecimalSignedValue(
      parsed.value,
      scale: parsed.scale,
      isVariable: isVariable,
    );
  }

  /// Creates a signed ManagedDecimal from a string.
  factory ManagedDecimalSignedValue.fromString(
    String value, {
    required int scale,
    bool isVariable = false,
  }) {
    final ManagedDecimalValue parsed = ManagedDecimalValue.fromString(
      value,
      scale: scale,
      isSigned: true,
      isVariable: isVariable,
    );
    return ManagedDecimalSignedValue(
      parsed.value,
      scale: parsed.scale,
      isVariable: isVariable,
    );
  }
}
