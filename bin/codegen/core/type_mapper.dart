import 'package:abidock_mvx/src/abi/abi.dart';

/// Maps ABI types to Dart types for generated code.
class TypeMapper {
  /// Maps an [AbiType] to a Dart type string.
  String mapToDartType(AbiType type) {
    if (type is U8Type || type is U16Type || type is U32Type) return 'int';
    if (type is U64Type || type is BigUIntType) return 'BigInt';
    if (type is I8Type || type is I16Type || type is I32Type) return 'int';
    if (type is I64Type || type is BigIntType) return 'BigInt';
    if (type is BigFloatType) return 'double';
    if (type is ManagedDecimalType) return 'BigInt';
    if (type is AddressType) return 'Address';
    if (type is BooleanType) return 'bool';
    if (type is BytesType) return 'Uint8List';
    if (type is StringType) return 'String';
    if (type is TokenIdentifierType) return 'TokenIdentifier';
    if (type is EsdtTokenIdentifierType) return 'TokenIdentifier';
    if (type is EgldOrEsdtTokenIdentifierType) {
      return 'EgldOrEsdtTokenIdentifier';
    }
    if (type is H256Type) return 'Uint8List';
    if (type is ManagedByteArrayType) return 'Uint8List';
    if (type is CodeMetadataType) return 'List<int>';
    if (type is NothingType) return 'void';
    if (type is TokenTransferType) return 'TokenTransferValue';

    if (type is OptionType) {
      final inner = mapToDartType(type.innerType);
      return inner.endsWith('?') ? inner : '$inner?';
    }

    if (type is OptionalType) {
      final inner = mapToDartType(type.innerType);
      return inner.endsWith('?') ? inner : '$inner?';
    }

    if (type is ListType) {
      return 'List<${mapToDartType(type.elementType)}>';
    }

    if (type is ArrayType) {
      return 'List<${mapToDartType(type.elementType)}>';
    }

    if (type is VariadicType) {
      return 'List<${mapToDartType(type.itemType)}>';
    }

    if (type is TupleType) {
      final elements = type.elementTypes.map(mapToDartType).join(', ');
      return '($elements)';
    }

    if (type is CompositeType) {
      final types = type.fieldTypes.map((t) => mapToDartType(t)).join(', ');
      return '($types)';
    }

    if (type is MultiValueType) {
      final types = type.types.map(mapToDartType).join(', ');
      return '($types)';
    }

    if (type is StructType || type is EnumType || type is ExplicitEnumType) {
      return type.name;
    }

    throw UnimplementedError(
      'Unsupported ABI type: ${type.runtimeType} - ${type.fullyQualifiedName}',
    );
  }

