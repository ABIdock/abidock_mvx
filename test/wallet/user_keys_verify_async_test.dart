/// Regression tests for asynchronous error handling in signature verification.
///
/// `verify` catches failures and reports them as `false`. Returning the
/// underlying future without awaiting it inside the `try` made that `catch`
/// unreachable for asynchronous errors, so a malformed signature escaped as a
/// thrown exception instead of a `false` result. Callers written as
/// `if (await key.verify(...))` would crash rather than reject the signature.
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('UserPublicKey.verify rejects rather than throws', () {
    late UserPublicKey publicKey;
    late Uint8List message;

    setUp(() async {
      final UserSecretKey secretKey = UserSecretKey(
        Uint8List.fromList(List<int>.generate(32, (int i) => i + 1)),
      );
      publicKey = await secretKey.generatePublicKey();
      message = Uint8List.fromList(<int>[1, 2, 3, 4]);
    });

    test('a signature of the wrong length returns false', () async {
      final Uint8List malformed = Uint8List.fromList(<int>[1, 2, 3]);

      expect(await publicKey.verify(message, malformed), isFalse);
    });

    test('an empty signature returns false', () async {
      expect(await publicKey.verify(message, Uint8List(0)), isFalse);
    });

    test('a correctly sized but wrong signature returns false', () async {
      final Uint8List wrong = Uint8List.fromList(
        List<int>.generate(64, (int i) => 0xAB),
      );

      expect(await publicKey.verify(message, wrong), isFalse);
    });

    test('a genuine signature still verifies', () async {
      final UserSecretKey secretKey = UserSecretKey(
        Uint8List.fromList(List<int>.generate(32, (int i) => i + 1)),
      );
      final Uint8List signature = await secretKey.sign(message);

      expect(await publicKey.verify(message, signature), isTrue);
    });
  });
}
