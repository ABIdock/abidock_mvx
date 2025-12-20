import 'dart:typed_data';

import 'package:abidock_mvx/src/wallet/crypto/crypto_utils.dart';
import 'package:test/test.dart';

void main() {
  group('CryptoUtils', () {
    group('computeHmacSha256', () {
      test('produces 32-byte output', () {
        final key = Uint8List.fromList(List.filled(32, 1));
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final mac = CryptoUtils.computeHmacSha256(key, data);
        expect(mac.length, equals(32));
      });

      test('same input produces same output', () {
        final key = Uint8List.fromList(List.filled(32, 42));
        final data = Uint8List.fromList([10, 20, 30]);
        final mac1 = CryptoUtils.computeHmacSha256(key, data);
        final mac2 = CryptoUtils.computeHmacSha256(key, data);
        expect(mac1, equals(mac2));
      });

      test('different keys produce different output', () {
        final key1 = Uint8List.fromList(List.filled(32, 1));
        final key2 = Uint8List.fromList(List.filled(32, 2));
        final data = Uint8List.fromList([1, 2, 3]);
        final mac1 = CryptoUtils.computeHmacSha256(key1, data);
        final mac2 = CryptoUtils.computeHmacSha256(key2, data);
        expect(mac1, isNot(equals(mac2)));
      });

      test('different data produces different output', () {
        final key = Uint8List.fromList(List.filled(32, 1));
        final data1 = Uint8List.fromList([1, 2, 3]);
        final data2 = Uint8List.fromList([1, 2, 4]);
        final mac1 = CryptoUtils.computeHmacSha256(key, data1);
        final mac2 = CryptoUtils.computeHmacSha256(key, data2);
        expect(mac1, isNot(equals(mac2)));
      });

      test('handles empty data', () {
        final key = Uint8List.fromList(List.filled(32, 1));
        final data = Uint8List(0);
        final mac = CryptoUtils.computeHmacSha256(key, data);
        expect(mac.length, equals(32));
      });

      test('handles large data', () {
        final key = Uint8List.fromList(List.filled(32, 1));
        final data = Uint8List.fromList(List.filled(10000, 42));
        final mac = CryptoUtils.computeHmacSha256(key, data);
        expect(mac.length, equals(32));
      });
    });

    group('constantTimeCompare', () {
      test('returns true for equal arrays', () {
        final a = Uint8List.fromList([1, 2, 3, 4, 5]);
        final b = Uint8List.fromList([1, 2, 3, 4, 5]);
        expect(CryptoUtils.constantTimeCompare(a, b), isTrue);
      });

      test('returns false for different arrays', () {
        final a = Uint8List.fromList([1, 2, 3, 4, 5]);
        final b = Uint8List.fromList([1, 2, 3, 4, 6]);
        expect(CryptoUtils.constantTimeCompare(a, b), isFalse);
      });

      test('returns false for different lengths', () {
        final a = Uint8List.fromList([1, 2, 3, 4, 5]);
        final b = Uint8List.fromList([1, 2, 3, 4]);
        expect(CryptoUtils.constantTimeCompare(a, b), isFalse);
      });

      test('returns true for empty arrays', () {
        final a = Uint8List(0);
        final b = Uint8List(0);
        expect(CryptoUtils.constantTimeCompare(a, b), isTrue);
      });

      test('returns false when one is empty', () {
        final a = Uint8List.fromList([1]);
        final b = Uint8List(0);
        expect(CryptoUtils.constantTimeCompare(a, b), isFalse);
        expect(CryptoUtils.constantTimeCompare(b, a), isFalse);
      });

      test('returns false for single bit difference', () {
        final a = Uint8List.fromList([0x00]);
        final b = Uint8List.fromList([0x01]);
        expect(CryptoUtils.constantTimeCompare(a, b), isFalse);
      });

      test('handles max byte values', () {
        final a = Uint8List.fromList([255, 255, 255]);
        final b = Uint8List.fromList([255, 255, 255]);
        expect(CryptoUtils.constantTimeCompare(a, b), isTrue);
      });

      test('returns true for large equal arrays', () {
        final a = Uint8List.fromList(List.filled(1000, 42));
        final b = Uint8List.fromList(List.filled(1000, 42));
        expect(CryptoUtils.constantTimeCompare(a, b), isTrue);
      });

      test('returns false for large arrays with single difference', () {
        final a = Uint8List.fromList(List.filled(1000, 42));
        final b = Uint8List.fromList(List.filled(1000, 42));
        b[999] = 43;
        expect(CryptoUtils.constantTimeCompare(a, b), isFalse);
      });
    });
  });
}