  String mapToTypeExpression(AbiType type) {
    if (type is U8Type) return 'U8Type.type';
    if (type is U16Type) return 'U16Type.type';
    if (type is U32Type) return 'U32Type.type';
    if (type is U64Type) return 'U64Type.type';
    if (type is BigUIntType) return 'BigUIntType.type';
    if (type is I8Type) return 'I8Type.type';
    if (type is I16Type) return 'I16Type.type';
    if (type is I32Type) return 'I32Type.type';
    if (type is I64Type) return 'I64Type.type';
    if (type is BigIntType) return 'BigIntType.type';
    if (type is BigFloatType) return 'BigFloatType.type';
    if (type is ManagedDecimalType) {
      if (type.isVariable) {
        return 'ManagedDecimalType.variable(${type.scale}${type.isSigned ? ', isSigned: true' : ''})';
      } else if (type.isSigned) {
        return 'ManagedDecimalType.signed(${type.scale})';
      } else {
        return 'ManagedDecimalType.of(${type.scale})';
      }
    }
    if (type is AddressType) return 'AddressType.type';
    if (type is BooleanType) return 'BooleanType.type';
    if (type is BytesType) return 'BytesType.type';
    if (type is StringType) return 'StringType.type';
    if (type is TokenIdentifierType) return 'TokenIdentifierType.type';
    if (type is EsdtTokenIdentifierType) return 'EsdtTokenIdentifierType.type';
    if (type is EgldOrEsdtTokenIdentifierType) {
      return 'EgldOrEsdtTokenIdentifierType.type';
    }
    if (type is H256Type) return 'H256Type.type';
    if (type is ManagedByteArrayType) {
      return 'ManagedByteArrayType(${type.length})';
    }
    if (type is CodeMetadataType) return 'CodeMetadataType.type';
    if (type is NothingType) return 'NothingType.type';
    if (type is TokenTransferType) return 'TokenTransferType.type';

    if (type is OptionType) {
      return 'OptionType(${mapToTypeExpression(type.innerType)})';
    }

    if (type is OptionalType) {
      return 'OptionalType.of(${mapToTypeExpression(type.innerType)})';
    }

    if (type is ListType) {
      return 'ListType(${mapToTypeExpression(type.elementType)})';
    }

    if (type is ArrayType) {
      return 'ArrayType(${mapToTypeExpression(type.elementType)}, ${type.length})';
    }

    if (type is VariadicType) {
      final itemTypeExpr = mapToTypeExpression(type.itemType);
      if (type.isCounted) {
        return 'VariadicType.counted($itemTypeExpr)';
      }
      return 'VariadicType.of($itemTypeExpr)';
    }

    if (type is TupleType) {
      final elements = type.elementTypes.map(mapToTypeExpression).join(', ');
      return 'TupleType([$elements])';
    }

    if (type is CompositeType) {
      final elements = type.fieldTypes.map(mapToTypeExpression).join(', ');
      return 'CompositeType.of([$elements])';
    }

    if (type is MultiValueType) {
      final elements = type.types.map(mapToTypeExpression).join(', ');
      return 'MultiValueType(${type.types.length}, [$elements])';
    }

    if (type is StructType) {
      return '${_toPascalCase(type.name)}.type';
    }

    if (type is EnumType) {
      return '${_toPascalCase(type.name)}.type';
    }

    if (type is ExplicitEnumType) {
      return '${_toPascalCase(type.name)}.type';
    }

    throw UnimplementedError(
      'Unsupported ABI type for type expression: ${type.runtimeType} - ${type.fullyQualifiedName}',
    );
  }

  /// Returns a Dart expression that decodes the [TypedValue] referenced by
  /// [valueExpr] into [type]'s Dart representation.
  ///
  /// Every wrapper layer (Option, Optional, List, Array, Variadic, Tuple,
  /// Composite) is peeled via its TypedValue API. `infer<T>` / `as` casts on
  /// `nativeValue` are used **only** for primitive leaves whose Dart type
  /// matches the `nativeValue` runtime type 1:1. Anything past a single
  /// nesting level must descend recursively, otherwise it crashes with
  /// `'List<dynamic>' is not a subtype of 'List<BigInt>'` at runtime.
  ///
  /// Used by `queries_generator`, `models_generator`, and
  /// `event_models_generator` to keep all decode paths consistent.
  String decodeTypedValue(AbiType type, String valueExpr) {
    if (type is StructType || type is EnumType || type is ExplicitEnumType) {
      final dartType = mapToDartType(type);
      return '$dartType.fromAbi($valueExpr)';
    }
    if (type is ManagedDecimalType) {
      return '($valueExpr as ManagedDecimalValue).value';
    }
    if (type is OptionType || type is OptionalType) {
      final inner = type is OptionType
          ? type.innerType
          : (type as OptionalType).innerType;
      final wrapper = type is OptionType ? 'OptionValue' : 'OptionalValue';
      final innerDecode = decodeTypedValue(inner, 'v.value!');
      return '(() { final v = $valueExpr as $wrapper; '
          'return v.value == null ? null : $innerDecode; })()';
    }
    if (type is ListType || type is ArrayType) {
      final element = type is ListType
          ? type.elementType
          : (type as ArrayType).elementType;
      final elemDart = mapToDartType(element);
      final elemDecode = decodeTypedValue(element, 'e');
      return '($valueExpr as ListValue).elements'
          '.map<$elemDart>((e) => $elemDecode).toList()';
    }
    if (type is VariadicType) {
      final elemDart = mapToDartType(type.itemType);
      final elemDecode = decodeTypedValue(type.itemType, 'e');
      return '($valueExpr as VariadicValue).items'
          '.map<$elemDart>((e) => $elemDecode).toList()';
    }
    if (type is TupleType) {
      final parts = <String>[];
      for (int i = 0; i < type.elementTypes.length; i++) {
        parts.add(decodeTypedValue(type.elementTypes[i], 't[$i]'));
      }
      return '(() { final t = $valueExpr as TupleValue; '
          'return (${parts.join(', ')}); })()';
    }
    if (type is CompositeType) {
      final parts = <String>[];
      for (int i = 0; i < type.fieldTypes.length; i++) {
        parts.add(decodeTypedValue(type.fieldTypes[i], 'c.fields[$i]'));
      }
      return '(() { final c = $valueExpr as CompositeValue; '
          'return (${parts.join(', ')}); })()';
    }
    if (type is MultiValueType) {
      final parts = <String>[];
      for (int i = 0; i < type.types.length; i++) {
        parts.add(decodeTypedValue(type.types[i], 'm.values[$i]'));
      }
      return '(() { final m = $valueExpr as MultiValueValue; '
          'return (${parts.join(', ')}); })()';
    }
    if (type is AddressType) {
      return 'Address.fromBech32($valueExpr.nativeValue as String)';
    }
    if (type is EgldOrEsdtTokenIdentifierType) {
      return 'EgldOrEsdtTokenIdentifier($valueExpr.nativeValue as String)';
    }
    if (type is TokenIdentifierType || type is EsdtTokenIdentifierType) {
      return 'TokenIdentifier($valueExpr.nativeValue as String)';
    }
    if (type is H256Type || type is BytesType || type is ManagedByteArrayType) {
      return '$valueExpr.nativeValue as Uint8List';
    }
    final dartType = mapToDartType(type);
    return '$valueExpr.nativeValue as $dartType';
  }

