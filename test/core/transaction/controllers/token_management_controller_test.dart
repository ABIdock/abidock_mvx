import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../../../fixtures/test_fixtures.dart';

void main() {
  late TokenManagementController controller;
  late IAccount alice;
  late IAccount bob;
  setUpAll(() async {
    alice = await createAliceAccount();
    bob = await createBobAccount();
    controller = TokenManagementController(chainId: const ChainId.devnet());
  });
  group('TokenManagementController - Token Issuance', () {
    test('should create transaction for issuing fungible token', () async {
      final input = IssueFungibleInput(
        tokenName: 'MyToken',
        tokenTicker: 'MTK',
        initialSupply: BigInt.from(1000000) * BigInt.from(10).pow(18),
        numDecimals: BigInt.from(18),
        canFreeze: true,
      );
      const baseInput = BaseControllerInput(gasLimit: GasLimit(60000000));
      final tx = await controller.createTransactionForIssuingFungible(
        alice,
        const Nonce(42),
        input,
        baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(
        tx.receiver.bech32,
        equals(
          'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
        ),
      );
      expect(tx.value.value, equals(BigInt.from(50000000000000000)));
      expect(tx.gasLimit.value, equals(60000000));
      expect(tx.nonce, equals(const Nonce(42)));
      expect(tx.signature, isNotNull);
    });
    test('should create transaction for issuing non-fungible token', () async {
      const input = IssueNonFungibleInput(
        tokenName: 'MyNFT',
        tokenTicker: 'MNFT',
        canTransferNFTCreateRole: true,
        canFreeze: true,
      );
      const baseInput = BaseControllerInput(gasLimit: GasLimit(60000000));
      final tx = await controller.createTransactionForIssuingNonFungible(
        alice,
        const Nonce(43),
        input,
        baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(
        tx.receiver.bech32,
        equals(
          'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
        ),
      );
      expect(tx.value.value, equals(BigInt.from(50000000000000000)));
      expect(tx.signature, isNotNull);
    });
    test('should create transaction for registering Meta-ESDT', () async {
      final input = RegisterMetaESDTInput(
        tokenName: 'MyMetaToken',
        tokenTicker: 'MMETA',
        numDecimals: BigInt.from(6),
      );
      const baseInput = BaseControllerInput(gasLimit: GasLimit(6000000));
      final tx = await controller.createTransactionForRegisteringMetaEsdt(
        alice,
        const Nonce(44),
        input,
        baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(
        tx.receiver.bech32,
        equals(
          'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
        ),
      );
      expect(tx.value.value, equals(BigInt.from(50000000000000000)));
      expect(tx.signature, isNotNull);
    });
  });
  group('TokenManagementController - Role Management', () {
    test(
      'should create transaction for setting fungible token special roles',
      () async {
        final input = FungibleSpecialRoleInput(
          user: bob.address,
          tokenIdentifier: 'MTK-123456',
          addRoleLocalMint: true,
          addRoleLocalBurn: true,
        );
        const baseInput = BaseControllerInput(gasLimit: GasLimit(60000000));
        final tx = await controller
            .createTransactionForSettingSpecialRoleOnFungibleToken(
              alice,
              const Nonce(50),
              input,
              baseInput,
            );
        expect(tx.sender, equals(alice.address));
        expect(
          tx.receiver.bech32,
          equals(
            'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
          ),
        );
        expect(tx.value.value, equals(BigInt.zero));
        expect(tx.signature, isNotNull);
      },
    );
    test('should create transaction for setting SFT special roles', () async {
      final input = SemiFungibleSpecialRoleInput(
        user: bob.address,
        tokenIdentifier: 'MSFT-123abc',
        addRoleNFTCreate: true,
        addRoleNFTAddQuantity: true,
      );
      const baseInput = BaseControllerInput(gasLimit: GasLimit(60000000));
      final tx = await controller
          .createTransactionForSettingSpecialRoleOnSemiFungibleToken(
            alice,
            const Nonce(51),
            input,
            baseInput,
          );
      expect(tx.sender, equals(alice.address));
      expect(
        tx.receiver.bech32,
        equals(
          'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
        ),
      );
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.signature, isNotNull);
    });
  });
  group('TokenManagementController - NFT Operations', () {
    test('should create transaction for creating NFT', () async {
      final input = MintInput(
        tokenIdentifier: 'MNFT-abcdef',
        initialQuantity: BigInt.one,
        name: 'My First NFT',
        royalties: 1000,
        hash: 'abc123',
        attributes: Uint8List.fromList([1, 2, 3, 4]),
        uris: ['https://example.com/nft1.json', 'https://example.com/nft1.png'],
      );
      const baseInput = BaseControllerInput(gasLimit: GasLimit(3000000));
      final tx = await controller.createTransactionForCreatingNft(
        alice,
        const Nonce(60),
        input,
        baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(
        tx.receiver.bech32,
        equals(
          'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
        ),
      );
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.signature, isNotNull);
    });
    test('should create transaction for local NFT burning', () async {
      final input = LocalBurnInput(
        tokenIdentifier: 'MNFT-abcdef',
        supplyToBurn: BigInt.one,
      );
      const baseInput = BaseControllerInput(gasLimit: GasLimit(3000000));
      final tx = await controller.createTransactionForLocalBurning(
        alice,
        const Nonce(61),
        input,
        baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(
        tx.receiver.bech32,
        equals(
          'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
        ),
      );
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.signature, isNotNull);
    });
  });
  group('TokenManagementController - Token Control', () {
    test('should create transaction for pausing token', () async {
      const input = PausingInput(tokenIdentifier: 'MTK-123456');
      const baseInput = BaseControllerInput(gasLimit: GasLimit(60000000));
      final tx = await controller.createTransactionForPausing(
        alice,
        const Nonce(70),
        input,
        baseInput,
      );
      expect(tx.sender, equals(alice.address));
      expect(
        tx.receiver.bech32,
        equals(
          'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u',
        ),
      );
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.signature, isNotNull);
    });
  });
}
