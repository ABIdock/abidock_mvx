import '../../core/type_system.dart';
import 'variadic.dart';

/// Builder for VariadicValue with type-safe value addition.
class VariadicBuilder<T extends AbiType> {
  /// Creates a variadic builder for the given item type.
  ///
  /// #### Parameters
  /// - `itemType` - Type of items in the variadic
  /// - `isCounted` - Whether to create counted variadic (default: false)
  ///
  /// #### Example
  /// ```dart
  /// final builder = VariadicBuilder(U32Type.type);
  /// final countedBuilder = VariadicBuilder(U64Type.type, isCounted: true);
  /// ```
  VariadicBuilder(this.itemType, {this.isCounted = false}) : _values = [];

  /// The type of items in this variadic.
  final T itemType;

  /// Whether this is a counted variadic.
  final bool isCounted;

  /// Internal storage for values.
  final List<TypedValue> _values;

  /// Adds a value to the variadic.
  ///
  /// #### Parameters
  /// - `value` - Native value to add (will be converted to TypedValue)
  ///
  /// #### Returns `VariadicBuilder<T>` - This builder for method chaining
  ///
  /// #### Example
  /// ```dart
  /// builder
  ///   .add(10)
  ///   .add(20)
  ///   .add(30);
  /// ```
  VariadicBuilder<T> add(dynamic value) {
    _values.add(itemType.createValue(value));
    return this;
  }

  /// Adds a TypedValue directly to the variadic.
  ///
  /// #### Parameters
  /// - `value` - TypedValue to add (must match itemType)
  ///
  /// #### Returns `VariadicBuilder<T>` - This builder for method chaining
  ///
  /// #### Throws
  /// - `ArgumentError` if value type doesn't match itemType
  ///
  /// #### Example
  /// ```dart
  /// builder
  ///   .addTyped(U32Value(10))
  ///   .addTyped(U32Value(20));
  /// ```
  VariadicBuilder<T> addTyped(TypedValue value) {
    if (!itemType.equals(value.type)) {
      throw ArgumentError(
        'Value type ${value.type.fullyQualifiedName} does not match '
        'itemType ${itemType.fullyQualifiedName}',
      );
    }
    _values.add(value);
    return this;
  }

  /// Adds multiple values at once.
  ///
  /// #### Parameters
  /// - `values` - List of native values to add
  ///
  /// #### Returns `VariadicBuilder<T>` - This builder for method chaining
  ///
  /// #### Example
  /// ```dart
  /// builder.addAll([10, 20, 30, 40, 50]);
  /// ```
  VariadicBuilder<T> addAll(List<dynamic> values) {
    for (final value in values) {
      add(value);
    }
    return this;
  }

  /// Adds multiple TypedValues at once.
  ///
  /// #### Parameters
  /// - `values` - List of TypedValues to add
  ///
  /// #### Returns `VariadicBuilder<T>` - This builder for method chaining
  ///
  /// #### Example
  /// ```dart
  /// builder.addAllTyped([
  ///   U32Value(10),
  ///   U32Value(20),
  ///   U32Value(30),
  /// ]);
  /// ```
  VariadicBuilder<T> addAllTyped(List<TypedValue> values) {
    for (final value in values) {
      addTyped(value);
    }
    return this;
  }

  /// Builds the VariadicValue.
  ///
  /// #### Returns `VariadicValue` with all added values
  ///
  /// #### Example
  /// ```dart
  /// final variadic = builder.build();
  /// print(variadic.length);  // Number of values added
  /// ```
  VariadicValue build() {
    return VariadicValue(
      List.unmodifiable(_values),
      itemType: itemType,
      isCounted: isCounted,
    );
  }

  /// Builds a counted VariadicValue (overrides constructor setting).
  ///
  /// #### Returns `VariadicValue` with isCounted=true
  ///
  /// #### Example
  /// ```dart
  /// final counted = builder.buildCounted();
  /// print(counted.isCounted);  // true
  /// ```
  VariadicValue buildCounted() {
    return VariadicValue.counted(
      List.unmodifiable(_values),
      itemType: itemType,
    );
  }

  /// Returns the current number of values.
  int get count => _values.length;

  /// Returns whether any values have been added.
  bool get isEmpty => _values.isEmpty;

  /// Returns whether values have been added.
  bool get isNotEmpty => _values.isNotEmpty;

  /// Clears all values from the builder.
  ///
  /// #### Returns `VariadicBuilder<T>` - This builder for method chaining
  void clear() {
    _values.clear();
  }

  @override
  String toString() =>
      'VariadicBuilder<${itemType.fullyQualifiedName}>($_count values)';

  int get _count => _values.length;
}

/// Extension methods for common variadic patterns.
extension VariadicBuilderExtensions<T extends AbiType> on VariadicBuilder<T> {
  /// Adds a value and returns the value for inspection.
  ///
  /// #### Parameters
  /// - `value` - Native value to add
  ///
  /// #### Returns `TypedValue` - The created TypedValue
  ///
  /// #### Example
  /// ```dart
  /// final addedValue = builder.push(42);
  /// print(addedValue.nativeValue);  // 42
  /// ```
  TypedValue push(dynamic value) {
    final typedValue = itemType.createValue(value);
    _values.add(typedValue);
    return typedValue;
  }

  /// Conditionally adds a value.
  ///
  /// #### Parameters
  /// - `condition` - Whether to add the value
  /// - `value` - Value to add if condition is true
  ///
  /// #### Returns `VariadicBuilder<T>` - This builder for method chaining
  ///
  /// #### Example
  /// ```dart
  /// builder
  ///   .addIf(true, 10)   // Added
  ///   .addIf(false, 20)  // Skipped
  ///   .addIf(true, 30);  // Added
  /// ```
  VariadicBuilder<T> addIf(bool condition, dynamic value) {
    if (condition) {
      add(value);
    }
    return this;
  }

  /// Adds values from an iterable with a transform function.
  ///
  /// #### Parameters
  /// - `iterable` - Source iterable
  /// - `transform` - Function to convert each item to a value
  ///
  /// #### Returns `VariadicBuilder<T>` - This builder for method chaining
  ///
  /// #### Example
  /// ```dart
  /// builder.addMapped([1, 2, 3], (x) => x * 10);
  /// // Adds 10, 20, 30
  /// ```
  VariadicBuilder<T> addMapped<S>(
    Iterable<S> iterable,
    dynamic Function(S) transform,
  ) {
    for (final item in iterable) {
      add(transform(item));
    }
    return this;
  }

  /// Adds n copies of the same value.
  ///
  /// #### Parameters
  /// - `value` - Value to repeat
  /// - `count` - Number of times to add
  ///
  /// #### Returns `VariadicBuilder<T>` - This builder for method chaining
  ///
  /// #### Example
  /// ```dart
  /// builder.repeat(42, 5);  // Adds 42 five times
  /// ```
  VariadicBuilder<T> repeat(dynamic value, int count) {
    for (int i = 0; i < count; i++) {
      add(value);
    }
    return this;
  }
}
