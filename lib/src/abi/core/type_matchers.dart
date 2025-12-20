/// Type pattern matching utilities for ABI type system.
import '../types/collections/array.dart';
import '../types/collections/list.dart';
import '../types/collections/option.dart';
import '../types/composite/enum.dart';
import '../types/composite/explicit_enum.dart';
import '../types/composite/struct.dart';
import '../types/composite/tuple.dart';
import '../types/primitives/address.dart';
import '../types/primitives/boolean.dart';
import '../types/primitives/bytes.dart';
import '../types/primitives/numerical.dart';
import '../types/primitives/string.dart';
import '../types/special/code_metadata.dart';
import '../types/special/h256.dart';
import '../types/special/managed_decimal.dart';
import '../types/special/nothing.dart';
import '../types/special/token_identifier.dart';
import '../types/special/variadic.dart';
import 'type_system.dart';

/// Callback signature for type pattern matching.
///
/// Function type that returns value of type T.
typedef TypeCallback<T> = T Function();

/// Pattern matches on AbiType and executes appropriate callback.
///
/// #### Parameters
/// - `type` - AbiType to pattern match
/// - `callbacks` - TypeMatchCallbacks with handlers for each type category
///
/// #### Returns
/// `T` - Result of executed callback
///
/// #### Throws
/// - `UnsupportedError` - If no callback provided for matched type
T onTypeSelect<T>(AbiType type, TypeMatchCallbacks<T> callbacks) {
  if (type is U8Type ||
      type is U16Type ||
      type is U32Type ||
      type is U64Type ||
      type is I8Type ||
      type is I16Type ||
      type is I32Type ||
      type is I64Type ||
      type is BigUIntType ||
      type is BigIntType ||
      type is AddressType ||
      type is BooleanType ||
      type is StringType ||
      type is BytesType) {
    return callbacks.onPrimitive();
  }

  if (type is OptionType) {
    return callbacks.onOption();
  }

  if (type is ListType) {
    return callbacks.onList();
  }

  if (type is ArrayType) {
    return callbacks.onArray();
  }

  if (type is StructType) {
    return callbacks.onStruct();
  }

  if (type is TupleType) {
    return callbacks.onTuple();
  }

  if (type is EnumType) {
    return callbacks.onEnum();
  }

  if (type is ExplicitEnumType) {
    return callbacks.onExplicitEnum();
  }

  if (type is VariadicType) {
    return callbacks.onVariadic();
  }

  if (type is NothingType) {
    return callbacks.onNothing();
  }

  if (type is H256Type) {
    return callbacks.onH256();
  }

  if (type is TokenIdentifierType) {
    return callbacks.onTokenIdentifier();
  }

  if (type is CodeMetadataType) {
    return callbacks.onCodeMetadata();
  }

  if (type is ManagedDecimalType) {
    return callbacks.onManagedDecimal();
  }

  if (type is ManagedDecimalSignedType) {
    return callbacks.onManagedDecimalSigned();
  }

  return callbacks.onOther();
}

/// Pattern matches on TypedValue and executes appropriate callback.
///
/// #### Parameters
/// - `value` - TypedValue to pattern match
/// - `callbacks` - ValueMatchCallbacks with handlers for each value category
///
/// #### Returns
/// `T` - Result of executed callback
///
/// #### Throws
/// - `UnsupportedError` - If no callback provided for matched value
T onTypedValueSelect<T>(TypedValue value, ValueMatchCallbacks<T> callbacks) {
  if (value is U8Value ||
      value is U16Value ||
      value is U32Value ||
      value is U64Value ||
      value is I8Value ||
      value is I16Value ||
      value is I32Value ||
      value is I64Value ||
      value is BigUIntValue ||
      value is BigIntValue ||
      value is AddressValue ||
      value is BooleanValue ||
      value is StringValue ||
      value is BytesValue) {
    return callbacks.onPrimitive();
  }

  if (value is OptionValue) {
    return callbacks.onOption();
  }

  if (value is ListValue) {
    return callbacks.onList();
  }

  if (value is ArrayValue) {
    return callbacks.onArray();
  }

  if (value is StructValue) {
    return callbacks.onStruct();
  }

  if (value is TupleValue) {
    return callbacks.onTuple();
  }

  if (value is EnumValue) {
    return callbacks.onEnum();
  }

  if (value is ExplicitEnumValue) {
    return callbacks.onExplicitEnum();
  }

  if (value is VariadicValue) {
    return callbacks.onVariadic();
  }

  if (value is NothingValue) {
    return callbacks.onNothing();
  }

  if (value is H256Value) {
    return callbacks.onH256();
  }

  if (value is TokenIdentifierValue) {
    return callbacks.onTokenIdentifier();
  }

  if (value is CodeMetadataValue) {
    return callbacks.onCodeMetadata();
  }

  if (value is ManagedDecimalValue) {
    return callbacks.onManagedDecimal();
  }

  if (value is ManagedDecimalSignedValue) {
    return callbacks.onManagedDecimalSigned();
  }

  return callbacks.onOther();
}

