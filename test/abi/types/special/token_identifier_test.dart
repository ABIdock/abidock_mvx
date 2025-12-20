import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('TokenIdentifierType', () {
    test('type_properties', () {
      final type = TokenIdentifierType.type;
      expect(type.name, 'TokenIdentifier');
    });

    test('createValue_from_string', () {
      final type = TokenIdentifierType.type;
      final value = type.createValue('MYTOKEN-a1b2c3');
      expect(value, isA<TokenIdentifierValue>());
    });
  });

  group('TokenIdentifierValue', () {
    test('identifier_parsing', () {
      final value = TokenIdentifierValue('MYTOKEN-a1b2c3');
      expect(value.identifier, 'MYTOKEN-a1b2c3');
      expect(value.ticker, 'MYTOKEN');
      expect(value.randomPart, 'a1b2c3');
    });

    test('validation_error', () {
      expect(() => TokenIdentifierValue('invalid'), throwsArgumentError);
    });
  });

  group('EgldOrEsdtTokenIdentifierType', () {
    test('type_properties', () {
      final type = EgldOrEsdtTokenIdentifierType.type;
      expect(type.name, 'EgldOrEsdtTokenIdentifier');
    });
  });

  group('EgldOrEsdtTokenIdentifierValue', () {
    test('egld_identification', () {
      final value = EgldOrEsdtTokenIdentifierValue('EGLD');
      expect(value.isEgld, isTrue);
      expect(value.isEsdt, isFalse);
      expect(value.ticker, 'EGLD');
    });

    test('esdt_identification', () {
      final value = EgldOrEsdtTokenIdentifierValue('MYTOKEN-a1b2c3');
      expect(value.isEgld, isFalse);
      expect(value.isEsdt, isTrue);
      expect(value.ticker, 'MYTOKEN');
    });
  });
}
