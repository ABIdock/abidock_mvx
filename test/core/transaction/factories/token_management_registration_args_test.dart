import 'dart:convert';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  final TokenManagementTransactionsFactory factory =
      TokenManagementTransactionsFactory(
        config: const TokenManagementConfig(chainId: ChainId('D')),
      );
  final Address sender = Address.fromBech32(
    'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
  );

  String dataOf(Transaction tx) => utf8.decode(tx.data);

  group('F1.2 registerAndSetAllRoles carries the token type', () {
    test('emits exactly name, ticker, type and decimals for FNG', () {
      final Transaction tx = factory
          .createTransactionForRegisteringAndSettingRoles(
            sender: sender,
            tokenName: 'MyToken',
            tokenTicker: 'MTK',
            tokenType: 'FNG',
            decimals: 18,
          );

      expect(
        dataOf(tx),
        'registerAndSetAllRoles@4d79546f6b656e@4d544b@464e47@12',
      );
      expect(dataOf(tx).split('@').length, 5);
    });

    test('emits the NFT type marker in the third argument slot', () {
      final Transaction tx = factory
          .createTransactionForRegisteringAndSettingRoles(
            sender: sender,
            tokenName: 'MyToken',
            tokenTicker: 'MTK',
            tokenType: 'NFT',
            decimals: 0,
          );

      expect(
        dataOf(tx),
        'registerAndSetAllRoles@4d79546f6b656e@4d544b@4e4654@',
      );
      expect(dataOf(tx).split('@')[3], '4e4654');
    });

    test('never emits token property pairs', () {
      final Transaction tx = factory
          .createTransactionForRegisteringAndSettingRoles(
            sender: sender,
            tokenName: 'MyToken',
            tokenTicker: 'MTK',
            tokenType: 'META',
            decimals: 6,
          );

      expect(
        dataOf(tx),
        'registerAndSetAllRoles@4d79546f6b656e@4d544b@4d455441@06',
      );
      expect(dataOf(tx), isNot(contains('63616e55706772616465')));
      expect(dataOf(tx), isNot(contains('74727565')));
    });

    test('rejects an unrecognised token type', () {
      expect(
        () => factory.createTransactionForRegisteringAndSettingRoles(
          sender: sender,
          tokenName: 'MyToken',
          tokenTicker: 'MTK',
          tokenType: 'FUNGIBLE',
          decimals: 18,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('F1.3 registerDynamic carries the token type', () {
    test('emits exactly name, ticker and type for NFT', () {
      final Transaction tx = factory.createTransactionForRegisteringDynamic(
        sender: sender,
        tokenName: 'MyToken',
        tokenTicker: 'MTK',
        tokenType: 'NFT',
      );

      expect(dataOf(tx), 'registerDynamic@4d79546f6b656e@4d544b@4e4654');
      expect(dataOf(tx).split('@').length, 4);
    });

    test('emits exactly name, ticker and type for SFT', () {
      final Transaction tx = factory.createTransactionForRegisteringDynamic(
        sender: sender,
        tokenName: 'MyToken',
        tokenTicker: 'MTK',
        tokenType: 'SFT',
      );

      expect(dataOf(tx), 'registerDynamic@4d79546f6b656e@4d544b@534654');
    });

    test('appends decimals for META when supplied', () {
      final Transaction tx = factory.createTransactionForRegisteringDynamic(
        sender: sender,
        tokenName: 'MyToken',
        tokenTicker: 'MTK',
        tokenType: 'META',
        numDecimals: 18,
      );

      expect(dataOf(tx), 'registerDynamic@4d79546f6b656e@4d544b@4d455441@12');
    });

    test('omits decimals for META when not supplied', () {
      final Transaction tx = factory.createTransactionForRegisteringDynamic(
        sender: sender,
        tokenName: 'MyToken',
        tokenTicker: 'MTK',
        tokenType: 'META',
      );

      expect(dataOf(tx), 'registerDynamic@4d79546f6b656e@4d544b@4d455441');
    });

    test('ignores decimals for NFT even when supplied', () {
      final Transaction tx = factory.createTransactionForRegisteringDynamic(
        sender: sender,
        tokenName: 'MyToken',
        tokenTicker: 'MTK',
        tokenType: 'NFT',
        numDecimals: 18,
      );

      expect(dataOf(tx), 'registerDynamic@4d79546f6b656e@4d544b@4e4654');
    });

    test('rejects a fungible token type', () {
      expect(
        () => factory.createTransactionForRegisteringDynamic(
          sender: sender,
          tokenName: 'MyToken',
          tokenTicker: 'MTK',
          tokenType: 'FNG',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('never emits token property pairs', () {
      final Transaction tx = factory.createTransactionForRegisteringDynamic(
        sender: sender,
        tokenName: 'MyToken',
        tokenTicker: 'MTK',
        tokenType: 'NFT',
      );

      expect(dataOf(tx), isNot(contains('63616e55706772616465')));
      expect(dataOf(tx), isNot(contains('74727565')));
    });
  });

  group(
    'F1.4 registerAndSetAllRolesDynamic appends decimals only for META',
    () {
      test('emits exactly three arguments for dynamic NFT', () {
        final Transaction tx = factory
            .createTransactionForRegisteringAndSettingAllRolesDynamic(
              sender: sender,
              tokenName: 'MyToken',
              tokenTicker: 'MTK',
              tokenType: 'NFT',
            );

        expect(
          dataOf(tx),
          'registerAndSetAllRolesDynamic@4d79546f6b656e@4d544b@4e4654',
        );
        expect(dataOf(tx).split('@').length, 4);
      });

      test('emits exactly three arguments for dynamic SFT', () {
        final Transaction tx = factory
            .createTransactionForRegisteringAndSettingAllRolesDynamic(
              sender: sender,
              tokenName: 'MyToken',
              tokenTicker: 'MTK',
              tokenType: 'SFT',
            );

        expect(
          dataOf(tx),
          'registerAndSetAllRolesDynamic@4d79546f6b656e@4d544b@534654',
        );
      });

      test('drops decimals for dynamic SFT even when supplied', () {
        final Transaction tx = factory
            .createTransactionForRegisteringAndSettingAllRolesDynamic(
              sender: sender,
              tokenName: 'MyToken',
              tokenTicker: 'MTK',
              tokenType: 'SFT',
              numDecimals: 18,
            );

        expect(
          dataOf(tx),
          'registerAndSetAllRolesDynamic@4d79546f6b656e@4d544b@534654',
        );
      });

      test('appends decimals for dynamic META', () {
        final Transaction tx = factory
            .createTransactionForRegisteringAndSettingAllRolesDynamic(
              sender: sender,
              tokenName: 'MyToken',
              tokenTicker: 'MTK',
              tokenType: 'META',
              numDecimals: 18,
            );

        expect(
          dataOf(tx),
          'registerAndSetAllRolesDynamic@4d79546f6b656e@4d544b@4d455441@12',
        );
        expect(dataOf(tx).split('@').length, 5);
      });

      test('rejects a fungible token type', () {
        expect(
          () =>
              factory.createTransactionForRegisteringAndSettingAllRolesDynamic(
                sender: sender,
                tokenName: 'MyToken',
                tokenTicker: 'MTK',
                tokenType: 'FNG',
                numDecimals: 18,
              ),
          throwsA(isA<ArgumentError>()),
        );
      });
    },
  );

  group('F1.1 receiver selection', () {
    test('ESDTNFTCreate is addressed to the sender', () {
      final Transaction tx = factory.createTransactionForCreatingNft(
        sender: sender,
        tokenIdentifier: 'COLL-abc123',
        initialQuantity: BigInt.one,
        name: 'MyNFT',
        royalties: 500,
      );

      expect(
        tx.receiver.bech32,
        'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
      );
      expect(
        tx.receiver.hex,
        isNot(
          '000000000000000000010000000000000000000000000000000000000002ffff',
        ),
      );
      expect(dataOf(tx), startsWith('ESDTNFTCreate@'));
    });

    test('issue is addressed to the ESDT system contract', () {
      final Transaction tx = factory.createTransactionForIssuingFungible(
        sender: sender,
        tokenName: 'MyToken',
        tokenTicker: 'MTK',
        initialSupply: BigInt.from(100),
        decimals: 18,
      );

      expect(
        tx.receiver.hex,
        '000000000000000000010000000000000000000000000000000000000002ffff',
      );
      expect(dataOf(tx), startsWith('issue@'));
    });

    test('registerAndSetAllRoles is addressed to the ESDT system contract', () {
      final Transaction tx = factory
          .createTransactionForRegisteringAndSettingRoles(
            sender: sender,
            tokenName: 'MyToken',
            tokenTicker: 'MTK',
            tokenType: 'FNG',
            decimals: 18,
          );

      expect(
        tx.receiver.hex,
        '000000000000000000010000000000000000000000000000000000000002ffff',
      );
    });
  });
}
