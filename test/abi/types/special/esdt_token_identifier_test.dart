/// Tests for [EsdtTokenIdentifierType] / [EsdtTokenIdentifierValue].
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('EsdtTokenIdentifierType', () {
    test('singleton instance + canonical name', () {
      expect(EsdtTokenIdentifierType.type, same(EsdtTokenIdentifierType.type));
      expect(EsdtTokenIdentifierType.type.name, equals('EsdtTokenIdentifier'));
    });
  });

  group('EsdtTokenIdentifierValue', () {
    test('accepts a valid TICKER-hexrandom identifier', () {
      final EsdtTokenIdentifierValue v = EsdtTokenIdentifierValue(
        'WEGLD-bd4d79',
      );
      expect(v.identifier, equals('WEGLD-bd4d79'));
    });

    test('rejects a malformed identifier (no random suffix)', () {
      expect(
        () => EsdtTokenIdentifierValue('WEGLD'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty identifier', () {
      expect(() => EsdtTokenIdentifierValue(''), throwsA(isA<ArgumentError>()));
    });

    test('fromBytes decodes UTF-8 then validates', () {
      final EsdtTokenIdentifierValue v = EsdtTokenIdentifierValue.fromBytes(
        utf8.encode('USDC-c76f1f'),
      );
      expect(v.identifier, equals('USDC-c76f1f'));
    });

    test('fromBytes rejects malformed payload', () {
      expect(
        () =>
            EsdtTokenIdentifierValue.fromBytes(Uint8List.fromList(<int>[0x21])),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('value equality on identifier string', () {
      expect(
        EsdtTokenIdentifierValue('WEGLD-bd4d79'),
        equals(EsdtTokenIdentifierValue('WEGLD-bd4d79')),
      );
    });
  });
}
