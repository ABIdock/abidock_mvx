import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../core/type_system.dart';
import 'numerical.dart';

/// Arbitrary precision floating-point type.
///
/// `BigFloat` has no portable wire form. Both top-level and nested encoding
/// emit whatever the VM placed in the value's managed buffer, and the VM fills
/// that buffer with an opaque serialisation of the arbitrary-precision float:
/// a version byte, one packed byte carrying rounding mode, accuracy, form and
/// sign, a 4-byte precision, a 4-byte exponent, then the mantissa words. It is
/// **not** a decimal string, the layout is a node implementation detail rather
/// than part of the ABI specification, and it cannot be reproduced portably.
///
/// **Note:** this SDK therefore has no `BigFloat` wire codec. The type exists
/// only so ABIs that *mention* `BigFloat` still load; encoding, decoding and
/// [BigFloatValue.toBytes] all throw. Dart-side values are surfaced as
/// [double] for local arithmetic and display.
@immutable
final class BigFloatType extends NumericalType {
  BigFloatType._() : super(name: 'BigFloat', sizeInBytes: null, isSigned: true);

  static final BigFloatType _instance = BigFloatType._();

  /// Singleton type instance.
  static BigFloatType get type => _instance;

  @override
  String get className => 'BigFloatType';

  static const List<String> _classHierarchy = <String>[
    'BigFloatType',
    'NumericalType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  String get fullyQualifiedName => 'multiversx:types:BigFloat';

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{'type': 'BigFloat'};

  @override
  BigFloatValue createValue(dynamic nativeValue) {
    if (nativeValue is double) return BigFloatValue(nativeValue);
    if (nativeValue is num) return BigFloatValue(nativeValue.toDouble());
    if (nativeValue is String) return BigFloatValue(double.parse(nativeValue));
    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'BigFloatType requires a num or numeric String',
    );
  }
}

/// Native value wrapper for [BigFloatType].
@immutable
final class BigFloatValue extends TypedValue {
  BigFloatValue(this.value) : super(BigFloatType._instance);

  /// The wrapped double value.
  final double value;

  @override
  double get nativeValue => value;

  /// Always throws; `BigFloat` has no portable wire form.
  ///
  /// The chain serialises `BigFloat` as an opaque arbitrary-precision-float
  /// blob (version byte, packed mode/accuracy/form/sign byte, precision,
  /// exponent, mantissa words), not as a decimal string. Emitting a decimal
  /// string here produced bytes the chain rejects, so the gap is surfaced
  /// loudly instead.
  ///
  /// #### Throws
  /// - `UnimplementedError` - Always
  @override
  Uint8List toBytes() {
    throw UnimplementedError(
      'BigFloat has no wire codec: the chain encodes it as an opaque '
      'arbitrary-precision float blob, not a decimal string.',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BigFloatValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BigFloatValue($value)';
}
