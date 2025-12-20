/// Event converter utilities for parsed events.
/// Converts ParsedEvent instances to strongly-typed event models.

import '../../../core/transaction/transaction_event_parser.dart';
import '../../../utils/helpers.dart';
import '../../core/type_system.dart';
import '../../types/collections/collections.dart';
import '../../types/composite/composite.dart';
import '../../types/primitives/primitives.dart';
import '../../types/special/special.dart';

/// Event conversion result with success or failure state.
class EventConversionResult<T> {
  /// Creates successful conversion result.
  ///
  /// #### Parameters
  /// - `value` - Converted event value
  const EventConversionResult.success(this.value)
    : error = null,
      failureReason = null;

  /// Creates failed conversion result.
  ///
  /// #### Parameters
  /// - `error` - Error that occurred during conversion
  /// - `failureReason` - Human-readable failure description
  const EventConversionResult.failure(this.error, this.failureReason)
    : value = null;

  /// Converted event value (null on failure).
  final T? value;

  /// Error that occurred during conversion (null on success).
  final Object? error;

  /// Human-readable reason for failure (null on success).
  final String? failureReason;

  /// Whether conversion was successful.
  bool get isSuccess => value != null;

  /// Whether conversion failed.
  bool get isFailure => !isSuccess;
}

/// Event converter utility for typed event model conversion.
///
/// Converts ParsedEvent instances to strongly-typed event models
/// using two conversion strategies: nested StructValue and flattened structure.
final class EventConverter {
  EventConverter._();

