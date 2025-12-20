import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../../../fixtures/test_fixtures.dart';

void main() {
  late IAccount alice;
  late IAccount bob;
  late Address guardianAddress;
  late AccountController controller;

  setUpAll(() async {
    alice = await createAliceAccount();
    bob = await createBobAccount();
    guardianAddress = Address.fromBech32(
      'erd1k2s324ww2g0yj38qn2ch2jwctdy8mnfxep94q9arncc6xecg3xaq6mjse8',
    );
    controller = AccountController(chainId: const ChainId.devnet());
  });

  group('Account Storage', () {
    test('handles key-value storage operations', () async {
      const ChainId.devnet();
      final singleInput = SaveKeyValueInput(
        keyValuePairs: {
          Uint8List.fromList(utf8.encode('username')): Uint8List.fromList(
            utf8.encode('alice'),
          ),
        },
      );
      const baseInput = BaseControllerInput(gasLimit: GasLimit(500000));
      final singleTx = await controller.createTransactionForSavingKeyValue(
        alice,
        const Nonce(100),
        singleInput,
        baseOptions: baseInput,
      );
      expect(singleTx.sender, equals(alice.address));
      expect(singleTx.receiver, equals(alice.address));
      expect(singleTx.gasLimit.value, equals(500000));
      expect(singleTx.signature, isNotNull);
      expect(singleTx.data, isNotEmpty);

      final multiInput = SaveKeyValueInput(
        keyValuePairs: {
          Uint8List.fromList(utf8.encode('username')): Uint8List.fromList(
            utf8.encode('alice'),
          ),
          Uint8List.fromList(utf8.encode('email')): Uint8List.fromList(
            utf8.encode('alice@example.com'),
          ),
          Uint8List.fromList(utf8.encode('age')): Uint8List.fromList([25]),
        },
      );
      final multiTx = await controller.createTransactionForSavingKeyValue(
        alice,
        const Nonce(101),
        multiInput,
        baseOptions: const BaseControllerInput(gasLimit: GasLimit(600000)),
      );
      expect(multiTx.data, isNotEmpty);

      final binaryInput = SaveKeyValueInput(
        keyValuePairs: {
          Uint8List.fromList([0xFF, 0xAB, 0xCD, 0xEF]): Uint8List.fromList([
            0x01,
            0x02,
            0x03,
            0x04,
          ]),
        },
      );
      final binaryTx = await controller.createTransactionForSavingKeyValue(
        alice,
        const Nonce(102),
        binaryInput,
        baseOptions: const BaseControllerInput(gasLimit: GasLimit(500000)),
      );
      expect(binaryTx.data, isNotEmpty);
    });
  });

  group('Guardian Management', () {
    test('handles guardian setup and activation', () async {
      final setupInput = SetGuardianInput(
        guardianAddress: guardianAddress,
        serviceId: 'twikey-2fa',
      );
      final setupTx = await controller.createTransactionForSettingGuardian(
        alice,
        const Nonce(200),
        setupInput,
        baseOptions: const BaseControllerInput(gasLimit: GasLimit(250000)),
      );
      expect(setupTx.sender, equals(alice.address));
      expect(setupTx.gasLimit.value, equals(250000));
      expect(setupTx.signature, isNotNull);
      expect(setupTx.data, isNotEmpty);

      final activateTx = await controller.createTransactionForGuardingAccount(
        alice,
        const Nonce(300),
        options: const BaseControllerInput(gasLimit: GasLimit(250000)),
      );
      expect(activateTx.sender, equals(alice.address));
      expect(activateTx.signature, isNotNull);
      expect(activateTx.chainId, equals(const ChainId('D')));

      final selfGuardianInput = SetGuardianInput(
        guardianAddress: alice.address,
        serviceId: 'self-custody',
      );
      final selfTx = await controller.createTransactionForSettingGuardian(
        alice,
        const Nonce(202),
        selfGuardianInput,
        baseOptions: const BaseControllerInput(gasLimit: GasLimit(250000)),
      );
      expect(selfTx.sender, equals(alice.address));
    });

    test('handles guardian removal', () async {
      final baseInput = BaseControllerInput(
        gasLimit: const GasLimit(250000),
        guardian: guardianAddress,
      );
      final unguardTx = await controller.createTransactionForUnguardingAccount(
        alice,
        const Nonce(400),
        options: baseInput,
      );
      expect(unguardTx.sender, equals(alice.address));
      expect(unguardTx.guardian, equals(guardianAddress));
      expect(unguardTx.guardianSignature, isNotNull);
      expect(unguardTx.data, isNotEmpty);

      final customGuardianInput = BaseControllerInput(
        gasLimit: const GasLimit(250000),
        guardian: alice.address,
      );
      final customTx = await controller.createTransactionForUnguardingAccount(
        alice,
        const Nonce(402),
        options: customGuardianInput,
      );
      expect(customTx.guardian, equals(alice.address));
    });
  });

  group('Transaction Properties', () {
    test('handles transaction properties and signatures', () async {
      final input = SaveKeyValueInput(
        keyValuePairs: {
          Uint8List.fromList(utf8.encode('test')): Uint8List.fromList([1]),
        },
      );
      final tx = await controller.createTransactionForSavingKeyValue(
        alice,
        const Nonce(500),
        input,
      );
      expect(tx.chainId, equals(const ChainId('D')));
      expect(tx.signature.bytes.length, equals(64));

      final tx1 = await controller.createTransactionForSavingKeyValue(
        alice,
        const Nonce(504),
        input,
      );
      final tx2 = await controller.createTransactionForSavingKeyValue(
        alice,
        const Nonce(504),
        input,
      );
      expect(tx1.signature.hex, equals(tx2.signature.hex));

      final customGasTx = await controller.createTransactionForSavingKeyValue(
        alice,
        const Nonce(505),
        input,
        baseOptions: const BaseControllerInput(
          gasLimit: GasLimit(500000),
          gasPrice: GasPrice(2000000000),
        ),
      );
      expect(customGasTx.gasPrice.value, equals(2000000000));
    });

    test('supports different accounts', () async {
      final input = SaveKeyValueInput(
        keyValuePairs: {
          Uint8List.fromList(utf8.encode('bob_data')): Uint8List.fromList([99]),
        },
      );
      final bobTx = await controller.createTransactionForSavingKeyValue(
        bob,
        const Nonce(600),
        input,
      );
      expect(bobTx.sender, equals(bob.address));
      expect(bobTx.receiver, equals(bob.address));

      final aliceSetsBob = SetGuardianInput(
        guardianAddress: bob.address,
        serviceId: 'alice-sets-bob',
      );
      final crossTx = await controller.createTransactionForSettingGuardian(
        alice,
        const Nonce(601),
        aliceSetsBob,
      );
      expect(crossTx.sender, equals(alice.address));
    });
  });

  group('Advanced Scenarios', () {
    test('handles real-world scenarios', () async {
      final profileData = json.encode({
        'username': 'alice_crypto',
        'email': 'alice@blockchain.com',
        'preferences': {'theme': 'dark', 'notifications': true},
      });
      final profileInput = SaveKeyValueInput(
        keyValuePairs: {
          Uint8List.fromList(utf8.encode('user_profile')): Uint8List.fromList(
            utf8.encode(profileData),
          ),
        },
      );
      final profileTx = await controller.createTransactionForSavingKeyValue(
        alice,
        const Nonce(700),
        profileInput,
      );
      expect(profileTx.data, isNotEmpty);

      final operations = <Transaction>[];
      operations.add(
        await controller.createTransactionForSavingKeyValue(
          alice,
          const Nonce(704),
          SaveKeyValueInput(
            keyValuePairs: {
              Uint8List.fromList(utf8.encode('batch_op_1')): Uint8List.fromList(
                [1],
              ),
            },
          ),
        ),
      );
      operations.add(
        await controller.createTransactionForSettingGuardian(
          alice,
          const Nonce(705),
          SetGuardianInput(
            guardianAddress: guardianAddress,
            serviceId: 'batch-operation',
          ),
        ),
      );
      expect(operations.length, equals(2));
      expect(operations[0].nonce.value, equals(704));
      expect(operations[1].nonce.value, equals(705));
    });

    test('handles edge cases', () async {
      final largeDataInput = SaveKeyValueInput(
        keyValuePairs: {
          Uint8List.fromList(utf8.encode('large_data')): Uint8List.fromList(
            utf8.encode('A' * 5000),
          ),
        },
      );
      final largeTx = await controller.createTransactionForSavingKeyValue(
        alice,
        const Nonce(800),
        largeDataInput,
        baseOptions: const BaseControllerInput(gasLimit: GasLimit(2000000)),
      );
      expect(largeTx.gasLimit.value, equals(2000000));

      final unicodeInput = SaveKeyValueInput(
        keyValuePairs: {
          Uint8List.fromList(utf8.encode('unicode_test')): Uint8List.fromList(
            utf8.encode('Hello 🌍 Universe! 안녕하세요 🚀'),
          ),
        },
      );
      final unicodeTx = await controller.createTransactionForSavingKeyValue(
        alice,
        const Nonce(801),
        unicodeInput,
      );
      expect(unicodeTx.data, isNotEmpty);

      final zeroGasTx = await controller.createTransactionForGuardingAccount(
        alice,
        const Nonce(803),
        options: const BaseControllerInput(gasPrice: GasPrice(0)),
      );
      expect(zeroGasTx.gasPrice.value, equals(0));
    });
  });
}
