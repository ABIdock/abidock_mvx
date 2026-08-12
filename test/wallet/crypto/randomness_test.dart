import 'package:abidock_mvx/src/wallet/crypto/randomness.dart';
import 'package:test/test.dart';

void main() {
  group('Randomness', () {
    test('id is a UUIDv4 string', () {
      final RegExp uuidV4 = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      for (int i = 0; i < 64; i++) {
        final Randomness r = Randomness();
        expect(
          uuidV4.hasMatch(r.id),
          isTrue,
          reason: 'id "${r.id}" does not match UUIDv4 format',
        );
      }
    });

    test('salt is 32 bytes and iv is 16 bytes', () {
      final Randomness r = Randomness();
      expect(r.salt.length, equals(32));
      expect(r.iv.length, equals(16));
    });

    test('honors caller-provided id', () {
      const String fixedId = '12345678-1234-4234-8234-123456789012';
      final Randomness r = Randomness(id: fixedId);
      expect(r.id, equals(fixedId));
    });
  });
}
