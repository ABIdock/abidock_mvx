import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('ValidatorSigner', () {
    test('canSign is true for ValidatorSigner.custom(...)', () {
      final ValidatorSigner signer = ValidatorSigner.custom(
        (Uint8List _) => Uint8List(96),
      );
      expect(signer.canSign, isTrue);
    });

    test('custom signer delegates to the provided function', () {
      final Uint8List expected = Uint8List.fromList(
        List<int>.generate(96, (int i) => i & 0xff),
      );
      final ValidatorSigner signer = ValidatorSigner.custom(
        (Uint8List _) => expected,
      );
      expect(signer.sign(Uint8List.fromList(<int>[9, 9, 9])), equals(expected));
    });

    test('custom signer receives the message bytes unchanged', () {
      final Uint8List message = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      Uint8List? seen;
      final ValidatorSigner signer = ValidatorSigner.custom((Uint8List bytes) {
        seen = bytes;
        return Uint8List(96);
      });

      signer.sign(message);

      expect(seen, equals(message));
    });
  });
}
