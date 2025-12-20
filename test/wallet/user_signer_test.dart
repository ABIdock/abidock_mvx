import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../fixtures/test_fixtures.dart';

void main() {
  group('UserSigner', () {
    test('loads from mnemonic and generates address', () async {
      final signer = await createAliceSigner();
      expect(signer, isNotNull);

      final address = await signer.getAddress();
      expect(address.bech32.startsWith('erd1'), isTrue);
      expect(address.bech32.length, equals(62));
    });

    test('signs messages deterministically', () async {
      final signer = await createAliceSigner();
      final message = Uint8List.fromList('test message'.codeUnits);

      final signature = await signer.sign(message);
      expect(signature, isNotNull);
      expect(signature.length, 64);

      final sig2 = await signer.sign(message);
      expect(signature, equals(sig2));
    });
  });

  group('UserSecretKey', () {
    test('derives from mnemonic and signs data', () async {
      final mnemonic = Mnemonic.fromString(testMnemonic);
      final secretKey = await mnemonic.deriveKey(addressIndex: 0);
      expect(secretKey, isNotNull);

      final message = Uint8List.fromList('test'.codeUnits);
      final signature = await secretKey.sign(message);
      expect(signature.length, 64);
    });
  });
}
