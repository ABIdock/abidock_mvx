/// Payload pinning tests for the public builders on
/// [TokenManagementTransactionsFactory].
///
/// Every assertion compares against a **literal** data payload, receiver hex,
/// EGLD value and gas limit. Nothing is compared against the factory's own
/// config object: an assertion that reads the same constant the builder reads
/// passes for any value, including a wrong one, which is how two wrong system
/// contract addresses reached users.
///
/// The hex fragments are plain ASCII of each argument, which is the wire format
/// the ESDT system contract and the built-in function handlers parse. Numbers
/// are top-level encoded: minimal big-endian bytes, empty for zero.
///
/// Gas limits are the sum of the data-movement cost the chain charges for the
/// payload — `50000 + 1500 * payloadBytes` — and the execution cost of the
/// endpoint. `pause@4652414e4b2d313163653365` is 30 bytes, so
/// `50000 + 1500 * 30 + 60000000 = 60095000`. Each expectation below is the
/// arithmetic on the literal payload asserted in the same test.
///
/// The two account pubkeys are the bech32 payloads of the addresses spelled
/// out beside them.
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// ESDT system smart contract, the receiver of every management endpoint.
const String esdtSystemContractHex =
    '000000000000000000010000000000000000000000000000000000000002ffff';

/// Issuance cost in atomic units (0.05 EGLD).
const String issueCostAtomic = '50000000000000000';

const String senderBech32 =
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th';
const String senderHex =
    '0139472eff6886771a982f3083da5d421f24c29181e63888228dc81ca60d69e1';

const String userBech32 =
    'erd1r69gk66fmedhhcg24g2c5kn2f2a5k4kvpr6jfw67dn2lyydd8cfswy6ede';
const String userHex =
    '1e8a8b6b49de5b7be10aaa158a5a6a4abb4b56cc08f524bb5e6cd5f211ad3e13';

const String otherBech32 =
    'erd1kdl46yctawygtwg2k462307dmz2v55c605737dp3zkxh04sct7asqylhyv';
const String otherHex =
    'b37f5d130beb8885b90ab574a8bfcdd894ca531a7d3d1f3431158d77d6185fbb';

