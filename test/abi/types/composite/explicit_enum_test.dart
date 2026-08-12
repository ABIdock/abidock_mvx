import 'dart:typed_data';

import 'package:abidock_mvx/src/abi/types/composite/explicit_enum.dart';
import 'package:test/test.dart';

void main() {
  group('ExplicitEnumVariantDefinition', () {
    test('creates with name and discriminant', () {
      const variant = ExplicitEnumVariantDefinition(
        name: 'Success',
        discriminant: 200,
      );
      expect(variant.name, equals('Success'));
      expect(variant.discriminant, equals(200));
    });

    test('handles negative discriminants', () {
      const variant = ExplicitEnumVariantDefinition(
        name: 'Error',
        discriminant: -1,
      );
      expect(variant.discriminant, equals(-1));
    });

    test('handles large discriminants', () {
      const variant = ExplicitEnumVariantDefinition(
        name: 'Large',
        discriminant: 999999999,
      );
      expect(variant.discriminant, equals(999999999));
    });

    group('equality', () {
      test('equal variants are equal', () {
        const v1 = ExplicitEnumVariantDefinition(name: 'A', discriminant: 1);
        const v2 = ExplicitEnumVariantDefinition(name: 'A', discriminant: 1);
        expect(v1, equals(v2));
      });

      test('different names are not equal', () {
        const v1 = ExplicitEnumVariantDefinition(name: 'A', discriminant: 1);
        const v2 = ExplicitEnumVariantDefinition(name: 'B', discriminant: 1);
        expect(v1, isNot(equals(v2)));
      });

      test('different discriminants are not equal', () {
        const v1 = ExplicitEnumVariantDefinition(name: 'A', discriminant: 1);
        const v2 = ExplicitEnumVariantDefinition(name: 'A', discriminant: 2);
        expect(v1, isNot(equals(v2)));
      });

      test('hashCode is consistent', () {
        const v1 = ExplicitEnumVariantDefinition(name: 'X', discriminant: 100);
        const v2 = ExplicitEnumVariantDefinition(name: 'X', discriminant: 100);
        expect(v1.hashCode, equals(v2.hashCode));
      });
    });

    test('toString format', () {
      const variant = ExplicitEnumVariantDefinition(
        name: 'Test',
        discriminant: 42,
      );
      expect(variant.toString(), equals('Test = 42'));
    });
  });

  group('ExplicitEnumType', () {
    late ExplicitEnumType httpStatus;

    setUp(() {
      httpStatus = ExplicitEnumType(
        name: 'HttpStatus',
        variants: [
          const ExplicitEnumVariantDefinition(name: 'Ok', discriminant: 200),
          const ExplicitEnumVariantDefinition(
            name: 'Created',
            discriminant: 201,
          ),
          const ExplicitEnumVariantDefinition(
            name: 'BadRequest',
            discriminant: 400,
          ),
          const ExplicitEnumVariantDefinition(
            name: 'NotFound',
            discriminant: 404,
          ),
          const ExplicitEnumVariantDefinition(
            name: 'ServerError',
            discriminant: 500,
          ),
        ],
      );
    });

    group('constructor', () {
      test('creates with variants', () {
        expect(httpStatus.name, equals('HttpStatus'));
        expect(httpStatus.variants.length, equals(5));
      });

      test('throws on empty variants', () {
        expect(
          () => ExplicitEnumType(name: 'Empty', variants: []),
          throwsArgumentError,
        );
      });

      test('throws on duplicate names', () {
        expect(
          () => ExplicitEnumType(
            name: 'Dup',
            variants: [
              const ExplicitEnumVariantDefinition(name: 'A', discriminant: 1),
              const ExplicitEnumVariantDefinition(name: 'A', discriminant: 2),
            ],
          ),
          throwsArgumentError,
        );
      });

      test('throws on duplicate discriminants', () {
        expect(
          () => ExplicitEnumType(
            name: 'Dup',
            variants: [
              const ExplicitEnumVariantDefinition(name: 'A', discriminant: 1),
              const ExplicitEnumVariantDefinition(name: 'B', discriminant: 1),
            ],
          ),
          throwsArgumentError,
        );
      });
    });

    group('createValue by name', () {
      test('creates value from variant name', () {
        final value = httpStatus.createValue('Ok') as ExplicitEnumValue;
        expect(value.variantName, equals('Ok'));
        expect(value.discriminant, equals(200));
      });

      test('creates different variants', () {
        final ok = httpStatus.createValue('Ok') as ExplicitEnumValue;
        final notFound =
            httpStatus.createValue('NotFound') as ExplicitEnumValue;
        expect(ok.discriminant, equals(200));
        expect(notFound.discriminant, equals(404));
      });

      test('throws on unknown variant name', () {
        expect(() => httpStatus.createValue('Unknown'), throwsArgumentError);
      });
    });

    group('createValue by discriminant', () {
      test('creates value from discriminant', () {
        final value = httpStatus.createValue(404) as ExplicitEnumValue;
        expect(value.variantName, equals('NotFound'));
        expect(value.discriminant, equals(404));
      });

      test('throws on unknown discriminant', () {
        expect(() => httpStatus.createValue(999), throwsArgumentError);
      });
    });

    group('getVariant', () {
      test('returns correct variant', () {
        final variant = httpStatus.getVariant('ServerError');
        expect(variant.discriminant, equals(500));
      });

      test('throws on unknown name', () {
        expect(() => httpStatus.getVariant('Unknown'), throwsArgumentError);
      });
    });

    group('getVariantByDiscriminant', () {
      test('returns correct variant', () {
        final variant = httpStatus.getVariantByDiscriminant(201);
        expect(variant.name, equals('Created'));
      });

      test('throws on unknown discriminant', () {
        expect(
          () => httpStatus.getVariantByDiscriminant(999),
          throwsArgumentError,
        );
      });
    });

    group('tryGetVariant', () {
      test('returns variant for existing name', () {
        final variant = httpStatus.tryGetVariant('Ok');
        expect(variant, isNotNull);
        expect(variant!.discriminant, equals(200));
      });

      test('returns null for unknown name', () {
        expect(httpStatus.tryGetVariant('Unknown'), isNull);
      });
    });

    group('variantCount', () {
      test('returns correct count', () {
        expect(httpStatus.variantCount, equals(5));
      });
    });
  });

  group('ExplicitEnumValue', () {
    late ExplicitEnumType errorCodes;

    setUp(() {
      errorCodes = ExplicitEnumType(
        name: 'ErrorCode',
        variants: [
          const ExplicitEnumVariantDefinition(name: 'None', discriminant: 0),
          const ExplicitEnumVariantDefinition(
            name: 'InvalidInput',
            discriminant: 100,
          ),
          const ExplicitEnumVariantDefinition(
            name: 'NotAuthorized',
            discriminant: 401,
          ),
        ],
      );
    });

    test('nativeValue is variant name', () {
      final value = errorCodes.createValue('InvalidInput') as ExplicitEnumValue;
      expect(value.nativeValue, equals('InvalidInput'));
    });

    test('toBytes encodes the variant name as UTF-8', () {
      final value = errorCodes.createValue('None') as ExplicitEnumValue;
      final bytes = value.toBytes();
      expect(bytes, isA<Uint8List>());
      expect(bytes, equals(<int>[78, 111, 110, 101]));
    });

    test('toBytes never emits the synthesised discriminant', () {
      final value = errorCodes.createValue('InvalidInput') as ExplicitEnumValue;
      expect(value.discriminant, equals(100));
      expect(value.toBytes(), isNot(equals(<int>[100])));
      expect(
        value.toBytes(),
        equals(<int>[73, 110, 118, 97, 108, 105, 100, 73, 110, 112, 117, 116]),
      );
    });

    group('equality', () {
      test('same variant values are equal', () {
        final v1 = errorCodes.createValue('None') as ExplicitEnumValue;
        final v2 = errorCodes.createValue('None') as ExplicitEnumValue;
        expect(v1.discriminant, equals(v2.discriminant));
        expect(v1.variantName, equals(v2.variantName));
      });

      test('different variants are not equal', () {
        final v1 = errorCodes.createValue('None') as ExplicitEnumValue;
        final v2 = errorCodes.createValue('InvalidInput') as ExplicitEnumValue;
        expect(v1.discriminant, isNot(equals(v2.discriminant)));
      });
    });
  });
}
