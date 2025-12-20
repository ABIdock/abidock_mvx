import 'dart:convert';
import 'dart:typed_data';

import '../../core/address.dart';
import '../../core/balance.dart';
import '../../utils/helpers.dart';
import '../../utils/sdk_exceptions.dart';
import '../codecs/binary_codec.dart';
import '../core/types.dart';

/// Deserializes smart contract query responses.
///
/// This class provides a simplified interface for deserializing ABI-encoded
/// values from base64 strings. It delegates all type-specific decoding to the
/// BinaryCodec, ensuring consistent behavior and avoiding code duplication.
///
/// The deserializer returns native Dart types (int, BigInt, String, List, Map)
/// rather than TypedValue instances, making it easier to work with the data.
final class AbiDeserializer {
  /// Creates deserializer with optional codec.
  ///
  /// #### Parameters
  /// - `codec` - Binary codec for decoding (optional, uses default)
  const AbiDeserializer({BinaryCodec? codec}) : _codec = codec;

  /// Binary codec for decoding (uses default if not provided).
  final BinaryCodec? _codec;

  /// Default codec instance (used when codec not provided).
  static final BinaryCodec _defaultCodec = BinaryCodec.withDefaults();

  /// Gets the codec to use (provided or default).
  BinaryCodec get codec => _codec ?? _defaultCodec;

  /// Deserializes value from base64 data.
  ///
  /// Decodes the base64 string and uses the BinaryCodec to decode the bytes
  /// into a TypedValue, then extracts the native Dart value.
  ///
  /// #### Parameters
  /// - `data` - Base64-encoded bytes
  /// - `type` - Expected ABI type
  ///
  /// #### Returns
  /// Native Dart value (int, BigInt, String, List, Map, etc.)
  ///
  /// #### Throws
  /// - `DeserializationException` - Decoding failure
  dynamic deserializeValue(String data, AbiType type) {
    try {
      final Uint8List bytes = base64.decode(data);
      final TypedValue typedValue = codec.decodeTopLevel(bytes, type);
      return _toDeserializerValue(typedValue);
    } catch (e) {
      if (e is DeserializationException) rethrow;
      throw DeserializationException(
        'Failed to deserialize value of type ${type.name}',
        typeName: type.name,
        cause: e,
      );
    }
  }

  /// Deserializes by type names.
  ///
  /// #### Parameters
  /// - `dataList` - List of base64-encoded values
  /// - `typeStrings` - List of type strings (e.g., 'u32', 'Address')
  ///
  /// #### Throws
  /// - `DeserializationException` - Count mismatch or decoding failure
  List<dynamic> deserializeByTypeNames(
    List<String> dataList,
    List<String> typeStrings,
  ) {
    if (dataList.length != typeStrings.length) {
      throw DeserializationException(
        'Data list length (${dataList.length}) does not match types length (${typeStrings.length})',
      );
    }

    final List<dynamic> results = <dynamic>[];
    for (int i = 0; i < dataList.length; i++) {
      try {
        final AbiType type = AbiTypeFactory().fromString(typeStrings[i]);
        results.add(deserializeValue(dataList[i], type));
      } catch (e) {
        throw DeserializationException(
          'Failed to deserialize value at index $i with type ${typeStrings[i]}',
          typeName: typeStrings[i],
          cause: e,
        );
      }
    }
    return results;
  }

  /// Converts TypedValue to deserializer's native format.
  ///
  /// This method transforms TypedValue instances into the specific format
  /// expected by the deserializer API (which differs from TypedValue.nativeValue).
  dynamic _toDeserializerValue(TypedValue typedValue) {
    if (typedValue is AddressValue) {
      return Address(typedValue.toBytes()).bech32;
    }

    if (typedValue is StructValue) {
      final Map<String, dynamic> result = <String, dynamic>{};
      for (final String name in typedValue.fieldNames) {
        result[name] = _toDeserializerValue(typedValue.getFieldValue(name));
      }
      return result;
    }

    if (typedValue is EnumValue) {
      final Map<String, dynamic> fieldsMap = <String, dynamic>{};
      for (int i = 0; i < typedValue.fields.length; i++) {
        fieldsMap['field$i'] = _toDeserializerValue(typedValue.fields[i]);
      }
      return <String, dynamic>{
        'variant': typedValue.variantName,
        'discriminant': typedValue.discriminant,
        'fields': fieldsMap,
      };
    }

    if (typedValue is ExplicitEnumValue) {
      return <String, dynamic>{
        'variant': typedValue.variant.name,
        'discriminant': typedValue.variant.discriminant,
      };
    }

    if (typedValue is TupleValue) {
      final List<dynamic> result = <dynamic>[];
      for (int i = 0; i < typedValue.arity; i++) {
        result.add(_toDeserializerValue(typedValue[i]));
      }
      return result;
    }

    if (typedValue is ListValue) {
      return typedValue.elements
          .map((TypedValue item) => _toDeserializerValue(item))
          .toList();
    }

    if (typedValue is ArrayValue) {
      return typedValue.elements
          .map((TypedValue item) => _toDeserializerValue(item))
          .toList();
    }

    if (typedValue is OptionValue) {
      if (typedValue.isNone) return null;
      return _toDeserializerValue(typedValue.value!);
    }

    if (typedValue is OptionalValue) {
      if (typedValue.isMissing) return null;
      return _toDeserializerValue(typedValue.value!);
    }

    if (typedValue is VariadicValue) {
      return typedValue.items
          .map((TypedValue item) => _toDeserializerValue(item))
          .toList();
    }

    if (typedValue is CompositeValue) {
      return typedValue.fields
          .map((TypedValue item) => _toDeserializerValue(item))
          .toList();
    }

    if (typedValue is CodeMetadataValue) {
      return <String, dynamic>{
        'upgradeable': typedValue.isUpgradeable,
        'readable': typedValue.isReadable,
        'payable': typedValue.isPayable,
        'payableBySc': typedValue.isPayableBySC,
      };
    }

    if (typedValue is ManagedDecimalValue) {
      return <String, dynamic>{
        'mantissa': typedValue.value,
        'scale': typedValue.scale,
      };
    }

    if (typedValue is H256Value) {
      return typedValue.value;
    }

    if (typedValue is NothingValue) {
      return null;
    }

    if (typedValue is NumericalValue) {
      return _toNativeNumeric(typedValue);
    }

    return typedValue.nativeValue;
  }

