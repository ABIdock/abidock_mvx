import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('String to Hex Conversion', () {
    test('converts ASCII string to hex', () {
      expect(HexUtils.stringToHex('hello'), '68656c6c6f');
    });

    test('converts empty string to empty hex', () {
      expect(HexUtils.stringToHex(''), '');
    });

    test('converts special characters to hex', () {
      expect(HexUtils.stringToHex('Hello!'), '48656c6c6f21');
    });
  });

  group('Bytes to Hex Conversion', () {
    test('converts bytes to hex', () {
      final bytes = [0x48, 0x65, 0x6c, 0x6c, 0x6f];
      expect(HexUtils.bytesToHex(bytes), '48656c6c6f');
    });

    test('converts empty bytes to empty hex', () {
      expect(HexUtils.bytesToHex([]), '');
    });

    test('handles Uint8List', () {
      final bytes = Uint8List.fromList([0x01, 0x02, 0x03]);
      expect(HexUtils.bytesToHex(bytes), '010203');
    });
  });

  group('Hex to Bytes Conversion', () {
    test('converts hex to bytes', () {
      final result = HexUtils.hexToBytes('48656c6c6f');
      expect(result, [0x48, 0x65, 0x6c, 0x6c, 0x6f]);
    });

    test('handles 0x prefix', () {
      final result = HexUtils.hexToBytes('0x48656c6c6f');
      expect(result, [0x48, 0x65, 0x6c, 0x6c, 0x6f]);
    });

    test('is case insensitive', () {
      expect(HexUtils.hexToBytes('ABCD'), HexUtils.hexToBytes('abcd'));
    });
  });

  group('Bytes to Hex Conversion', () {
    test('converts bytes to hex', () {
      final bytes = [0x48, 0x65, 0x6c, 0x6c, 0x6f];
      expect(HexUtils.bytesToHex(bytes), '48656c6c6f');
    });

    test('converts empty bytes to empty hex', () {
      expect(HexUtils.bytesToHex([]), '');
    });

    test('handles Uint8List', () {
      final bytes = Uint8List.fromList([0x01, 0x02, 0x03]);
      expect(HexUtils.bytesToHex(bytes), '010203');
    });
  });

  group('Hex to Bytes Conversion', () {
    test('converts hex to bytes', () {
      final result = HexUtils.hexToBytes('48656c6c6f');
      expect(result, [0x48, 0x65, 0x6c, 0x6c, 0x6f]);
    });

    test('handles 0x prefix', () {
      final result = HexUtils.hexToBytes('0x48656c6c6f');
      expect(result, [0x48, 0x65, 0x6c, 0x6c, 0x6f]);
    });

    test('is case insensitive', () {
      expect(HexUtils.hexToBytes('ABCD'), HexUtils.hexToBytes('abcd'));
    });
  });

  group('Round Trip Conversions', () {
    test('string to hex to string round trip', () {
      const original = 'Hello World!';
      final hex = HexUtils.stringToHex(original);
      final result = HexUtils.hexToString(hex);
      expect(result, original);
    });

    test('bytes to hex to bytes round trip', () {
      final original = [0x01, 0x02, 0x03, 0xFF];
      final hex = HexUtils.bytesToHex(original);
      final result = HexUtils.hexToBytes(hex);
      expect(result, original);
    });
  });

  group('Error Handling', () {
    test('throws on invalid hex characters', () {
      expect(() => HexUtils.hexToBytes('xyz'), throwsException);
    });

    test('throws on odd-length hex string', () {
      expect(() => HexUtils.hexToBytes('abc'), throwsFormatException);
      expect(() => HexUtils.hexToBytes('1'), throwsFormatException);
      expect(() => HexUtils.hexToBytes('123'), throwsFormatException);
    });

    test('throws on invalid characters in middle', () {
      expect(() => HexUtils.hexToBytes('12gh34'), throwsFormatException);
      expect(() => HexUtils.hexToBytes('ab!cd'), throwsFormatException);
      expect(() => HexUtils.hexToBytes('00zz00'), throwsFormatException);
    });
  });

  group('Hex Edge Cases', () {
    test('handles empty input', () {
      expect(HexUtils.hexToBytes(''), isEmpty);
      expect(HexUtils.hexToBytes('0x'), isEmpty);
      expect(HexUtils.hexToBytesLenient(''), isEmpty);
    });

    test('handles leading zeros', () {
      expect(HexUtils.hexToBytes('0000'), [0, 0]);
      expect(HexUtils.hexToBytes('00ff'), [0, 255]);
      expect(HexUtils.hexToBytes('000000000001'), [0, 0, 0, 0, 0, 1]);
    });

    test('handles max byte values', () {
      expect(HexUtils.hexToBytes('ff'), [255]);
      expect(HexUtils.hexToBytes('ffff'), [255, 255]);
      expect(HexUtils.hexToBytes('ffffffff'), [255, 255, 255, 255]);
    });

    test('handles mixed case', () {
      expect(HexUtils.hexToBytes('AaBbCcDd'), [170, 187, 204, 221]);
      expect(HexUtils.hexToBytes('0xAbCdEf'), [171, 205, 239]);
    });

    test('handles whitespace stripping', () {
      expect(HexUtils.hexToBytes('ab cd'), [171, 205]);
      expect(HexUtils.hexToBytes(' abcd '), [171, 205]);
      expect(HexUtils.hexToBytes('0x ab cd'), [171, 205]);
    });

    test('hexToBytesLenient handles odd-length strings', () {
      expect(HexUtils.hexToBytesLenient('f'), [15]);
      expect(HexUtils.hexToBytesLenient('fff'), [15, 255]);
      expect(HexUtils.hexToBytesLenient('1'), [1]);
      expect(HexUtils.hexToBytesLenient('123'), [1, 35]);
      expect(HexUtils.hexToBytesLenient('0xabc'), [10, 188]);
    });

    test('handles boundary values', () {
      expect(HexUtils.hexToBytes('00'), [0]);
      expect(HexUtils.hexToBytes('7f'), [127]);
      expect(HexUtils.hexToBytes('80'), [128]);
      expect(HexUtils.hexToBytes('fe'), [254]);
      expect(HexUtils.hexToBytes('ff'), [255]);
    });
  });

  group('Fuzz-style Tests', () {
    test('round trip for all single byte values', () {
      for (int i = 0; i <= 255; i++) {
        final bytes = [i];
        final hex = HexUtils.bytesToHex(bytes);
        final result = HexUtils.hexToBytes(hex);
        expect(result, bytes);
      }
    });

    test('round trip for multi-byte sequences', () {
      final testCases = [
        [0, 0],
        [255, 255],
        [0, 255],
        [255, 0],
        [1, 2, 3, 4, 5],
        [255, 254, 253, 252, 251],
        List.generate(32, (i) => i),
        List.generate(64, (i) => i % 256),
        List.filled(100, 0),
        List.filled(100, 255),
      ];

      for (final bytes in testCases) {
        final hex = HexUtils.bytesToHex(bytes);
        final result = HexUtils.hexToBytes(hex);
        expect(result, bytes);
      }
    });

    test('hexToBytesLenient produces same result for padded input', () {
      for (int i = 0; i <= 255; i++) {
        final lenientResult = HexUtils.hexToBytesLenient(i.toRadixString(16));
        final paddedHex = i.toRadixString(16).padLeft(2, '0');
        final strictResult = HexUtils.hexToBytes(paddedHex);
        expect(lenientResult, strictResult);
      }
    });

    test('rejects all invalid single characters', () {
      final invalidChars = [
        'g',
        'h',
        'i',
        'j',
        'k',
        'l',
        'm',
        'n',
        'o',
        'p',
        'q',
        'r',
        's',
        't',
        'u',
        'v',
        'w',
        'x',
        'y',
        'z',
        '!',
        '@',
        '#',
        '%',
        '^',
        '&',
        '*',
        '(',
        ')',
        '_',
        '=',
        '[',
        ']',
        '{',
        '}',
        '|',
        ';',
        ':',
        '/',
        '?',
        '`',
        '~',
      ];
      for (final char in invalidChars) {
        expect(() => HexUtils.hexToBytes('${char}0'), throwsFormatException);
      }
    });
  });
}
