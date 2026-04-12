import 'dart:typed_data';

import 'package:abidock_mvx/src/wallet/crypto/derivation_params.dart';
import 'package:test/test.dart';

void main() {
  group('ScryptKeyDerivationParams', () {
    group('default parameters', () {
      test('has correct default values', () {
        final params = ScryptKeyDerivationParams();
        expect(params.n, equals(16384));
        expect(params.r, equals(8));
        expect(params.p, equals(1));
        expect(params.dklen, equals(32));
      });
    });

    group('custom parameters', () {
      test('accepts custom n value (power of 2, >= 16384)', () {
        final params = ScryptKeyDerivationParams(n: 32768);
        expect(params.n, equals(32768));
      });

      test('accepts custom r value', () {
        final params = ScryptKeyDerivationParams(r: 16);
        expect(params.r, equals(16));
      });

      test('accepts custom p value', () {
        final params = ScryptKeyDerivationParams(p: 2);
        expect(params.p, equals(2));
      });
    });

    group('validation', () {
      test('rejects n below 16384', () {
        expect(
          () => ScryptKeyDerivationParams(n: 8192),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects n that is not a power of 2', () {
        expect(
          () => ScryptKeyDerivationParams(n: 20000),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects r below 8', () {
        expect(
          () => ScryptKeyDerivationParams(r: 4),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects p below 1', () {
        expect(
          () => ScryptKeyDerivationParams(p: 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects dklen different from 32', () {
        expect(
          () => ScryptKeyDerivationParams(dklen: 64),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('generateDerivedKey', () {
      test('generates key of correct length', () {
        final params = ScryptKeyDerivationParams();
        final password = Uint8List.fromList('test_password'.codeUnits);
        final salt = Uint8List.fromList(List.filled(32, 1));
        final key = params.generateDerivedKey(password, salt);
        expect(key.length, equals(32));
      });

      test('generates different keys for different passwords', () {
        final params = ScryptKeyDerivationParams();
        final salt = Uint8List.fromList(List.filled(32, 1));
        final password1 = Uint8List.fromList('password1'.codeUnits);
        final password2 = Uint8List.fromList('password2'.codeUnits);
        final key1 = params.generateDerivedKey(password1, salt);
        final key2 = params.generateDerivedKey(password2, salt);
        expect(key1, isNot(equals(key2)));
      });

      test('generates different keys for different salts', () {
        final params = ScryptKeyDerivationParams();
        final password = Uint8List.fromList('password'.codeUnits);
        final salt1 = Uint8List.fromList(List.filled(32, 1));
        final salt2 = Uint8List.fromList(List.filled(32, 2));
        final key1 = params.generateDerivedKey(password, salt1);
        final key2 = params.generateDerivedKey(password, salt2);
        expect(key1, isNot(equals(key2)));
      });

      test('same inputs produce same output', () {
        final params = ScryptKeyDerivationParams();
        final password = Uint8List.fromList('test'.codeUnits);
        final salt = Uint8List.fromList(List.filled(32, 42));
        final key1 = params.generateDerivedKey(password, salt);
        final key2 = params.generateDerivedKey(password, salt);
        expect(key1, equals(key2));
      });

      test('handles empty password', () {
        final params = ScryptKeyDerivationParams();
        final password = Uint8List(0);
        final salt = Uint8List.fromList(List.filled(32, 1));
        final key = params.generateDerivedKey(password, salt);
        expect(key.length, equals(32));
      });

      test('handles unicode password', () {
        final params = ScryptKeyDerivationParams();
        final password = Uint8List.fromList('пароль密码🔐'.codeUnits);
        final salt = Uint8List.fromList(List.filled(32, 1));
        final key = params.generateDerivedKey(password, salt);
        expect(key.length, equals(32));
      });
    });
  });
}