/// Callbacks for type pattern matching.
class TypeMatchCallbacks<T> {
  /// Creates type match callbacks.
  ///
  /// #### Parameters
  /// - `onPrimitive` - Handler for primitive types (optional)
  /// - `onOption` - Handler for Option types (optional)
  /// - `onList` - Handler for List types (optional)
  /// - `onArray` - Handler for Array types (optional)
  /// - `onStruct` - Handler for Struct types (optional)
  /// - `onTuple` - Handler for Tuple types (optional)
  /// - `onEnum` - Handler for Enum types (optional)
  /// - `onExplicitEnum` - Handler for ExplicitEnum types (optional)
  /// - `onVariadic` - Handler for Variadic types (optional)
  /// - `onNothing` - Handler for Nothing type (optional)
  /// - `onH256` - Handler for H256 type (optional)
  /// - `onTokenIdentifier` - Handler for TokenIdentifier type (optional)
  /// - `onCodeMetadata` - Handler for CodeMetadata type (optional)
  /// - `onManagedDecimal` - Handler for ManagedDecimal type (optional)
  /// - `onManagedDecimalSigned` - Handler for ManagedDecimalSigned type (optional)
  /// - `onOther` - Handler for unknown types (optional)
  ///
  /// #### Throws
  /// - `UnsupportedError` - If callback invoked but not provided
  TypeMatchCallbacks({
    TypeCallback<T>? onPrimitive,
    TypeCallback<T>? onOption,
    TypeCallback<T>? onList,
    TypeCallback<T>? onArray,
    TypeCallback<T>? onStruct,
    TypeCallback<T>? onTuple,
    TypeCallback<T>? onEnum,
    TypeCallback<T>? onExplicitEnum,
    TypeCallback<T>? onVariadic,
    TypeCallback<T>? onNothing,
    TypeCallback<T>? onH256,
    TypeCallback<T>? onTokenIdentifier,
    TypeCallback<T>? onCodeMetadata,
    TypeCallback<T>? onManagedDecimal,
    TypeCallback<T>? onManagedDecimalSigned,
    TypeCallback<T>? onOther,
  }) : onPrimitive = onPrimitive ?? _unsupported('primitive type'),
       onOption = onOption ?? _unsupported('Option type'),
       onList = onList ?? _unsupported('List type'),
       onArray = onArray ?? _unsupported('Array type'),
       onStruct = onStruct ?? _unsupported('Struct type'),
       onTuple = onTuple ?? _unsupported('Tuple type'),
       onEnum = onEnum ?? _unsupported('Enum type'),
       onExplicitEnum = onExplicitEnum ?? _unsupported('ExplicitEnum type'),
       onVariadic = onVariadic ?? _unsupported('Variadic type'),
       onNothing = onNothing ?? _unsupported('Nothing type'),
       onH256 = onH256 ?? _unsupported('H256 type'),
       onTokenIdentifier =
           onTokenIdentifier ?? _unsupported('TokenIdentifier type'),
       onCodeMetadata = onCodeMetadata ?? _unsupported('CodeMetadata type'),
       onManagedDecimal =
           onManagedDecimal ?? _unsupported('ManagedDecimal type'),
       onManagedDecimalSigned =
           onManagedDecimalSigned ?? _unsupported('ManagedDecimalSigned type'),
       onOther = onOther ?? _unsupported('unknown type');

  /// Callback for primitive types.
  final TypeCallback<T> onPrimitive;

  /// Callback for Option types.
  final TypeCallback<T> onOption;

  /// Callback for List types.
  final TypeCallback<T> onList;

  /// Callback for Array types.
  final TypeCallback<T> onArray;

  /// Callback for Struct types.
  final TypeCallback<T> onStruct;

  /// Callback for Tuple types.
  final TypeCallback<T> onTuple;

  /// Callback for Enum types.
  final TypeCallback<T> onEnum;

  /// Callback for ExplicitEnum types.
  final TypeCallback<T> onExplicitEnum;

  /// Callback for Variadic types.
  final TypeCallback<T> onVariadic;

  /// Callback for Nothing type.
  final TypeCallback<T> onNothing;

  /// Callback for H256 type.
  final TypeCallback<T> onH256;

  /// Callback for TokenIdentifier type.
  final TypeCallback<T> onTokenIdentifier;

  /// Callback for CodeMetadata type.
  final TypeCallback<T> onCodeMetadata;

  /// Callback for ManagedDecimal type.
  final TypeCallback<T> onManagedDecimal;

  /// Callback for ManagedDecimalSigned type.
  final TypeCallback<T> onManagedDecimalSigned;

  /// Callback for unknown types.
  final TypeCallback<T> onOther;

