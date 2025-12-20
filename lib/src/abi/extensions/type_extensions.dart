/// Extension methods for cleaner type handling and error management.
import '../core/types.dart';

/// Type-safe helpers for ABI type and value handling.
extension AbiTypeFactoryExtensions on AbiTypeFactory {
  /// Creates an AbiType from a type string and ensures it matches expected type.
  ///
  /// #### Parameters
  /// - `typeString` - Type formula (e.g., `Option<U32>`, `List<Address>`)
  ///
  /// #### Returns
  /// `T` - Type instance of T
  ///
  /// #### Throws
  /// - `ArgumentError` - If parsed type is not instance of T
  T fromStringOrThrow<T extends AbiType>(String typeString) {
    final type = fromString(typeString);
    if (type is! T) {
      throw ArgumentError(
        'Expected ${T.toString()}, got ${type.runtimeType} for type string "$typeString".\n'
        'This usually means the type formula does not match the expected type class.\n'
        'Example: fromStringOrThrow<OptionType>("U32") will fail because U32 is not an Option type.',
      );
    }
    return type;
  }
}

/// Type-safe value creation extensions for AbiType.
extension AbiTypeOrThrowExtensions on AbiType {
  /// Creates a TypedValue from native value and ensures it matches expected type.
  ///
  /// #### Parameters
  /// - `nativeValue` - Native Dart value (e.g., int, String, List)
  ///
  /// #### Returns
  /// `T` - TypedValue instance of T
  ///
  /// #### Throws
  /// - `ArgumentError` - If created value is not instance of T
  T createValueOrThrow<T extends TypedValue>(dynamic nativeValue) {
    final value = createValue(nativeValue);
    if (value is! T) {
      throw ArgumentError(
        'Expected ${T.toString()}, got ${value.runtimeType} for native value "$nativeValue".\n'
        'This usually means the type does not produce values of the expected class.\n'
        'Type: $runtimeType, Native value type: ${nativeValue.runtimeType}',
      );
    }
    return value;
  }
}

/// Extensions for TypedValue to provide type-safe conversions.
extension TypedValueExtensions on TypedValue {
  /// Casts this value to type [T] with a clear error message if the cast fails.
  ///
  /// #### Returns
  /// `T` - This value as type T
  ///
  /// #### Throws
  /// - `ArgumentError` - If this value is not an instance of T
  T asOrThrow<T extends TypedValue>() {
    if (this is! T) {
      throw ArgumentError(
        'Expected ${T.toString()}, got $runtimeType.\n'
        'Native value: $nativeValue (${nativeValue.runtimeType})',
      );
    }
    return this as T;
  }

  /// Attempts to cast this value to type [T], returning null if the cast fails.
  ///
  /// #### Returns
  /// `T?` - This value as type T, or null if not an instance of T
  T? asOrNull<T extends TypedValue>() {
    return this is T ? this as T : null;
  }
}

/// Extensions for convenient type checking with clear error messages.
extension AbiTypeValidationExtensions on AbiType {
  /// Ensures this type is an instance of [T], throwing with a custom message if not.
  ///
  /// #### Parameters
  /// - `message` - Custom error message to include in the exception
  ///
  /// #### Returns
  /// `T` - This type as T
  ///
  /// #### Throws
  /// - `ArgumentError` - If this type is not an instance of T
  T requireType<T extends AbiType>(String message) {
    if (this is! T) {
      throw ArgumentError(
        '$message\n'
        'Expected ${T.toString()}, got $runtimeType',
      );
    }
    return this as T;
  }
}

/// Extensions for TypedValue validation with clear error messages.
extension TypedValueValidationExtensions on TypedValue {
  /// Ensures this value is an instance of [T], throwing with a custom message if not.
  ///
  /// #### Parameters
  /// - `message` - Custom error message to include in the exception
  ///
  /// #### Returns
  /// `T` - This value as T
  ///
  /// #### Throws
  /// - `ArgumentError` - If this value is not an instance of T
  T requireValueType<T extends TypedValue>(String message) {
    if (this is! T) {
      throw ArgumentError(
        '$message\n'
        'Expected ${T.toString()}, got $runtimeType\n'
        'Native value: $nativeValue (${nativeValue.runtimeType})',
      );
    }
    return this as T;
  }
}