  /// Converts numerical TypedValue to native Dart numeric type.
  ///
  /// Returns int for U8, U16, U32, I8, I16, I32, and U64/I64 when value fits.
  /// Returns BigInt for larger values and all BigInt/BigUInt types.
  dynamic _toNativeNumeric(NumericalValue typedValue) {
    final AbiType type = typedValue.type;
    final dynamic nativeValue = typedValue.nativeValue;

    if (type is U8Type ||
        type is U16Type ||
        type is U32Type ||
        type is I8Type ||
        type is I16Type ||
        type is I32Type) {
      return (nativeValue is BigInt) ? nativeValue.toInt() : nativeValue;
    }

    if (type is U64Type || type is I64Type) {
      if (nativeValue is BigInt) {
        final BigInt maxInt64 = (BigInt.one << 63) - BigInt.one;
        final BigInt minInt64 = -(BigInt.one << 63);
        if (nativeValue >= minInt64 && nativeValue <= maxInt64) {
          return nativeValue.toInt();
        }
      }
    }

    return nativeValue;
  }
}

/// Extension methods for easier deserialization.
///
/// Convenience methods for common types with simplified interfaces.
extension AbiDeserializerExtensions on AbiDeserializer {
  /// Deserializes BigInt from base64.
  ///
  /// #### Parameters
  /// - `data` - Base64-encoded bytes
  BigInt deserializeBigInt(String data) {
    final BigUIntType type = BigUIntType.type;
    return requireAs<BigInt>(deserializeValue(data, type), 'BigUInt');
  }

  /// Deserializes int from base64.
  ///
  /// #### Parameters
  /// - `data` - Base64-encoded bytes
  /// - `bits` - Bit size (8, 16, 32, or 64)
  ///
  /// #### Throws
  /// - `ArgumentError` - Invalid bit size
  int deserializeInt(String data, {required int bits}) {
    final AbiType type;
    switch (bits) {
      case 8:
        type = U8Type.type;
        break;
      case 16:
        type = U16Type.type;
        break;
      case 32:
        type = U32Type.type;
        break;
      case 64:
        type = U64Type.type;
        break;
      default:
        throw ArgumentError(
          'Unsupported bit size: $bits. Use 8, 16, 32, or 64.',
        );
    }
    return requireAs<int>(deserializeValue(data, type), 'int$bits');
  }

  /// Deserializes address from base64.
  ///
  /// #### Parameters
  /// - `data` - Base64-encoded 32 bytes
  String deserializeAddress(String data) {
    return requireAs<String>(
      deserializeValue(data, AddressType.type),
      'Address',
    );
  }

  /// Deserializes boolean from base64.
  ///
  /// #### Parameters
  /// - `data` - Base64-encoded byte (0x00 or 0x01)
  bool deserializeBoolean(String data) {
    return requireAs<bool>(deserializeValue(data, BooleanType.type), 'Boolean');
  }

  /// Deserializes bytes from base64.
  ///
  /// #### Parameters
  /// - `data` - Base64-encoded bytes
  Uint8List deserializeBytes(String data) {
    return requireAs<Uint8List>(
      deserializeValue(data, BytesType.type),
      'Bytes',
    );
  }

  /// Deserializes Balance from base64.
  ///
  /// #### Parameters
  /// - `data` - Base64-encoded BigInt bytes
  Balance deserializeBalance(String data) {
    final BigInt value = deserializeBigInt(data);
    return Balance(value);
  }
}
