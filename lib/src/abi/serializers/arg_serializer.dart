/// Argument serializer for smart contract ABI encoding and decoding.
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../utils/hex_utils.dart';
import '../../utils/sdk_exceptions.dart';
import '../codecs/binary_codec.dart' as binarycodec;
import '../core/types.dart';
import 'native_serializer.dart';

/// Parameter definition for endpoint functions.
///
/// Defines parameter with type and optional name for smart contract endpoint arguments.
@immutable
class ParameterDefinition {
  /// Creates parameter definition.
  ///
  /// #### Parameters
  /// - `type` - Parameter ABI type
  /// - `name` - Parameter name (optional)
  const ParameterDefinition(this.type, [this.name]);

  /// Parameter type.
  final AbiType type;

  /// Parameter name.
  final String? name;
}

/// Options for argument serializer.
@immutable
class ArgSerializerOptions {
  /// Creates serializer options.
  ///
  /// #### Parameters
  /// - `binaryCodec` - Codec for encoding/decoding
  const ArgSerializerOptions({required this.binaryCodec});

  /// Creates with default codec.
  factory ArgSerializerOptions.withDefaults() {
    return ArgSerializerOptions(
      binaryCodec: binarycodec.BinaryCodec.withDefaults(),
    );
  }

  /// Binary codec for encoding/decoding.
  final binarycodec.ICodec binaryCodec;
}

/// Result of values to string conversion.
@immutable
class ValuesToStringResult {
  /// Creates result.
  ///
  /// #### Parameters
  /// - `argumentsString` - Joined hex arguments (@ separator)
  /// - `count` - Number of arguments
  const ValuesToStringResult({
    required this.argumentsString,
    required this.count,
  });

  /// Joined argument string.
  final String argumentsString;

  /// Number of arguments.
  final int count;
}

/// Argument serializer for ABI encoding/decoding.
class ArgSerializer {
  /// Creates argument serializer.
  ///
  /// #### Parameters
  /// - `options` - Serializer options (optional, uses defaults)
  ArgSerializer([ArgSerializerOptions? options])
    : codec = options?.binaryCodec ?? _defaultCodec;

  /// Cached default codec instance.
  static final binarycodec.ICodec _defaultCodec =
      binarycodec.BinaryCodec.withDefaults();

  /// Binary codec for encoding/decoding.
  final binarycodec.ICodec codec;

  /// Separator between hex-encoded arguments.
  static const String argumentsSeparator = '@';

  /// Converts hex string to typed values.
  ///
  /// #### Parameters
  /// - `joinedString` - Hex string with @ separators (e.g., '2a@68656c6c6f')
  /// - `parameters` - Parameter type definitions
  ///
  /// #### Throws
  /// - `AbiArgumentSerializationException` - Decoding failure
  List<TypedValue> stringToValues(
    String joinedString,
    List<ParameterDefinition> parameters,
  ) {
    try {
      final List<Uint8List> buffers = stringToBuffers(joinedString);
      return buffersToValues(buffers, parameters);
    } catch (e) {
      throw AbiArgumentSerializationException(
        'Failed to convert string to values',
        cause: e,
      );
    }
  }

  /// Splits hex string into argument buffers.
  ///
  /// #### Parameters
  /// - `joinedString` - Hex string with @ separators
  List<Uint8List> stringToBuffers(String joinedString) {
    if (joinedString.isEmpty) return <Uint8List>[];

    return joinedString
        .split(argumentsSeparator)
        .map((String hexString) => HexUtils.hexToBytesLenient(hexString.trim()))
        .toList();
  }

  /// Converts buffers to typed values with variadic/composite support.
  ///
  /// #### Parameters
  /// - `buffers` - Byte buffers to decode
  /// - `parameters` - Parameter type definitions
  ///
  /// #### Throws
  /// - `AbiArgumentSerializationException` - Decoding failure or leftover buffers
  List<TypedValue> buffersToValues(
    List<Uint8List> buffers,
    List<ParameterDefinition> parameters,
  ) {
    final List<TypedValue> values = <TypedValue>[];
    int bufferIndex = 0;

    for (int paramIndex = 0; paramIndex < parameters.length; paramIndex++) {
      final ParameterDefinition param = parameters[paramIndex];

      try {
        final (TypedValue value, int consumed) = _readValue(
          param.type,
          buffers,
          bufferIndex,
        );
        values.add(value);
        bufferIndex = consumed;
      } catch (e) {
        throw AbiArgumentSerializationException(
          'Failed to decode parameter $paramIndex (${param.name ?? 'unnamed'})',
          cause: e,
        );
      }
    }

    if (bufferIndex < buffers.length) {
      throw AbiArgumentSerializationException(
        'Leftover buffers after parsing all parameters: '
        '${buffers.length - bufferIndex} buffer(s) remaining',
      );
    }

    return values;
  }

