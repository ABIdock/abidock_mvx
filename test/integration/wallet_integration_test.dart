import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../fixtures/test_fixtures.dart';

void main() {
  group('Mnemonic Wallet Integration', () {
    test('should create signer from mnemonic', () async {
      final signer = await createAliceSigner();
      final address = await signer.getAddress();
      expect(address.bech32.startsWith('erd1'), isTrue);
      expect(address.bech32.length, equals(62));
    });
    test('should sign bytes with derived key', () async {
      final signer = await createAliceSigner();
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final signature = await signer.sign(data);
      expect(signature.length, equals(64));
    });
  });
  group('Address Conversion Integration', () {
    test('should convert between Address and AddressValue', () async {
      final signer = await createAliceSigner();
      final address = await signer.getAddress();
      final addressValue = address.toAddressValue();
      expect(addressValue.value.length, equals(32));
      expect(addressValue.toBech32().startsWith('erd1'), isTrue);
      final converted = addressValue.toAddress();
      expect(converted.bech32, equals(address.bech32));
    });
  });
}
