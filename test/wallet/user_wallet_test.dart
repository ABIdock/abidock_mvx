import 'dart:io';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('UserWallet', () {
    test('fromSecretKey_encryption_decryption', () async {
      final secretKey = UserSecretKey.generate();
      final originalHex = secretKey.hex;
      final wallet = await UserWallet.fromSecretKey(
        secretKey: secretKey,
        password: 'test123',
      );
      final json = wallet.toJson();

      expect(json['kind'], equals('secretKey'));
      expect(json['crypto'], isNotNull);
      expect(json['bech32'], contains('erd1'));

      final decrypted = await UserWallet.decrypt(json, 'test123');
      expect(decrypted.hex, equals(originalHex));
      expect(() => UserWallet.decrypt(json, 'wrong'), throwsA(anything));
    });

    test('fromMnemonic_encryption_decryption', () async {
      final mnemonic = Mnemonic.generate();
      final wallet = UserWallet.fromMnemonic(
        mnemonic: mnemonic.getWords().join(' '),
        password: 'test123',
      );
      final json = wallet.toJson();

      expect(json['kind'], equals('mnemonic'));

      final key0 = await UserWallet.decrypt(json, 'test123', addressIndex: 0);
      final key1 = await UserWallet.decrypt(json, 'test123', addressIndex: 1);
      expect(key0.hex, isNot(equals(key1.hex)));
    });

    test('file_save_load_operations', () async {
      final tempDir = Directory.systemTemp.createTempSync('wallet_test');

      try {
        final secretKey = UserSecretKey.generate();
        final wallet = await UserWallet.fromSecretKey(
          secretKey: secretKey,
          password: 'test123',
        );

        final filePath = '${tempDir.path}/test_wallet.json';
        wallet.save(filePath);

        expect(File(filePath).existsSync(), isTrue);
        final loadedKey = await UserWallet.loadSecretKey(filePath, 'test123');
        expect(loadedKey.hex, equals(secretKey.hex));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('transaction_signing_integration', () async {
      final mnemonic = Mnemonic.generate();
      final wallet = UserWallet.fromMnemonic(
        mnemonic: mnemonic.getWords().join(' '),
        password: 'secure_password',
      );

      final json = wallet.toJson();
      final key = await UserWallet.decrypt(
        json,
        'secure_password',
        addressIndex: 0,
      );
      final publicKey = await key.generatePublicKey();
      final address = publicKey.toAddress();

      final transaction = Transaction(
        nonce: const Nonce(1),
        sender: address,
        receiver: address,
        data: Uint8List(0),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('D'),
        version: const TransactionVersion(1),
        value: Balance.zero(),
      );

      const computer = TransactionComputer();
      final serialized = computer.computeBytesForSigning(transaction);
      final signature = await key.sign(serialized);
      final isValid = await publicKey.verify(serialized, signature);

      expect(isValid, isTrue);
    });
  });
}