  /// Reads value from buffers, returns (value, newIndex).
  (TypedValue, int) _readValue(
    AbiType type,
    List<Uint8List> buffers,
    int bufferIndex,
  ) {
    if (type is OptionalType) {
      if (bufferIndex >= buffers.length) {
        return (OptionalValue.missing(type), bufferIndex);
      }

      final (TypedValue innerValue, int consumed) = _readValue(
        type.innerType,
        buffers,
        bufferIndex,
      );

      return (OptionalValue.provided(type, innerValue), consumed);
    } else if (type is VariadicType) {
      if (type.isCounted) {
        if (bufferIndex >= buffers.length) {
          throw ArgumentError(
            'Missing count buffer for counted variadic at index $bufferIndex',
          );
        }

        final Uint8List countBuffer = buffers[bufferIndex];
        int currentIndex = bufferIndex + 1;

        final U32Value countValue =
            codec.decodeTopLevel(countBuffer, U32Type.type) as U32Value;
        final int count = countValue.nativeValue;

        final List<TypedValue> items = <TypedValue>[];
        for (int i = 0; i < count; i++) {
          final (TypedValue item, int consumed) = _readValue(
            type.itemType,
            buffers,
            currentIndex,
          );
          items.add(item);
          currentIndex = consumed;
        }

        return (
          VariadicValue(items, itemType: type.itemType, isCounted: true),
          currentIndex,
        );
      } else {
        final List<TypedValue> items = <TypedValue>[];
        int currentIndex = bufferIndex;

        while (currentIndex < buffers.length) {
          final (TypedValue item, int consumed) = _readValue(
            type.itemType,
            buffers,
            currentIndex,
          );
          items.add(item);
          currentIndex = consumed;
        }

        return (VariadicValue(items, itemType: type.itemType), currentIndex);
      }
    } else if (type is MultiValueType) {
      final List<TypedValue> inner = <TypedValue>[];
      int currentIndex = bufferIndex;

      for (int i = 0; i < type.arity; i++) {
        if (currentIndex >= buffers.length) {
          throw AbiArgumentSerializationException(
            'Not enough buffers for MultiValue slot $i (arity ${type.arity})',
          );
        }
        final TypedValue value = codec.decodeTopLevel(
          buffers[currentIndex],
          type.types[i],
        );
        inner.add(value);
        currentIndex += 1;
      }

      return (MultiValueValue(type, inner), currentIndex);
    } else if (type is CompositeType) {
      final List<TypedValue> fields = <TypedValue>[];
      int currentIndex = bufferIndex;

      for (final AbiType fieldType in type.fieldTypes) {
        if (currentIndex >= buffers.length) {
          throw const AbiArgumentSerializationException(
            'Not enough buffers for composite field',
          );
        }

        final (TypedValue fieldValue, int consumed) = _readValue(
          fieldType,
          buffers,
          currentIndex,
        );
        fields.add(fieldValue);
        currentIndex = consumed;
      }

      return (CompositeValue(type, fields), currentIndex);
    } else {
      if (bufferIndex >= buffers.length) {
        throw const AbiArgumentSerializationException(
          'Not enough buffers for parameter',
        );
      }

      final TypedValue value = codec.decodeTopLevel(buffers[bufferIndex], type);
      return (value, bufferIndex + 1);
    }
  }

  /// Converts typed values to hex string.
  ///
  /// #### Parameters
  /// - `values` - TypedValue instances to encode
  ///
  /// #### Throws
  /// - `AbiArgumentSerializationException` - Encoding failure
  ValuesToStringResult valuesToString(List<TypedValue> values) {
    try {
      final List<String> strings = valuesToStrings(values);
      final String argumentsString = strings.join(argumentsSeparator);
      return ValuesToStringResult(
        argumentsString: argumentsString,
        count: strings.length,
      );
    } catch (e) {
      throw AbiArgumentSerializationException(
        'Failed to convert values to string',
        cause: e,
      );
    }
  }

  /// Converts typed values to hex strings.
  ///
  /// #### Parameters
  /// - `values` - TypedValue instances to encode
  List<String> valuesToStrings(List<TypedValue> values) {
    final List<Uint8List> buffers = valuesToBuffers(values);
    return buffers
        .map((Uint8List buffer) => HexUtils.bytesToHex(buffer))
        .toList();
  }

  /// Converts typed values to buffers with variadic/composite support.
  ///
  /// #### Parameters
  /// - `values` - TypedValue instances to encode
  List<Uint8List> valuesToBuffers(List<TypedValue> values) {
    final List<Uint8List> buffers = <Uint8List>[];

    for (final TypedValue value in values) {
      _handleValue(value, buffers);
    }

    return buffers;
  }

  void _handleValue(TypedValue value, List<Uint8List> buffers) {
    if (value is OptionalValue) {
      if (value.isProvided) {
        _handleValue(value.value!, buffers);
      }
    } else if (value is VariadicValue) {
      if (value.isCounted) {
        final U32Value countValue = U32Value(value.length);
        buffers.add(codec.encodeTopLevel(countValue));
      }
      for (final TypedValue item in value.items) {
        _handleValue(item, buffers);
      }
    } else if (value is MultiValueValue) {
      for (final TypedValue inner in value.values) {
        _handleValue(inner, buffers);
      }
    } else if (value is CompositeValue) {
      for (final TypedValue field in value.fields) {
        _handleValue(field, buffers);
      }
    } else {
      buffers.add(codec.encodeTopLevel(value));
    }
  }

  /// Creates typed values from native values using type formulas.
  ///
  /// #### Parameters
  /// - `nativeValues` - Native Dart values (int, String, List, etc.)
  /// - `typeFormulas` - Type strings (e.g., 'u32', 'List<Address>')
  ///
  /// #### Throws
  /// - `AbiArgumentSerializationException` - Count mismatch or type conversion failure
  List<TypedValue> createTypedValues(
    List<dynamic> nativeValues,
    List<String> typeFormulas,
  ) {
    try {
      return NativeSerializer.createTypedValues(nativeValues, typeFormulas);
    } on AbiNativeSerializationException catch (e) {
      throw AbiArgumentSerializationException(e.message, cause: e.cause);
    }
  }

  /// Validates native values against type formulas.
  ///
  /// #### Parameters
  /// - `nativeValues` - Native Dart values to validate
  /// - `typeFormulas` - Type strings to check against
  bool validateArguments(
    List<dynamic> nativeValues,
    List<String> typeFormulas,
  ) {
    return NativeSerializer.validateValues(nativeValues, typeFormulas);
  }
}