void main() {
  final TokenManagementTransactionsFactory factory =
      TokenManagementTransactionsFactory(
        config: const TokenManagementConfig(chainId: ChainId('D')),
      );
  final Address sender = Address.fromBech32(senderBech32);
  final Address user = Address.fromBech32(userBech32);
  final Address other = Address.fromBech32(otherBech32);

  String dataOf(Transaction tx) => utf8.decode(tx.data);

  void expectSystemContractCall(Transaction tx) {
    expect(tx.receiver.hex, equals(esdtSystemContractHex));
    expect(tx.sender.bech32, equals(senderBech32));
  }

  void expectBuiltInCall(Transaction tx) {
    expect(tx.receiver.bech32, equals(senderBech32));
    expect(tx.sender.bech32, equals(senderBech32));
    expect(tx.value.value, equals(BigInt.zero));
  }

  group('issuance endpoints', () {
    test(
      'issue emits name, ticker, supply, decimals and enabled properties',
      () {
        final Transaction tx = factory.createTransactionForIssuingFungible(
          sender: sender,
          tokenName: 'AlphaCoin',
          tokenTicker: 'ALPHA',
          initialSupply: BigInt.from(100),
          decimals: 0,
        );

        expect(
          dataOf(tx),
          equals(
            'issue@416c706861436f696e@414c504841@64@'
            '@63616e467265657a65@66616c7365'
            '@63616e57697065@66616c7365'
            '@63616e5061757365@66616c7365'
            '@63616e4368616e67654f776e6572@66616c7365'
            '@63616e55706772616465@74727565'
            '@63616e4164645370656369616c526f6c6573@66616c7365',
          ),
        );
        expectSystemContractCall(tx);
        expect(tx.value.value, equals(BigInt.parse(issueCostAtomic)));
        expect(tx.gasLimit.value, equals(60411500));
      },
    );

    /// `canTransferNFTCreateRole` is deliberately absent even when the caller
    /// enables it: the fungible endpoint has no NFT-create role to transfer,
    /// and its argument list does not carry that property.
    test('issue omits canTransferNFTCreateRole with every other flag on', () {
      final Transaction tx = factory.createTransactionForIssuingFungible(
        sender: sender,
        tokenName: 'AlphaCoin',
        tokenTicker: 'ALPHA',
        initialSupply: BigInt.from(1000000),
        decimals: 18,
        properties: const TokenProperties(
          canFreeze: true,
          canWipe: true,
          canPause: true,
          canTransferNFTCreateRole: true,
          canChangeOwner: true,
          canAddSpecialRoles: true,
        ),
      );

      expect(
        dataOf(tx),
        equals(
          'issue@416c706861436f696e@414c504841@0f4240@12'
          '@63616e467265657a65@74727565'
          '@63616e57697065@74727565'
          '@63616e5061757365@74727565'
          '@63616e4368616e67654f776e6572@74727565'
          '@63616e55706772616465@74727565'
          '@63616e4164645370656369616c526f6c6573@74727565',
        ),
      );
      expect(
        dataOf(tx),
        isNot(contains('63616e5472616e736665724e4654437265617465526f6c65')),
      );
      expectSystemContractCall(tx);
      expect(tx.gasLimit.value, equals(60405500));
    });

    test('issueSemiFungible emits name, ticker and enabled properties', () {
      final Transaction tx = factory.createTransactionForIssuingSemiFungible(
        sender: sender,
        tokenName: 'AlphaCoin',
        tokenTicker: 'ALPHA',
      );

      expect(
        dataOf(tx),
        equals(
          'issueSemiFungible@416c706861436f696e@414c504841'
          '@63616e467265657a65@66616c7365'
          '@63616e57697065@66616c7365'
          '@63616e5061757365@66616c7365'
          '@63616e5472616e736665724e4654437265617465526f6c65@66616c7365'
          '@63616e4368616e67654f776e6572@66616c7365'
          '@63616e55706772616465@74727565'
          '@63616e4164645370656369616c526f6c6573@66616c7365',
        ),
      );
      expectSystemContractCall(tx);
      expect(tx.value.value, equals(BigInt.parse(issueCostAtomic)));
      expect(tx.gasLimit.value, equals(60513500));
    });

    test('issueNonFungible emits name, ticker and enabled properties', () {
      final Transaction tx = factory.createTransactionForIssuingNonFungible(
        sender: sender,
        tokenName: 'AlphaCoin',
        tokenTicker: 'ALPHA',
        properties: const TokenProperties(canFreeze: true),
      );

      expect(
        dataOf(tx),
        equals(
          'issueNonFungible@416c706861436f696e@414c504841'
          '@63616e467265657a65@74727565'
          '@63616e57697065@66616c7365'
          '@63616e5061757365@66616c7365'
          '@63616e5472616e736665724e4654437265617465526f6c65@66616c7365'
          '@63616e4368616e67654f776e6572@66616c7365'
          '@63616e55706772616465@74727565'
          '@63616e4164645370656369616c526f6c6573@66616c7365',
        ),
      );
      expectSystemContractCall(tx);
      expect(tx.value.value, equals(BigInt.parse(issueCostAtomic)));
      expect(tx.gasLimit.value, equals(60509000));
    });

    test('registerMetaESDT emits name, ticker, decimals and properties', () {
      final Transaction tx = factory.createTransactionForRegisteringMetaEsdt(
        sender: sender,
        tokenName: 'AlphaCoin',
        tokenTicker: 'ALPHA',
        decimals: 18,
      );

      expect(
        dataOf(tx),
        equals(
          'registerMetaESDT@416c706861436f696e@414c504841@12'
          '@63616e467265657a65@66616c7365'
          '@63616e57697065@66616c7365'
          '@63616e5061757365@66616c7365'
          '@63616e5472616e736665724e4654437265617465526f6c65@66616c7365'
          '@63616e4368616e67654f776e6572@66616c7365'
          '@63616e55706772616465@74727565'
          '@63616e4164645370656369616c526f6c6573@66616c7365',
        ),
      );
      expectSystemContractCall(tx);
      expect(tx.value.value, equals(BigInt.parse(issueCostAtomic)));
      expect(tx.gasLimit.value, equals(60516500));
    });

    test('token name shorter than three characters is rejected', () {
      expect(
        () => factory.createTransactionForIssuingFungible(
          sender: sender,
          tokenName: 'Al',
          tokenTicker: 'ALPHA',
          initialSupply: BigInt.one,
          decimals: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('lowercase ticker is rejected', () {
      expect(
        () => factory.createTransactionForIssuingFungible(
          sender: sender,
          tokenName: 'AlphaCoin',
          tokenTicker: 'alpha',
          initialSupply: BigInt.one,
          decimals: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('role endpoints', () {
    test('setSpecialRole emits token, user and every requested role', () {
      final Transaction tx = factory
          .createTransactionForSettingSpecialRoleOnFungibleToken(
            sender: sender,
            user: user,
            tokenIdentifier: 'FRANK-11ce3e',
            roles: const <String>['ESDTRoleLocalMint', 'ESDTRoleLocalBurn'],
          );

      expect(
        dataOf(tx),
        equals(
          'setSpecialRole@4652414e4b2d313163653365@$userHex'
          '@45534454526f6c654c6f63616c4d696e74'
          '@45534454526f6c654c6f63616c4275726e',
        ),
      );
      expectSystemContractCall(tx);
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(60311000));
    });

    test('unSetSpecialRole emits token, user and every removed role', () {
      final Transaction tx = factory
          .createTransactionForUnsettingSpecialRoleOnFungibleToken(
            sender: sender,
            user: user,
            tokenIdentifier: 'FRANK-11ce3e',
            roles: const <String>['ESDTRoleLocalMint'],
          );

      expect(
        dataOf(tx),
        equals(
          'unSetSpecialRole@4652414e4b2d313163653365@$userHex'
          '@45534454526f6c654c6f63616c4d696e74',
        ),
      );
      expectSystemContractCall(tx);
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(60261500));
    });

    test('non-fungible role setter emits the same setSpecialRole call', () {
      final Transaction tx = factory
          .createTransactionForSettingSpecialRoleOnNonFungibleToken(
            sender: sender,
            user: user,
            tokenIdentifier: 'MYCOLL-1a2b3c',
            roles: const <String>[
              'ESDTRoleNFTCreate',
              'ESDTRoleNFTBurn',
              'ESDTRoleNFTAddQuantity',
            ],
          );

      expect(
        dataOf(tx),
        equals(
          'setSpecialRole@4d59434f4c4c2d316132623363@$userHex'
          '@45534454526f6c654e4654437265617465'
          '@45534454526f6c654e46544275726e'
          '@45534454526f6c654e46544164645175616e74697479',
        ),
      );
      expectSystemContractCall(tx);
      expect(tx.gasLimit.value, equals(60375500));
    });

    test('non-fungible role remover emits unSetSpecialRole', () {
      final Transaction tx = factory
          .createTransactionForUnsettingSpecialRoleOnNonFungibleToken(
            sender: sender,
            user: user,
            tokenIdentifier: 'MYCOLL-1a2b3c',
            roles: const <String>['ESDTRoleNFTBurn'],
          );

      expect(
        dataOf(tx),
        equals(
          'unSetSpecialRole@4d59434f4c4c2d316132623363@$userHex'
          '@45534454526f6c654e46544275726e',
        ),
      );
      expectSystemContractCall(tx);
      expect(tx.gasLimit.value, equals(60258500));
    });

    test('setBurnRoleGlobally carries only the token identifier', () {
      final Transaction tx = factory
          .createTransactionForSettingBurnRoleGlobally(
            sender: sender,
            tokenIdentifier: 'FRANK-11ce3e',
          );

      expect(
        dataOf(tx),
        equals('setBurnRoleGlobally@4652414e4b2d313163653365'),
      );
      expectSystemContractCall(tx);
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(60116000));
    });

    test('unsetBurnRoleGlobally carries only the token identifier', () {
      final Transaction tx = factory
          .createTransactionForUnsettingBurnRoleGlobally(
            sender: sender,
            tokenIdentifier: 'FRANK-11ce3e',
          );

      expect(
        dataOf(tx),
        equals('unsetBurnRoleGlobally@4652414e4b2d313163653365'),
      );
      expectSystemContractCall(tx);
      expect(tx.gasLimit.value, equals(60119000));
    });

    test('transferNFTCreateRole names the old and the new creator', () {
      final Transaction tx = factory
          .createTransactionForTransferringNftCreateRole(
            sender: sender,
            tokenIdentifier: 'SFT-123456',
            oldCreator: sender,
            newCreator: other,
          );

      expect(
        dataOf(tx),
        equals(
          'transferNFTCreateRole@5346542d313233343536@$senderHex@$otherHex',
        ),
      );
      expectSystemContractCall(tx);
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(60308000));
    });

    test('stopNFTCreate carries only the token identifier', () {
      final Transaction tx = factory.createTransactionForStoppingNftCreate(
        sender: sender,
        tokenIdentifier: 'SFT-123456',
      );

      expect(dataOf(tx), equals('stopNFTCreate@5346542d313233343536'));
      expectSystemContractCall(tx);
      expect(tx.gasLimit.value, equals(60101000));
    });

    test('transferOwnership names the new token manager', () {
      final Transaction tx = factory.createTransactionForTransferringOwnership(
        sender: sender,
        tokenIdentifier: 'AND-1d56f2',
        newOwner: other,
      );

      expect(
        dataOf(tx),
        equals('transferOwnership@414e442d316435366632@$otherHex'),
      );
      expectSystemContractCall(tx);
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(60204500));
    });

    test('controlChanges emits the enabled property pairs', () {
      final Transaction tx = factory.createTransactionForControllingProperties(
        sender: sender,
        tokenIdentifier: 'FRANK-11ce3e',
        properties: const TokenProperties(canFreeze: true, canWipe: true),
      );

      expect(
        dataOf(tx),
        equals(
          'controlChanges@4652414e4b2d313163653365'
          '@63616e467265657a65@74727565'
          '@63616e57697065@74727565'
          '@63616e5061757365@66616c7365'
          '@63616e5472616e736665724e4654437265617465526f6c65@66616c7365'
          '@63616e4368616e67654f776e6572@66616c7365'
          '@63616e55706772616465@74727565'
          '@63616e4164645370656369616c526f6c6573@66616c7365',
        ),
      );
      expectSystemContractCall(tx);
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(60495500));
    });
  });

  group('supply endpoints', () {
    test('ESDTLocalMint omits a zero nonce and is sent to the caller', () {
      final Transaction tx = factory.createTransactionForLocalMint(
        sender: sender,
        tokenIdentifier: 'FRANK-11ce3e',
        supplyToMint: BigInt.from(10),
      );

      expect(dataOf(tx), equals('ESDTLocalMint@4652414e4b2d313163653365@0a'));
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(411500));
    });

    test('ESDTLocalMint inserts the nonce when it is non-zero', () {
      final Transaction tx = factory.createTransactionForLocalMint(
        sender: sender,
        tokenIdentifier: 'SFT-123456',
        supplyToMint: BigInt.from(255),
        nonce: 7,
      );

      expect(dataOf(tx), equals('ESDTLocalMint@5346542d313233343536@07@ff'));
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(410000));
    });

    test('ESDTLocalBurn omits a zero nonce and is sent to the caller', () {
      final Transaction tx = factory.createTransactionForLocalBurn(
        sender: sender,
        tokenIdentifier: 'FRANK-11ce3e',
        supplyToBurn: BigInt.from(10),
      );

      expect(dataOf(tx), equals('ESDTLocalBurn@4652414e4b2d313163653365@0a'));
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(411500));
    });

    test('ESDTNFTAddQuantity carries token, nonce and quantity', () {
      final Transaction tx = factory.createTransactionForAddingQuantity(
        sender: sender,
        tokenIdentifier: 'SFT-123456',
        nonce: 10,
        quantityToAdd: BigInt.from(10),
      );

      expect(
        dataOf(tx),
        equals('ESDTNFTAddQuantity@5346542d313233343536@0a@0a'),
      );
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(1117500));
    });

    test('ESDTNFTBurn carries token, nonce and quantity', () {
      final Transaction tx = factory.createTransactionForBurningQuantity(
        sender: sender,
        tokenIdentifier: 'SFT-123456',
        nonce: 10,
        quantityToBurn: BigInt.from(10),
      );

      expect(dataOf(tx), equals('ESDTNFTBurn@5346542d313233343536@0a@0a'));
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(1107000));
    });

    test('ESDTNFTCreate emits hash and attributes as raw bytes', () {
      final Transaction tx = factory.createTransactionForCreatingNft(
        sender: sender,
        tokenIdentifier: 'FRANK-aa9e8d',
        initialQuantity: BigInt.one,
        name: 'test',
        royalties: 1000,
        hash: 'abba',
        attributes: Uint8List.fromList(utf8.encode('test')),
        uris: const <String>['a', 'b'],
      );

      expect(
        dataOf(tx),
        equals(
          'ESDTNFTCreate@4652414e4b2d616139653864@01@74657374@03e8'
          '@61626261@74657374@61@62',
        ),
      );
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(3228500));
    });

    test('ESDTNFTCreate leaves hash and attributes empty when omitted', () {
      final Transaction tx = factory.createTransactionForCreatingNft(
        sender: sender,
        tokenIdentifier: 'FRANK-aa9e8d',
        initialQuantity: BigInt.one,
        name: 'test',
        royalties: 0,
      );

      expect(
        dataOf(tx),
        equals('ESDTNFTCreate@4652414e4b2d616139653864@01@74657374@@@'),
      );
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(3129500));
    });
  });

  group('control endpoints', () {
    test('pause carries only the token identifier', () {
      final Transaction tx = factory.createTransactionForPausing(
        sender: sender,
        tokenIdentifier: 'FRANK-11ce3e',
      );

      expect(dataOf(tx), equals('pause@4652414e4b2d313163653365'));
      expectSystemContractCall(tx);
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(60095000));
    });

    test('unPause carries only the token identifier', () {
      final Transaction tx = factory.createTransactionForUnpausing(
        sender: sender,
        tokenIdentifier: 'FRANK-11ce3e',
      );

      expect(dataOf(tx), equals('unPause@4652414e4b2d313163653365'));
      expectSystemContractCall(tx);
      expect(tx.gasLimit.value, equals(60098000));
    });

    test('freeze names the account whose balance is frozen', () {
      final Transaction tx = factory.createTransactionForFreezing(
        sender: sender,
        tokenIdentifier: 'FRANK-11ce3e',
        addressToFreeze: user,
      );

      expect(dataOf(tx), equals('freeze@4652414e4b2d313163653365@$userHex'));
      expectSystemContractCall(tx);
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(60194000));
    });

    test('unFreeze names the account whose balance is released', () {
      final Transaction tx = factory.createTransactionForUnfreezing(
        sender: sender,
        tokenIdentifier: 'FRANK-11ce3e',
        addressToUnfreeze: user,
      );

      expect(dataOf(tx), equals('unFreeze@4652414e4b2d313163653365@$userHex'));
      expectSystemContractCall(tx);
      expect(tx.gasLimit.value, equals(60197000));
    });

    test('wipe omits a zero nonce', () {
      final Transaction tx = factory.createTransactionForWiping(
        sender: sender,
        tokenIdentifier: 'FRANK-11ce3e',
        addressToWipe: user,
      );

      expect(dataOf(tx), equals('wipe@4652414e4b2d313163653365@$userHex'));
      expectSystemContractCall(tx);
      expect(tx.gasLimit.value, equals(60191000));
    });

    test('wipe places a non-zero nonce between token and account', () {
      final Transaction tx = factory.createTransactionForWiping(
        sender: sender,
        tokenIdentifier: 'SFT-123456',
        addressToWipe: user,
        nonce: 1,
      );

      expect(dataOf(tx), equals('wipe@5346542d313233343536@01@$userHex'));
      expectSystemContractCall(tx);
      expect(tx.gasLimit.value, equals(60189500));
    });
  });

  group('metadata endpoints', () {
    test('ESDTNFTUpdateAttributes carries the raw attribute bytes', () {
      final Transaction tx = factory.createTransactionForUpdatingAttributes(
        sender: sender,
        tokenIdentifier: 'FRANK-11ce3e',
        nonce: 10,
        attributes: Uint8List.fromList(utf8.encode('test')),
      );

      expect(
        dataOf(tx),
        equals('ESDTNFTUpdateAttributes@4652414e4b2d313163653365@0a@74657374'),
      );
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(1180000));
    });

    test('ESDTModifyRoyalties carries token, nonce and basis points', () {
      final Transaction tx = factory.createTransactionForModifyingRoyalties(
        sender: sender,
        tokenIdentifier: 'TEST-123456',
        nonce: 1,
        newRoyalties: 1234,
      );

      expect(
        dataOf(tx),
        equals('ESDTModifyRoyalties@544553542d313233343536@01@04d2'),
      );
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(60125000));
    });

    test('ESDTSetNewURIs replaces the whole URI list', () {
      final Transaction tx = factory.createTransactionForSettingNewUris(
        sender: sender,
        tokenIdentifier: 'TEST-123456',
        nonce: 1,
        newUris: const <String>['firstURI', 'secondURI'],
      );

      expect(
        dataOf(tx),
        equals(
          'ESDTSetNewURIs@544553542d313233343536@01'
          '@6669727374555249@7365636f6e64555249',
        ),
      );
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(60334000));
    });

    test('ESDTNFTAddURI appends to the URI list', () {
      final Transaction tx = factory.createTransactionForAddingNftUri(
        sender: sender,
        tokenIdentifier: 'SFT-123456',
        nonce: 10,
        uris: const <String>['firstURI', 'secondURI'],
      );

      expect(
        dataOf(tx),
        equals(
          'ESDTNFTAddURI@5346542d313233343536@0a'
          '@6669727374555249@7365636f6e64555249',
        ),
      );
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(60159500));
    });

    test('ESDTNFTAddURI without a URI is rejected', () {
      expect(
        () => factory.createTransactionForAddingNftUri(
          sender: sender,
          tokenIdentifier: 'SFT-123456',
          nonce: 10,
          uris: const <String>[],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('ESDTModifyCreator carries token and nonce only', () {
      final Transaction tx = factory.createTransactionForModifyingCreator(
        sender: sender,
        tokenIdentifier: 'TEST-123456',
        nonce: 1,
      );

      expect(dataOf(tx), equals('ESDTModifyCreator@544553542d313233343536@01'));
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(60114500));
    });

    test('ESDTMetaDataUpdate emits the full instance payload', () {
      final Transaction tx = factory.createTransactionForUpdatingMetadata(
        sender: sender,
        tokenIdentifier: 'TEST-123456',
        nonce: 1,
        newName: 'Test',
        newRoyalties: 1234,
        newHash: 'abba',
        newAttributes: Uint8List.fromList(utf8.encode('test')),
        newUris: const <String>['firstURI', 'secondURI'],
      );

      expect(
        dataOf(tx),
        equals(
          'ESDTMetaDataUpdate@544553542d313233343536@01@54657374@04d2'
          '@61626261@74657374@6669727374555249@7365636f6e64555249',
        ),
      );
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(60428000));
    });

    test('ESDTMetaDataRecreate emits the full instance payload', () {
      final Transaction tx = factory.createTransactionForRecreatingMetadata(
        sender: sender,
        tokenIdentifier: 'TEST-123456',
        nonce: 1,
        newName: 'Test',
        newRoyalties: 1234,
        newHash: 'abba',
        newAttributes: Uint8List.fromList(utf8.encode('test')),
        newUris: const <String>['firstURI', 'secondURI'],
      );

      expect(
        dataOf(tx),
        equals(
          'ESDTMetaDataRecreate@544553542d313233343536@01@54657374@04d2'
          '@61626261@74657374@6669727374555249@7365636f6e64555249',
        ),
      );
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(60431000));
    });

    test('ESDTNFTUpdate emits the full instance payload', () {
      final Transaction tx = factory.createTransactionForNftUpdate(
        sender: sender,
        tokenIdentifier: 'TEST-123456',
        nonce: 1,
        newName: 'Test',
        newRoyalties: 1234,
        newHash: 'abba',
        newAttributes: Uint8List.fromList(utf8.encode('test')),
        newUris: const <String>['firstURI', 'secondURI'],
      );

      expect(
        dataOf(tx),
        equals(
          'ESDTNFTUpdate@544553542d313233343536@01@54657374@04d2'
          '@61626261@74657374@6669727374555249@7365636f6e64555249',
        ),
      );
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(60420500));
    });

    test('ESDTNFTRecreate emits the full instance payload', () {
      final Transaction tx = factory.createTransactionForNftRecreate(
        sender: sender,
        tokenIdentifier: 'TEST-123456',
        nonce: 1,
        newName: 'Test',
        newRoyalties: 1234,
        newHash: 'abba',
        newAttributes: Uint8List.fromList(utf8.encode('test')),
        newUris: const <String>['firstURI', 'secondURI'],
      );

      expect(
        dataOf(tx),
        equals(
          'ESDTNFTRecreate@544553542d313233343536@01@54657374@04d2'
          '@61626261@74657374@6669727374555249@7365636f6e64555249',
        ),
      );
      expectBuiltInCall(tx);
      expect(tx.gasLimit.value, equals(60423500));
    });
  });

  group('token type migration endpoints', () {
    test('changeToDynamic carries only the token identifier', () {
      final Transaction tx = factory.createTransactionForChangingToDynamic(
        sender: sender,
        tokenIdentifier: 'TEST-123456',
      );

      expect(dataOf(tx), equals('changeToDynamic@544553542d313233343536'));
      expectSystemContractCall(tx);
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(60107000));
    });

    test('updateTokenID carries only the token identifier', () {
      final Transaction tx = factory.createTransactionForUpdatingTokenId(
        sender: sender,
        tokenIdentifier: 'TEST-123456',
      );

      expect(dataOf(tx), equals('updateTokenID@544553542d313233343536'));
      expectSystemContractCall(tx);
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(60104000));
    });

    test('changeSFTToMetaESDT appends the new decimal precision', () {
      final Transaction tx = factory.createTransactionForChangingSftToMetaEsdt(
        sender: sender,
        tokenIdentifier: 'SFT-123456',
        numDecimals: 6,
      );

      expect(dataOf(tx), equals('changeSFTToMetaESDT@5346542d313233343536@06'));
      expectSystemContractCall(tx);
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(60114500));
    });
  });

  group('transaction envelope', () {
    test('builders leave nonce, version and signature unset', () {
      final Transaction tx = factory.createTransactionForPausing(
        sender: sender,
        tokenIdentifier: 'FRANK-11ce3e',
      );

      expect(tx.nonce.value, equals(0));
      expect(tx.version.value, equals(1));
      expect(tx.chainId.value, equals('D'));
      expect(tx.gasPrice.value, equals(1000000000));
      expect(tx.signature.hex, equals(''));
    });
  });
}
