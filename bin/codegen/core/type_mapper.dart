import 'package:abidock_mvx/src/abi/abi.dart';

class TypeMapper {
  String mapToDartType(AbiType type) {
    if (type is U8Type || type is U16Type || type is U32Type) return 'int';
    if (type is U64Type || type is BigUIntType) return 'BigInt';
    if (type is I8Type || type is I16Type || type is I32Type) return 'int';
    if (type is I64Type || type is BigIntType) return 'BigInt';
    if (type is ManagedDecimalType) return 'BigInt';
    if (type is AddressType) return 'String';
    if (type is BooleanType) return 'bool';
    if (type is BytesType) return 'Uint8List';
    if (type is StringType) return 'String';
    if (type is TokenIdentifierType) return 'String';
    if (type is EgldOrEsdtTokenIdentifierType) return 'String';
    if (type is H256Type) return 'Uint8List';
    if (type is CodeMetadataType) return 'List<int>';
    if (type is NothingType) return 'void';

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
    if (type is EgldOrEsdtTokenIdentifierType) {
      return 'EgldOrEsdtTokenIdentifierType.type';
    }
    if (type is H256Type) return 'H256Type.type';
    if (type is CodeMetadataType) return 'CodeMetadataType.type';
    if (type is NothingType) return 'NothingType.type';

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
      return 'TupleType([$elements])';
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
    if (type is BytesType || type is H256Type) return true;
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

  String _toPascalCase(String name) {
    return name
        .split('_')
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
    if (type is EgldOrEsdtTokenIdentifierType) {
      return 'EgldOrEsdtTokenIdentifier';
    }
    if (type is H256Type) return 'H256';
    if (type is CodeMetadataType) return 'CodeMetadata';
    if (type is NothingType) return 'Nothing';

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
      return 'variadic<${getAbiTypeString(type.itemType)}>';
    }

    if (type is TupleType) {
      final elements = type.elementTypes.map(getAbiTypeString).join(',');
      return 'multi<$elements>';
    }

    if (type is CompositeType) {
      final elements = type.fieldTypes.map(getAbiTypeString).join(',');
      return 'multi<$elements>';
    }

    if (type is StructType || type is EnumType || type is ExplicitEnumType) {
      return type.name;
    }

    return 'unknown';
  }

  String getAbiTypeStringForDocs(AbiType type) {
    return getAbiTypeString(
      type,
    ).replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  }
}