  /// Wraps a Dart variable so it is type-correct for the native serializer.
  ///
  /// The native serializer is strict about a few container shapes the
  /// generated Dart type can't express directly:
  /// - **Counted variadic** needs `VariadicValue.counted(...)` because the
  ///   plain `List` path always emits `isCounted: false`.
  /// - **Tuple / Composite** inputs are mapped to Dart record syntax
  ///   `(A, B, …)` for ergonomics, but `_toTupleValue` /
  ///   `_toCompositeValue` both throw `Expected List`. We convert each
  ///   record to a list literal before passing it through.
  /// - Both transformations recurse into `List`, `Array`, and `Variadic`
  ///   so `List<(u32, Address)>`, `variadic<multi<u32, Address>>`, etc.
  ///   still encode correctly.
  ///
  /// Returns [variable] unchanged when no wrapping is required.
  String wrapArgumentExpression(AbiType type, String variable) {
    if (type is VariadicType && type.isCounted) {
      final itemExpr = mapToTypeExpression(type.itemType);
      final inner = wrapArgumentExpression(type.itemType, 'e');
      final innerCreate = inner == 'e'
          ? '$itemExpr.createValue(e)'
          : '$itemExpr.createValue($inner)';
      return 'VariadicValue.counted('
          '$variable.map((e) => $innerCreate).toList(), '
          'itemType: $itemExpr)';
    }
    if (type is AddressType) return '$variable.bech32';
    if (type is TokenIdentifierType ||
        type is EsdtTokenIdentifierType ||
        type is EgldOrEsdtTokenIdentifierType) {
      return '$variable.value';
    }
    if (type is TupleType) {
      return _recordToList(variable, type.elementTypes.length);
    }
    if (type is CompositeType) {
      return _recordToList(variable, type.fieldTypes.length);
    }
    if (type is MultiValueType) {
      return _recordToList(variable, type.types.length);
    }
    if (type is VariadicType) {
      final inner = wrapArgumentExpression(type.itemType, 'e');
      if (inner == 'e') return variable;
      return '$variable.map((e) => $inner).toList()';
    }
    if (type is ListType) {
      final inner = wrapArgumentExpression(type.elementType, 'e');
      if (inner == 'e') return variable;
      return '$variable.map((e) => $inner).toList()';
    }
    if (type is ArrayType) {
      final inner = wrapArgumentExpression(type.elementType, 'e');
      if (inner == 'e') return variable;
      return '$variable.map((e) => $inner).toList()';
    }
    return variable;
  }

  String _recordToList(String variable, int fieldCount) {
    final parts = <String>[];
    for (int i = 1; i <= fieldCount; i++) {
      parts.add('$variable.\$$i');
    }
    return '<dynamic>[${parts.join(', ')}]';
  }