  /// Converts ParsedEvent to typed event model.
  ///
  /// Uses two conversion strategies: nested StructValue and flattened structure.
  /// Returns null if conversion fails.
  ///
  /// #### Parameters
  /// - `parsedEvent` - Parsed event from WebSocket or polling
  /// - `fromAbi` - Function to create event from TypedValue
  /// - `eventType` - Event type definition
  ///
  /// #### Returns
  /// `T?` - Typed event instance or null if conversion failed
  static T? convertEvent<T>(
    ParsedEvent parsedEvent,
    T Function(TypedValue) fromAbi,
    AbiType eventType,
  ) {
    try {
      final eventMap = parsedEvent.toMap();

      for (final value in eventMap.values) {
        if (value is StructValue) {
          try {
            final result = fromAbi(value);
            return result;
          } catch (e) {
            continue;
          }
        }
      }

      try {
        final nativeMap = convertTypedValueMapToNative(eventMap);
        final reconstructedValue = eventType.createValue(nativeMap);
        final result = fromAbi(reconstructedValue);
        return result;
      } catch (e) {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Converts ParsedEvent to typed event with detailed error information.
  ///
  /// Returns EventConversionResult containing value on success
  /// or error details on failure.
  ///
  /// #### Parameters
  /// - `parsedEvent` - Parsed event from WebSocket or polling
  /// - `fromAbi` - Function to create event from TypedValue
  /// - `eventType` - Event type definition
  ///
  /// #### Returns
  /// `EventConversionResult<T>` - Result with value or error details
  static EventConversionResult<T> convertEventWithResult<T>(
    ParsedEvent parsedEvent,
    T Function(TypedValue) fromAbi,
    AbiType eventType,
  ) {
    try {
      final eventMap = parsedEvent.toMap();

      for (final value in eventMap.values) {
        if (value is StructValue) {
          try {
            return EventConversionResult.success(fromAbi(value));
          } catch (e) {
            continue;
          }
        }
      }

      try {
        final nativeMap = convertTypedValueMapToNative(eventMap);
        final reconstructedValue = eventType.createValue(nativeMap);
        return EventConversionResult.success(fromAbi(reconstructedValue));
      } catch (e) {
        return EventConversionResult.failure(
          e,
          'Flat conversion failed: ${e.toString()}',
        );
      }
    } catch (e) {
      return EventConversionResult.failure(
        e,
        'Unexpected error: ${e.toString()}',
      );
    }
  }

  /// Converts map of TypedValues to map of native Dart values.
  ///
  /// Handles all TypedValue types including primitives, collections,
  /// composite types, and special values.
  ///
  /// #### Parameters
  /// - `valueMap` - Map of field names to TypedValues
  ///
  /// #### Returns
  /// `Map<String, dynamic>` - Map of field names to native Dart values
  static Map<String, dynamic> convertTypedValueMapToNative(
    Map<String, TypedValue> valueMap,
  ) {
    return valueMap.map(
      (key, value) => MapEntry(key, convertTypedValueToNative(value)),
    );
  }

  /// Converts single TypedValue to native Dart value.
  ///
  /// Handles type-specific conversion for all TypedValue types.
  ///
  /// #### Parameters
  /// - `value` - TypedValue to convert
  ///
  /// #### Returns
  /// `dynamic` - Native Dart value
  static dynamic convertTypedValueToNative(TypedValue value) {
    if (value is U8Value ||
        value is U16Value ||
        value is U32Value ||
        value is I8Value ||
        value is I16Value ||
        value is I32Value) {
      return value.nativeValue;
    }

    if (value is U64Value ||
        value is I64Value ||
        value is BigIntValue ||
        value is BigUIntValue) {
      return value.nativeValue;
    }

    if (value is BooleanValue) {
      return value.nativeValue;
    }

    if (value is StringValue) {
      return value.nativeValue;
    }

    if (value is BytesValue) {
      return value.nativeValue;
    }

    if (value is AddressValue) {
      return value.nativeValue;
    }

    if (value is OptionValue) {
      return value.nativeValue;
    }

    if (value is ListValue) {
      final List elements = value.nativeValue;
      return elements
          .map((e) => convertTypedValueToNative(e as TypedValue))
          .toList();
    }

    if (value is ArrayValue) {
      final List elements = value.nativeValue;
      return elements
          .map((e) => convertTypedValueToNative(e as TypedValue))
          .toList();
    }

    if (value is StructValue) {
      return value.nativeValue;
    }

    if (value is EnumValue) {
      return value.nativeValue;
    }

    if (value is ExplicitEnumValue) {
      return value.nativeValue;
    }

    if (value is TupleValue) {
      final List fields = value.nativeValue;
      return fields
          .map((e) => convertTypedValueToNative(e as TypedValue))
          .toList();
    }

    if (value is TokenIdentifierValue) {
      return value.nativeValue;
    }

    if (value is EgldOrEsdtTokenIdentifierValue) {
      return value.nativeValue;
    }

    if (value is TokenTransferValue) {
      return value.nativeValue;
    }

    if (value is H256Value) {
      return value.nativeValue;
    }

    if (value is ManagedDecimalValue) {
      return value.nativeValue;
    }

    if (value is NothingValue) {
      return null;
    }

    if (value is OptionalValue) {
      return value.nativeValue;
    }

    if (value is VariadicValue) {
      final List values = value.nativeValue;
      return values
          .map(
            (e) => convertTypedValueToNative(
              requireAs<TypedValue>(e, 'VariadicValue.element'),
            ),
          )
          .toList();
    }

    if (value is CompositeValue) {
      final fields = value.nativeValue;
      return convertTypedValueMapToNative(
        requireAs<Map<String, TypedValue>>(fields, 'CompositeValue.fields'),
      );
    }

    if (value is CodeMetadataValue) {
      return value.nativeValue;
    }

    return value.nativeValue;
  }

  /// Filters event stream by identifier and converts to typed events.
  ///
  /// #### Parameters
  /// - `source` - Source stream of event results
  /// - `identifier` - Event identifier to filter by
  /// - `converter` - Function to convert parsed event to typed model
  ///
  /// #### Returns
  /// `Stream<T>` - Filtered and converted stream of typed events
  static Stream<T> filterByIdentifier<T>(
    Stream source,
    String identifier,
    T? Function(ParsedEvent) converter,
  ) {
    return source
        .where(
          (r) =>
              r.parsedEvent != null &&
              r.parsedEvent!.definition.identifier == identifier,
        )
        .map<T?>((r) => converter(r.parsedEvent!))
        .where((event) => event != null)
        .cast<T>();
  }
}
