import 'dart:typed_data';

import 'package:abidock_mvx/src/wallet/crypto/derivation_params.dart';
import 'package:test/test.dart';

void main() {
  group('ScryptKeyDerivationParams', () {
    group('default parameters', () {
      test('has correct default values', () {
        const params = ScryptKeyDerivationParams();
        expect(params.n, equals(16384));
        expect(params.r, equals(8));
        expect(params.p, equals(1));
        expect(params.dklen, equals(32));
      });
    });

    group('custom parameters', () {
      test('accepts custom n value', () {
        const params = ScryptKeyDerivationParams(n: 8192);
        expect(params.n, equals(8192));
      });

      test('accepts custom r value', () {
        const params = ScryptKeyDerivationParams(r: 16);
        expect(params.r, equals(16));
      });

      test('accepts custom p value', () {
        const params = ScryptKeyDerivationParams(p: 2);
        expect(params.p, equals(2));
      });

      test('accepts custom dklen value', () {
        const params = ScryptKeyDerivationParams(dklen: 64);
        expect(params.dklen, equals(64));
      });
    });

    group('generateDerivedKey', () {
      test('generates key of correct length', () {
        const params = ScryptKeyDerivationParams();
        final password = Uint8List.fromList('test_password'.codeUnits);
        final salt = Uint8List.fromList(List.filled(32, 1));
        final key = params.generateDerivedKey(password, salt);
        expect(key.length, equals(32));
      });

      test('generates different keys for different passwords', () {
        const params = ScryptKeyDerivationParams();
        final salt = Uint8List.fromList(List.filled(32, 1));
        final password1 = Uint8List.fromList('password1'.codeUnits);
        final password2 = Uint8List.fromList('password2'.codeUnits);
        final key1 = params.generateDerivedKey(password1, salt);
        final key2 = params.generateDerivedKey(password2, salt);
        expect(key1, isNot(equals(key2)));
      });

      test('generates different keys for different salts', () {
        const params = ScryptKeyDerivationParams();
        final password = Uint8List.fromList('password'.codeUnits);
        final salt1 = Uint8List.fromList(List.filled(32, 1));
        final salt2 = Uint8List.fromList(List.filled(32, 2));
        final key1 = params.generateDerivedKey(password, salt1);
        final key2 = params.generateDerivedKey(password, salt2);
        expect(key1, isNot(equals(key2)));
      });

      test('same inputs produce same output', () {
        const params = ScryptKeyDerivationParams();
        final password = Uint8List.fromList('test'.codeUnits);
        final salt = Uint8List.fromList(List.filled(32, 42));
        final key1 = params.generateDerivedKey(password, salt);
        final key2 = params.generateDerivedKey(password, salt);
        expect(key1, equals(key2));
      });

      test('respects custom dklen', () {
        const params = ScryptKeyDerivationParams(dklen: 64);
        final password = Uint8List.fromList('test'.codeUnits);
        final salt = Uint8List.fromList(List.filled(32, 1));
        final key = params.generateDerivedKey(password, salt);
        expect(key.length, equals(64));
      });

      test('handles empty password', () {
        const params = ScryptKeyDerivationParams();
        final password = Uint8List(0);
        final salt = Uint8List.fromList(List.filled(32, 1));
        final key = params.generateDerivedKey(password, salt);
        expect(key.length, equals(32));
      });

      test('handles unicode password', () {
        const params = ScryptKeyDerivationParams();
        final password = Uint8List.fromList('пароль密码🔐'.codeUnits);
        final salt = Uint8List.fromList(List.filled(32, 1));
        final key = params.generateDerivedKey(password, salt);
        expect(key.length, equals(32));
      });
    });
  });
}