  static TypeCallback<T> _unsupported<T>(String typeName) {
    return () => throw UnsupportedError('Unsupported $typeName');
  }
}

/// Callbacks for value pattern matching.
class ValueMatchCallbacks<T> {
  /// Creates value match callbacks.
  ///
  /// #### Parameters
  /// - `onPrimitive` - Handler for primitive values (optional)
  /// - `onOption` - Handler for Option values (optional)
  /// - `onList` - Handler for List values (optional)
  /// - `onArray` - Handler for Array values (optional)
  /// - `onStruct` - Handler for Struct values (optional)
  /// - `onTuple` - Handler for Tuple values (optional)
  /// - `onEnum` - Handler for Enum values (optional)
  /// - `onExplicitEnum` - Handler for ExplicitEnum values (optional)
  /// - `onVariadic` - Handler for Variadic values (optional)
  /// - `onNothing` - Handler for Nothing value (optional)
  /// - `onH256` - Handler for H256 value (optional)
  /// - `onTokenIdentifier` - Handler for TokenIdentifier value (optional)
  /// - `onCodeMetadata` - Handler for CodeMetadata value (optional)
  /// - `onManagedDecimal` - Handler for ManagedDecimal value (optional)
  /// - `onManagedDecimalSigned` - Handler for ManagedDecimalSigned value (optional)
  /// - `onOther` - Handler for unknown values (optional)
  ///
  /// #### Throws
  /// - `UnsupportedError` - If callback invoked but not provided
  ValueMatchCallbacks({
    TypeCallback<T>? onPrimitive,
    TypeCallback<T>? onOption,
    TypeCallback<T>? onList,
    TypeCallback<T>? onArray,
    TypeCallback<T>? onStruct,
    TypeCallback<T>? onTuple,
    TypeCallback<T>? onEnum,
    TypeCallback<T>? onExplicitEnum,
    TypeCallback<T>? onVariadic,
    TypeCallback<T>? onNothing,
    TypeCallback<T>? onH256,
    TypeCallback<T>? onTokenIdentifier,
    TypeCallback<T>? onCodeMetadata,
    TypeCallback<T>? onManagedDecimal,
    TypeCallback<T>? onManagedDecimalSigned,
    TypeCallback<T>? onOther,
  }) : onPrimitive = onPrimitive ?? _unsupported('primitive value'),
       onOption = onOption ?? _unsupported('Option value'),
       onList = onList ?? _unsupported('List value'),
       onArray = onArray ?? _unsupported('Array value'),
       onStruct = onStruct ?? _unsupported('Struct value'),
       onTuple = onTuple ?? _unsupported('Tuple value'),
       onEnum = onEnum ?? _unsupported('Enum value'),
       onExplicitEnum = onExplicitEnum ?? _unsupported('ExplicitEnum value'),
       onVariadic = onVariadic ?? _unsupported('Variadic value'),
       onNothing = onNothing ?? _unsupported('Nothing value'),
       onH256 = onH256 ?? _unsupported('H256 value'),
       onTokenIdentifier =
           onTokenIdentifier ?? _unsupported('TokenIdentifier value'),
       onCodeMetadata = onCodeMetadata ?? _unsupported('CodeMetadata value'),
       onManagedDecimal =
           onManagedDecimal ?? _unsupported('ManagedDecimal value'),
       onManagedDecimalSigned =
           onManagedDecimalSigned ?? _unsupported('ManagedDecimalSigned value'),
       onOther = onOther ?? _unsupported('unknown value');

  /// Callback for primitive values.
  final TypeCallback<T> onPrimitive;

  /// Callback for Option values.
  final TypeCallback<T> onOption;

  /// Callback for List values.
  final TypeCallback<T> onList;

  /// Callback for Array values.
  final TypeCallback<T> onArray;

  /// Callback for Struct values.
  final TypeCallback<T> onStruct;

  /// Callback for Tuple values.
  final TypeCallback<T> onTuple;

  /// Callback for Enum values.
  final TypeCallback<T> onEnum;

  /// Callback for ExplicitEnum values.
  final TypeCallback<T> onExplicitEnum;

  /// Callback for Variadic values.
  final TypeCallback<T> onVariadic;

  /// Callback for Nothing value.
  final TypeCallback<T> onNothing;

  /// Callback for H256 value.
  final TypeCallback<T> onH256;

  /// Callback for TokenIdentifier value.
  final TypeCallback<T> onTokenIdentifier;

  /// Callback for CodeMetadata value.
  final TypeCallback<T> onCodeMetadata;

  /// Callback for ManagedDecimal value.
  final TypeCallback<T> onManagedDecimal;

  /// Callback for ManagedDecimalSigned value.
  final TypeCallback<T> onManagedDecimalSigned;

  /// Callback for unknown values.
  final TypeCallback<T> onOther;

  static TypeCallback<T> _unsupported<T>(String valueName) {
    return () => throw UnsupportedError('Unsupported $valueName');
  }
}
