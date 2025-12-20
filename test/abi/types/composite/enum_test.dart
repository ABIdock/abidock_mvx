import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('EnumType', () {
    test('works with variant definitions', () {
      final statusType = EnumType(
        name: 'Status',
        variants: [
          const EnumVariantDefinition(name: 'Active', discriminant: 0),
          const EnumVariantDefinition(name: 'Inactive', discriminant: 1),
        ],
      );
      expect(statusType.name, 'Status');

      final resultType = EnumType(
        name: 'Result',
        variants: [
          const EnumVariantDefinition(name: 'Success', discriminant: 0),
          EnumVariantDefinition(
            name: 'Error',
            discriminant: 1,
            fields: [U32Type.type],
          ),
        ],
      );
      expect(resultType.variants.length, 2);
      expect(resultType.variants[0].name, 'Success');
      expect(resultType.variants[1].name, 'Error');
    });
  });

  group('EnumValue', () {
    test('creates different variant types', () {
      final statusType = EnumType(
        name: 'Status',
        variants: [
          const EnumVariantDefinition(name: 'Active', discriminant: 0),
          const EnumVariantDefinition(name: 'Inactive', discriminant: 1),
        ],
      );
      final simpleValue = statusType.createValue('Active');
      expect(simpleValue.nativeValue, isA<String>());
      expect(simpleValue.nativeValue, 'Active');

      final resultType = EnumType(
        name: 'Result',
        variants: [
          const EnumVariantDefinition(name: 'Success', discriminant: 0),
          EnumVariantDefinition(
            name: 'Error',
            discriminant: 1,
            fields: [U32Type.type],
          ),
        ],
      );
      final complexValue = resultType.createValue({
        'variant': 'Error',
        'fields': [404],
      });
      expect(complexValue.nativeValue, isA<Map>());
    });

    test('encodes to bytes', () {
      final enumType = EnumType(
        name: 'Status',
        variants: [
          const EnumVariantDefinition(name: 'Active', discriminant: 0),
          const EnumVariantDefinition(name: 'Inactive', discriminant: 1),
        ],
      );
      final value = enumType.createValue({'variant': 'Active'});
      final bytes = value.toBytes();
      expect(bytes, isA<List<int>>());
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