  Set<String> getRequiredImports(AbiType type) {
    final imports = <String>{};

    if (needsTypedData(type)) {
      imports.add('dart:typed_data');
    }

    if (_needsAsync(type)) {
      imports.add('dart:async');
    }

    return imports;
  }

  bool needsTypedData(AbiType type) {
    if (type is BytesType || type is H256Type || type is ManagedByteArrayType) {
      return true;
    }
    if (type is MultiValueType) {
      return type.types.any(needsTypedData);
    }
    if (type is OptionType) return needsTypedData(type.innerType);
    if (type is OptionalType) return needsTypedData(type.innerType);
    if (type is ListType) return needsTypedData(type.elementType);
    if (type is ArrayType) return needsTypedData(type.elementType);
    if (type is VariadicType) return needsTypedData(type.itemType);
    if (type is TupleType) return type.elementTypes.any(needsTypedData);
    if (type is CompositeType) return type.fieldTypes.any(needsTypedData);
    return false;
  }

  bool _needsAsync(AbiType type) {
    return false;
  }

  /// Converts `snake_case` / mixed input to `PascalCase` safely (skips
  /// empty fragments produced by leading / consecutive / trailing
  /// underscores). Kept inlined to avoid coupling TypeMapper to
  /// NameSanitizer — the function is purely textual.
  String _toPascalCase(String name) {
    return name
        .split('_')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join();
  }

  String getAbiTypeString(AbiType type) {
    if (type is U8Type) return 'u8';
    if (type is U16Type) return 'u16';
    if (type is U32Type) return 'u32';
    if (type is U64Type) return 'u64';
    if (type is BigUIntType) return 'BigUint';
    if (type is I8Type) return 'i8';
    if (type is I16Type) return 'i16';
    if (type is I32Type) return 'i32';
    if (type is I64Type) return 'i64';
    if (type is BigIntType) return 'BigInt';
    if (type is BigFloatType) return 'BigFloat';
    if (type is ManagedDecimalType) {
      if (type.isVariable) {
        return type.isSigned
            ? 'ManagedDecimalSigned<usize>'
            : 'ManagedDecimal<usize>';
      }
      return type.isSigned
          ? 'ManagedDecimalSigned<${type.scale}>'
          : 'ManagedDecimal<${type.scale}>';
    }
    if (type is AddressType) return 'Address';
    if (type is BooleanType) return 'bool';
    if (type is BytesType) return 'bytes';
    if (type is StringType) return 'String';
    if (type is TokenIdentifierType) return 'TokenIdentifier';
    if (type is EsdtTokenIdentifierType) return 'EsdtTokenIdentifier';
    if (type is EgldOrEsdtTokenIdentifierType) {
      return 'EgldOrEsdtTokenIdentifier';
    }
    if (type is H256Type) return 'H256';
    if (type is ManagedByteArrayType) return 'ManagedByteArray<${type.length}>';
    if (type is CodeMetadataType) return 'CodeMetadata';
    if (type is NothingType) return 'Nothing';
    if (type is TokenTransferType) return 'TokenTransfer';

    if (type is OptionType) {
      return 'Option<${getAbiTypeString(type.innerType)}>';
    }

    if (type is OptionalType) {
      return 'optional<${getAbiTypeString(type.innerType)}>';
    }

    if (type is ListType) {
      return 'List<${getAbiTypeString(type.elementType)}>';
    }

    if (type is ArrayType) {
      return 'array${type.length}<${getAbiTypeString(type.elementType)}>';
    }

    if (type is VariadicType) {
      final prefix = type.isCounted ? 'counted-variadic' : 'variadic';
      return '$prefix<${getAbiTypeString(type.itemType)}>';
    }

    if (type is TupleType) {
      final elements = type.elementTypes.map(getAbiTypeString).join(',');
      return 'tuple<$elements>';
    }

    if (type is CompositeType) {
      final elements = type.fieldTypes.map(getAbiTypeString).join(',');
      return 'multi<$elements>';
    }
    if (type is MultiValueType) {
      final elements = type.types.map(getAbiTypeString).join(',');
      return 'multi<$elements>';
    }

    if (type is StructType || type is EnumType || type is ExplicitEnumType) {
      return type.name;
    }

    return 'unknown';
  }

  String getAbiTypeStringForDocs(AbiType type) {
    return getAbiTypeString(type)
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
