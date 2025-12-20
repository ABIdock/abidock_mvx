import 'package:abidock_mvx/abidock_mvx.dart';

/// State enum.
enum State {
  inactive,
  active,
  partialActive;

  static final type = EnumType(
    name: 'State',
    variants: [
      const EnumVariantDefinition(name: 'Inactive', discriminant: 0),
      const EnumVariantDefinition(name: 'Active', discriminant: 1),
      const EnumVariantDefinition(name: 'PartialActive', discriminant: 2),
    ],
  );

  factory State.fromAbi(TypedValue value) {
    final nativeValue = value.nativeValue;

    // Handle int discriminant
    if (nativeValue is int) {
      return State.values[nativeValue];
    }

    // Handle String variant name (from event parsing)
    if (nativeValue is String) {
      return State.values.firstWhere(
        (v) => v.name.toLowerCase() == nativeValue.toLowerCase(),
        orElse: () =>
            throw ArgumentError('Unknown State variant: $nativeValue'),
      );
    }

    throw ArgumentError('Invalid State value: $nativeValue');
  }

  TypedValue toAbi() {
    return type.createValue(index);
  }
}
