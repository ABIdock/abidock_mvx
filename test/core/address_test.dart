import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// A well-formed mainnet address used as the positive control.
const String validBech32 =
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th';

/// Same payload as [validBech32] with the final checksum character mutated.
const String badChecksumBech32 =
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6tz';

/// Same payload as [validBech32] with a character outside the Bech32 charset.
const String badCharsetBech32 =
    'erd1byu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th';

/// Matches an [AddressException] whose message contains [fragment].
Matcher throwsAddressExceptionContaining(String fragment) => throwsA(
  isA<AddressException>().having(
    (AddressException e) => e.message,
    'message',
    contains(fragment),
  ),
);

void main() {
  group('Address.fromBech32 rejects untrusted input with AddressException', () {
    test('bad checksum', () {
      expect(
        () => Address.fromBech32(badChecksumBech32),
        throwsAddressExceptionContaining(badChecksumBech32),
      );
      expect(
        () => Address.fromBech32(badChecksumBech32),
        throwsAddressExceptionContaining('Invalid checksum'),
      );
    });

    test('character outside the Bech32 charset', () {
      expect(
        () => Address.fromBech32(badCharsetBech32),
        throwsAddressExceptionContaining(badCharsetBech32),
      );
      expect(
        () => Address.fromBech32(badCharsetBech32),
        throwsAddressExceptionContaining('Invalid character'),
      );
    });

    test('missing separator', () {
      expect(
        () => Address.fromBech32('notbech32'),
        throwsAddressExceptionContaining('notbech32'),
      );
    });

    test('empty string', () {
      expect(() => Address.fromBech32(''), throwsA(isA<AddressException>()));
    });

    test('data part shorter than the checksum', () {
      expect(
        () => Address.fromBech32('erd1qq'),
        throwsAddressExceptionContaining('erd1qq'),
      );
    });

    test('correct checksum but a payload that is not 32 bytes', () {
      expect(
        () => Address.fromBech32('erd1qurswpc8qurswpc8qurswpc8qurswpc8trcrcj'),
        throwsAddressExceptionContaining('20'),
      );
    });

    test('every rejection is catchable as AbidockException', () {
      for (final String input in <String>[
        badChecksumBech32,
        badCharsetBech32,
        'notbech32',
        '',
      ]) {
        expect(
          () => Address.fromBech32(input),
          throwsA(isA<AbidockException>()),
          reason: 'input: "$input"',
        );
      }
    });

    test('never leaks ArgumentError to the caller', () {
      for (final String input in <String>[
        badChecksumBech32,
        badCharsetBech32,
        'notbech32',
        '',
      ]) {
        expect(
          () => Address.fromBech32(input),
          throwsA(isNot(isA<ArgumentError>())),
          reason: 'input: "$input"',
        );
      }
    });

    test('preserves the underlying failure as cause', () {
      try {
        Address.fromBech32(badChecksumBech32);
        fail('expected AddressException');
      } on AddressException catch (e) {
        expect(e.cause, isNotNull);
      }
    });

    test('a well-formed address still round-trips', () {
      expect(Address.fromBech32(validBech32).bech32, validBech32);
    });
  });

  group('Address.fromHex rejects untrusted input with AddressException', () {
    test('odd-length hex', () {
      expect(
        () => Address.fromHex('abc'),
        throwsAddressExceptionContaining('abc'),
      );
    });

    test('non-hexadecimal characters', () {
      expect(
        () => Address.fromHex('zz' * 32),
        throwsAddressExceptionContaining('zz'),
      );
    });

    test('0x-prefixed hex', () {
      expect(
        () => Address.fromHex('0x${'00' * 32}'),
        throwsAddressExceptionContaining('0x'),
      );
    });

    test('valid hex of the wrong length', () {
      expect(
        () => Address.fromHex('abcd'),
        throwsAddressExceptionContaining('abcd'),
      );
      expect(
        () => Address.fromHex('abcd'),
        throwsAddressExceptionContaining('32 bytes'),
      );
    });

    test('never leaks FormatException to the caller', () {
      for (final String input in <String>['abc', 'zz', '0x00', 'abcd']) {
        expect(
          () => Address.fromHex(input),
          throwsA(isNot(isA<FormatException>())),
          reason: 'input: "$input"',
        );
        expect(
          () => Address.fromHex(input),
          throwsA(isA<AbidockException>()),
          reason: 'input: "$input"',
        );
      }
    });

    test('a 64-character hex string still decodes', () {
      expect(Address.fromHex('00' * 32).hex, '00' * 32);
    });
  });

  group('Address length invariant survives release builds', () {
    test('short byte buffer throws AddressException, not AssertionError', () {
      expect(
        () => Address(List<int>.filled(4, 0)),
        throwsAddressExceptionContaining('32'),
      );
      expect(
        () => Address(List<int>.filled(4, 0)),
        throwsA(isNot(isA<AssertionError>())),
      );
    });

    test('long byte buffer throws AddressException', () {
      expect(
        () => Address(List<int>.filled(33, 0)),
        throwsAddressExceptionContaining('33'),
      );
    });

    test('empty byte buffer throws AddressException', () {
      expect(() => Address(const <int>[]), throwsA(isA<AddressException>()));
    });

    test('exactly 32 bytes is accepted', () {
      expect(Address(List<int>.filled(32, 0)).hex, '00' * 32);
    });
  });

  group('Address.isValid', () {
    test('returns false for malformed input instead of throwing', () {
      expect(Address.isValid(badChecksumBech32), isFalse);
      expect(Address.isValid(badCharsetBech32), isFalse);
      expect(Address.isValid('notbech32'), isFalse);
      expect(Address.isValid(''), isFalse);
    });

    test('returns true for a well-formed address', () {
      expect(Address.isValid(validBech32), isTrue);
    });
  });
}
