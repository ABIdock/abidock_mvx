import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../fixtures/test_fixtures.dart';

void main() {
  late ApiNetworkProvider provider;
  late UserSigner aliceSigner;

  setUp(() async {
    provider = ApiNetworkProvider.devnet();
    aliceSigner = await createAliceSigner();
  });

  group('Transaction Integration', () {
    test('should create and sign EGLD transfer', () async {
      final aliceAddr = await aliceSigner.getAddress();
      final account = await provider.getAccount(aliceAddr);
      final bobSigner = await createBobSigner();
      final bobAddr = await bobSigner.getAddress();

      final tx = Transaction(
        sender: aliceAddr,
        receiver: bobAddr,
        value: Balance.fromEgld(0.001),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('D'),
        version: const TransactionVersion(1),
        nonce: account.nonce,
        data: Uint8List(0),
      );

      final signature = await aliceSigner.sign(tx.serializeForSigning());
      final signedTx = tx.copyWith(
        newSignature: Signature.fromUint8List(signature),
      );

      expect(signedTx.signature, isNotNull);
      expect(signedTx.signature.hex.length, equals(128));
      expect(signedTx.value.toDenominatedTrimmed, equals('0.001'));
    });

    test('should create relayed V3 transaction', () async {
      final aliceAddr = await aliceSigner.getAddress();
      final aliceAccount = await provider.getAccount(aliceAddr);
      final aliceShard = Address.getShardOfAddress(aliceAddr);

      UserSigner relayerSigner = await createBobSigner();
      Address relayerAddr = await relayerSigner.getAddress();

      for (var i = 2; i <= 10; i++) {
        if (aliceShard == Address.getShardOfAddress(relayerAddr)) break;
        final mnemonic = Mnemonic.fromString(testMnemonic);
        final secretKey = await mnemonic.deriveKey(addressIndex: i);
        relayerSigner = UserSigner.fromSecretKey(secretKey);
        relayerAddr = await relayerSigner.getAddress();
      }

      if (aliceShard != Address.getShardOfAddress(relayerAddr)) {
        return;
      }

      final innerTx = Transaction(
        sender: aliceAddr,
        receiver: aliceAddr,
        value: Balance.fromEgld(0.001),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('D'),
        version: const TransactionVersion(2),
        nonce: aliceAccount.nonce,
        data: Uint8List(0),
        relayer: relayerAddr,
      );

      final aliceSignature = await aliceSigner.sign(
        innerTx.serializeForSigning(),
      );
      final aliceSignedTx = innerTx.copyWith(
        newSignature: Signature.fromUint8List(aliceSignature),
      );
      final relayedTx = await aliceSignedTx.signAsRelayer(relayerSigner);

      expect(relayedTx.signature, isNotNull);
      expect(relayedTx.relayerSignature, isNotNull);
      expect(relayedTx.relayer, equals(relayerAddr));
      expect(relayedTx.version.value, equals(2));
    });

    test('should compute transaction hash and nonce management', () async {
      final aliceAddr = await aliceSigner.getAddress();
      final account = await provider.getAccount(aliceAddr);

      final tx = Transaction(
        sender: aliceAddr,
        receiver: aliceAddr,
        value: Balance.fromEgld(0.001),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId('D'),
        version: const TransactionVersion(1),
        nonce: account.nonce,
        data: Uint8List(0),
      );

      final signature = await aliceSigner.sign(tx.serializeForSigning());
      final signedTx = tx.copyWith(
        newSignature: Signature.fromUint8List(signature),
      );

      const computer = TransactionComputer();
      final txHash = computer.computeTransactionHash(signedTx);
      expect(txHash.length, equals(64));

      const nonce = Nonce(42);
      final nextNonce = nonce.increment();
      expect(nextNonce.value, equals(43));
      expect(account.nonce.value, greaterThanOrEqualTo(0));
    });
  });
}
