/// Type conversion extensions for numerical values.
import '../types/primitives/numerical.dart';

/// Conversion methods for all numerical types.
extension NumericalConversions on NumericalValue {
  /// Converts to U8 (8-bit unsigned).
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is outside range
  U8Value toU8() => U8Value(asInt);

  /// Converts to U16 (16-bit unsigned).
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is outside range
  U16Value toU16() => U16Value(asInt);

  /// Converts to U32 (32-bit unsigned).
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is outside range
  U32Value toU32() => U32Value(asInt);

  /// Converts to U64 (64-bit unsigned).
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is negative
  U64Value toU64() => U64Value(asBigInt);

  /// Converts to BigUint (arbitrary precision unsigned).
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is negative
  BigUIntValue toBigUInt() => BigUIntValue(asBigInt);

  /// Converts to I8 (8-bit signed).
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is outside range
  I8Value toI8() => I8Value(asInt);

  /// Converts to I16 (16-bit signed).
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is outside range
  I16Value toI16() => I16Value(asInt);

  /// Converts to I32 (32-bit signed).
  ///
  /// #### Throws
  /// - `ArgumentError` - If value is outside range
  I32Value toI32() => I32Value(asInt);

  /// Converts to I64 (64-bit signed).
  I64Value toI64() => I64Value(asBigInt);

  /// Converts to BigInt (arbitrary precision signed).
  BigIntValue toBigInt() => BigIntValue(asBigInt);

  /// Attempts to convert to U8, returns null if out of range.
  U8Value? toU8OrNull() {
    try {
      return U8Value(asInt);
    } catch (_) {
      return null;
    }
  }

  /// Attempts to convert to U16, returns null if out of range.
  U16Value? toU16OrNull() {
    try {
      return U16Value(asInt);
    } catch (_) {
      return null;
    }
  }

  /// Attempts to convert to U32, returns null if out of range.
  U32Value? toU32OrNull() {
    try {
      return U32Value(asInt);
    } catch (_) {
      return null;
    }
  }

  /// Attempts to convert to U64, returns null if negative.
  U64Value? toU64OrNull() {
    try {
      return U64Value(asBigInt);
    } catch (_) {
      return null;
    }
  }

  /// Attempts to convert to BigUint, returns null if negative.
  BigUIntValue? toBigUIntOrNull() {
    try {
      return BigUIntValue(asBigInt);
    } catch (_) {
      return null;
    }
  }

  /// Attempts to convert to I8, returns null if out of range.
  I8Value? toI8OrNull() {
    try {
      return I8Value(asInt);
    } catch (_) {
      return null;
    }
  }

  /// Attempts to convert to I16, returns null if out of range.
  I16Value? toI16OrNull() {
    try {
      return I16Value(asInt);
    } catch (_) {
      return null;
    }
  }

  /// Attempts to convert to I32, returns null if out of range.
  I32Value? toI32OrNull() {
    try {
      return I32Value(asInt);
    } catch (_) {
      return null;
    }
  }

  /// Attempts to convert to I64, always succeeds.
  I64Value? toI64OrNull() {
    try {
      return I64Value(asBigInt);
    } catch (_) {
      return null;
    }
  }

  /// Attempts to convert to BigInt, always succeeds.
  BigIntValue? toBigIntOrNull() {
    try {
      return BigIntValue(asBigInt);
    } catch (_) {
      return null;
    }
  }

  /// Checks if value fits in U8 range.
  bool get canBeU8 {
    final int value = asInt;
    return value >= 0 && value <= u8Max;
  }

  /// Checks if value fits in U16 range.
  bool get canBeU16 {
    final int value = asInt;
    return value >= 0 && value <= u16Max;
  }

  /// Checks if value fits in U32 range.
  bool get canBeU32 {
    final int value = asInt;
    return value >= 0 && value <= u32Max;
  }

  /// Checks if value fits in U64 range.
  bool get canBeU64 {
    return asBigInt >= BigInt.zero && asBigInt <= u64Max;
  }

  /// Checks if value fits in I8 range.
  bool get canBeI8 {
    final int value = asInt;
    return value >= i8Min && value <= i8Max;
  }

  /// Checks if value fits in I16 range.
  bool get canBeI16 {
    final int value = asInt;
    return value >= i16Min && value <= i16Max;
  }

  /// Checks if value fits in I32 range.
  bool get canBeI32 {
    final int value = asInt;
    return value >= i32Min && value <= i32Max;
  }

  /// Checks if value fits in I64 range.
  bool get canBeI64 {
    return asBigInt >= i64Min && asBigInt <= i64Max;
  }

  /// Checks if value is non-negative.
  bool get isUnsigned => asBigInt >= BigInt.zero;

  /// Checks if value is negative.
  bool get isSigned => asBigInt < BigInt.zero;
}
