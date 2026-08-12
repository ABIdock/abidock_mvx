/// Decoding tests for [TokenManagementOutcomeParser].
///
/// Each test feeds a literal event-topic fixture shaped exactly like the log
/// entries the chain emits for ESDT operations, then asserts every field of the
/// decoded result. Topic layouts follow the wire format:
///
/// - issuance events carry `[tokenIdentifier, name, ticker, type, decimals]`
/// - built-in function events carry `[tokenIdentifier, nonce, value, extra]`,
///   where `extra` is the frozen/wiped account for freeze-family events and the
///   new attributes or metadata for the update-family events
/// - `ESDTSetRole` carries `[tokenIdentifier, nonce, value, ...roles]`
///
/// Numbers are unsigned big-endian with no padding; a zero is an empty topic.
/// Strings are plain ASCII bytes. The account pubkey below is the bech32
/// payload of the address spelled out beside it.
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

const String holderBech32 =
    'erd1r69gk66fmedhhcg24g2c5kn2f2a5k4kvpr6jfw67dn2lyydd8cfswy6ede';
const String holderHex =
    '1e8a8b6b49de5b7be10aaa158a5a6a4abb4b56cc08f524bb5e6cd5f211ad3e13';

const String esdtSystemContractBech32 =
    'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u';

/// ASCII topic, the encoding used for identifiers, names, roles and URIs.
Uint8List text(String value) => Uint8List.fromList(utf8.encode(value));

/// Raw byte topic, used for unsigned big-endian numbers and pubkeys.
Uint8List bytes(List<int> value) => Uint8List.fromList(value);

/// Decodes a literal pubkey written as hex into its 32 raw bytes.
Uint8List hexBytes(String value) {
  final Uint8List out = Uint8List(value.length ~/ 2);
  for (int i = 0; i < out.length; i++) {
    out[i] = int.parse(value.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// Empty topic, which is how the chain writes a zero number.
Uint8List empty() => Uint8List(0);

void main() {
  const TokenManagementOutcomeParser parser = TokenManagementOutcomeParser();

  final Address holder = Address.fromBech32(holderBech32);
  final Address esdtContract = Address.fromBech32(esdtSystemContractBech32);

  final Transaction baseTransaction = Transaction(
    sender: holder,
    receiver: esdtContract,
    value: Balance.zero(),
    gasLimit: const GasLimit(60000000),
    gasPrice: const GasPrice(1000000000),
    chainId: const ChainId('D'),
    nonce: const Nonce(7),
    data: Uint8List(0),
    version: const TransactionVersion(1),
  );

  TransactionEvent event(
    String identifier,
    List<Uint8List> topics, {
    Address? emitter,
    List<Uint8List> additionalData = const <Uint8List>[],
  }) {
    return TransactionEvent(
      address: emitter ?? holder,
      identifier: identifier,
      topics: topics,
      data: Uint8List(0),
      additionalData: additionalData,
    );
  }

  TransactionOnNetwork transactionWith(List<TransactionEvent> events) {
    return TransactionOnNetwork(
      transaction: baseTransaction,
      status: TransactionStatus.success,
      txHash: '00' * 32,
      blockNonce: 100,
      timestamp: 1234567890,
      logs: TransactionLogs(address: holder, events: events),
    );
  }

  group('issuance outcomes', () {
    test('parseIssueFungible reads the identifier from the issue event', () {
      final List<IssueFungibleResult> results = parser.parseIssueFungible(
        transactionWith(<TransactionEvent>[
          event('issue', <Uint8List>[
            text('ZZZ-9ee87d'),
            text('SECOND'),
            text('ZZZ'),
            text('FungibleESDT'),
            bytes(<int>[0x02]),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('ZZZ-9ee87d'));
    });

    test('parseIssueNonFungible reads the collection identifier', () {
      final List<IssueNonFungibleResult> results = parser.parseIssueNonFungible(
        transactionWith(<TransactionEvent>[
          event('issueNonFungible', <Uint8List>[
            text('NFT-f01d1e'),
            text('NFTEST'),
            text('NFT'),
            text('NonFungibleESDT'),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('NFT-f01d1e'));
    });

    test('parseIssueSemiFungible reads the collection identifier', () {
      final List<IssueSemiFungibleResult> results = parser
          .parseIssueSemiFungible(
            transactionWith(<TransactionEvent>[
              event('issueSemiFungible', <Uint8List>[
                text('SEMIFNG-2c6d9f'),
                text('SEMI'),
                text('SEMIFNG'),
                text('SemiFungibleESDT'),
              ]),
            ]),
          );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('SEMIFNG-2c6d9f'));
    });

    test('parseRegisterMetaEsdt reads the identifier', () {
      final List<RegisterMetaEsdtResult> results = parser.parseRegisterMetaEsdt(
        transactionWith(<TransactionEvent>[
          event('registerMetaESDT', <Uint8List>[
            text('METATEST-e05d11'),
            text('METATEST'),
            text('METATEST'),
            text('MetaESDT'),
            bytes(<int>[0x12]),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('METATEST-e05d11'));
    });

    test('parseIssueFungible returns one result per issue event', () {
      final List<IssueFungibleResult> results = parser.parseIssueFungible(
        transactionWith(<TransactionEvent>[
          event('issue', <Uint8List>[text('AAA-29c4c9')]),
          event('issue', <Uint8List>[text('BBB-1a2b3c')]),
        ]),
      );

      expect(results, hasLength(2));
      expect(results[0].tokenIdentifier, equals('AAA-29c4c9'));
      expect(results[1].tokenIdentifier, equals('BBB-1a2b3c'));
    });

    test(
      'parseIssueFungible yields an empty identifier for an empty topic',
      () {
        final List<IssueFungibleResult> results = parser.parseIssueFungible(
          transactionWith(<TransactionEvent>[
            event('issue', <Uint8List>[empty()]),
          ]),
        );

        expect(results, hasLength(1));
        expect(results.single.tokenIdentifier, equals(''));
      },
    );
  });

  group('role outcomes', () {
    test('parseRegisterAndSetAllRoles pairs each token with its roles', () {
      final List<RegisterAndSetAllRolesResult> results = parser
          .parseRegisterAndSetAllRoles(
            transactionWith(<TransactionEvent>[
              event('registerAndSetAllRoles', <Uint8List>[
                text('LMAO-d9f892'),
                text('LMAO'),
                text('LMAO'),
                text('FungibleESDT'),
                bytes(<int>[0x02]),
              ]),
              event('registerAndSetAllRoles', <Uint8List>[
                text('TST-123456'),
                text('TST'),
                text('TST'),
                text('FungibleESDT'),
                bytes(<int>[0x02]),
              ]),
              event('ESDTSetRole', <Uint8List>[
                text('LMAO-d9f892'),
                empty(),
                empty(),
                text('ESDTRoleLocalMint'),
                text('ESDTRoleLocalBurn'),
              ]),
              event('ESDTSetRole', <Uint8List>[
                text('TST-123456'),
                empty(),
                empty(),
                text('ESDTRoleLocalMint'),
                text('ESDTRoleLocalBurn'),
              ]),
            ]),
          );

      expect(results, hasLength(2));
      expect(results[0].tokenIdentifier, equals('LMAO-d9f892'));
      expect(
        results[0].roles,
        equals(<String>['ESDTRoleLocalMint', 'ESDTRoleLocalBurn']),
      );
      expect(results[1].tokenIdentifier, equals('TST-123456'));
      expect(
        results[1].roles,
        equals(<String>['ESDTRoleLocalMint', 'ESDTRoleLocalBurn']),
      );
    });

    test('parseRegisterAndSetAllRoles rejects mismatched event counts', () {
      expect(
        () => parser.parseRegisterAndSetAllRoles(
          transactionWith(<TransactionEvent>[
            event('registerAndSetAllRoles', <Uint8List>[text('LMAO-d9f892')]),
            event('registerAndSetAllRoles', <Uint8List>[text('TST-123456')]),
            event('ESDTSetRole', <Uint8List>[
              text('LMAO-d9f892'),
              empty(),
              empty(),
              text('ESDTRoleLocalMint'),
            ]),
          ]),
        ),
        throwsA(isA<TokenManagementParseException>()),
      );
    });

    test('parseSetSpecialRole reports the holder, token and every role', () {
      final List<SetSpecialRoleResult> results = parser.parseSetSpecialRole(
        transactionWith(<TransactionEvent>[
          event('ESDTSetRole', <Uint8List>[
            text('METATEST-e05d11'),
            empty(),
            empty(),
            text('ESDTRoleNFTCreate'),
            text('ESDTRoleNFTAddQuantity'),
            text('ESDTRoleNFTBurn'),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.userAddress.bech32, equals(holderBech32));
      expect(results.single.tokenIdentifier, equals('METATEST-e05d11'));
      expect(
        results.single.roles,
        equals(<String>[
          'ESDTRoleNFTCreate',
          'ESDTRoleNFTAddQuantity',
          'ESDTRoleNFTBurn',
        ]),
      );
    });

    test('parseSetSpecialRole reports no roles when none were granted', () {
      final List<SetSpecialRoleResult> results = parser.parseSetSpecialRole(
        transactionWith(<TransactionEvent>[
          event('ESDTSetRole', <Uint8List>[
            text('METATEST-e05d11'),
            empty(),
            empty(),
          ]),
        ]),
      );

      expect(results.single.roles, isEmpty);
    });

    test('parseSetBurnRoleGlobally accepts a successful transaction', () {
      expect(
        () => parser.parseSetBurnRoleGlobally(
          transactionWith(<TransactionEvent>[
            event('ESDTSetBurnRoleForAll', <Uint8List>[text('AAA-29c4c9')]),
          ]),
        ),
        returnsNormally,
      );
    });

    test('parseUnsetBurnRoleGlobally accepts a successful transaction', () {
      expect(
        () => parser.parseUnsetBurnRoleGlobally(
          transactionWith(<TransactionEvent>[
            event('ESDTUnSetBurnRoleForAll', <Uint8List>[text('AAA-29c4c9')]),
          ]),
        ),
        returnsNormally,
      );
    });

    test('parseSetBurnRoleGlobally rejects a failed transaction', () {
      expect(
        () => parser.parseSetBurnRoleGlobally(
          transactionWith(<TransactionEvent>[
            event('signalError', <Uint8List>[
              hexBytes(holderHex),
              text('cannot set burn role globally'),
            ]),
          ]),
        ),
        throwsA(isA<TokenManagementParseException>()),
      );
    });
  });

  group('supply outcomes', () {
    test('parseNftCreate reports identifier, nonce and initial quantity', () {
      final List<NftCreateResult> results = parser.parseNftCreate(
        transactionWith(<TransactionEvent>[
          event('ESDTNFTCreate', <Uint8List>[
            text('NFT-f01d1e'),
            bytes(<int>[0x01]),
            bytes(<int>[0x01]),
            text('metadata'),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('NFT-f01d1e'));
      expect(results.single.nonce, equals(BigInt.one));
      expect(results.single.initialQuantity, equals(BigInt.one));
    });

    test('parseNftCreate decodes a multi-byte nonce and quantity', () {
      final List<NftCreateResult> results = parser.parseNftCreate(
        transactionWith(<TransactionEvent>[
          event('ESDTNFTCreate', <Uint8List>[
            text('SFT-123456'),
            bytes(<int>[0x01, 0x00]),
            bytes(<int>[0x27, 0x10]),
            empty(),
          ]),
        ]),
      );

      expect(results.single.nonce, equals(BigInt.from(256)));
      expect(results.single.initialQuantity, equals(BigInt.from(10000)));
    });

    test('parseLocalMint reports minter, token, nonce and minted supply', () {
      final List<LocalMintResult> results = parser.parseLocalMint(
        transactionWith(<TransactionEvent>[
          event('ESDTLocalMint', <Uint8List>[
            text('AAA-29c4c9'),
            empty(),
            bytes(<int>[0x01, 0x86, 0xa0]),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.userAddress.bech32, equals(holderBech32));
      expect(results.single.tokenIdentifier, equals('AAA-29c4c9'));
      expect(results.single.nonce, equals(BigInt.zero));
      expect(results.single.mintedSupply, equals(BigInt.from(100000)));
    });

    test('parseLocalBurn reports burner, token, nonce and burnt supply', () {
      final List<LocalBurnResult> results = parser.parseLocalBurn(
        transactionWith(<TransactionEvent>[
          event('ESDTLocalBurn', <Uint8List>[
            text('AAA-29c4c9'),
            empty(),
            bytes(<int>[0x01, 0x86, 0xa0]),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.userAddress.bech32, equals(holderBech32));
      expect(results.single.tokenIdentifier, equals('AAA-29c4c9'));
      expect(results.single.nonce, equals(BigInt.zero));
      expect(results.single.burntSupply, equals(BigInt.from(100000)));
    });

    test('parseAddQuantity reports token, nonce and added quantity', () {
      final List<AddQuantityResult> results = parser.parseAddQuantity(
        transactionWith(<TransactionEvent>[
          event('ESDTNFTAddQuantity', <Uint8List>[
            text('SFT-123456'),
            bytes(<int>[0x0a]),
            bytes(<int>[0x14]),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('SFT-123456'));
      expect(results.single.nonce, equals(BigInt.from(10)));
      expect(results.single.addedQuantity, equals(BigInt.from(20)));
    });

    test('parseBurnQuantity reports token, nonce and burnt quantity', () {
      final List<BurnQuantityResult> results = parser.parseBurnQuantity(
        transactionWith(<TransactionEvent>[
          event('ESDTNFTBurn', <Uint8List>[
            text('SFT-123456'),
            bytes(<int>[0x0a]),
            bytes(<int>[0x14]),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('SFT-123456'));
      expect(results.single.nonce, equals(BigInt.from(10)));
      expect(results.single.burntQuantity, equals(BigInt.from(20)));
    });
  });

  group('control outcomes', () {
    test('parsePause reports the paused token', () {
      final List<PauseResult> results = parser.parsePause(
        transactionWith(<TransactionEvent>[
          event('ESDTPause', <Uint8List>[text('AAA-29c4c9')]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('AAA-29c4c9'));
    });

    test('parseUnpause reports the unpaused token', () {
      final List<UnpauseResult> results = parser.parseUnpause(
        transactionWith(<TransactionEvent>[
          event('ESDTUnPause', <Uint8List>[text('AAA-29c4c9')]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('AAA-29c4c9'));
    });

    test('parsePause ignores an unpause event', () {
      final List<PauseResult> results = parser.parsePause(
        transactionWith(<TransactionEvent>[
          event('ESDTUnPause', <Uint8List>[text('AAA-29c4c9')]),
        ]),
      );

      expect(results, isEmpty);
    });

    test(
      'parseFreeze reports the frozen account, token, nonce and balance',
      () {
        final List<FreezeResult> results = parser.parseFreeze(
          transactionWith(<TransactionEvent>[
            event('ESDTFreeze', <Uint8List>[
              text('AAA-29c4c9'),
              empty(),
              bytes(<int>[0x98, 0x96, 0x80]),
              hexBytes(holderHex),
            ]),
          ]),
        );

        expect(results, hasLength(1));
        expect(results.single.userAddress, equals(holderBech32));
        expect(results.single.tokenIdentifier, equals('AAA-29c4c9'));
        expect(results.single.nonce, equals(BigInt.zero));
        expect(results.single.balance, equals(BigInt.from(10000000)));
      },
    );

    test('parseUnfreeze reports the released account and balance', () {
      final List<UnfreezeResult> results = parser.parseUnfreeze(
        transactionWith(<TransactionEvent>[
          event('ESDTUnFreeze', <Uint8List>[
            text('AAA-29c4c9'),
            empty(),
            bytes(<int>[0x98, 0x96, 0x80]),
            hexBytes(holderHex),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.userAddress, equals(holderBech32));
      expect(results.single.tokenIdentifier, equals('AAA-29c4c9'));
      expect(results.single.nonce, equals(BigInt.zero));
      expect(results.single.balance, equals(BigInt.from(10000000)));
    });

    test('parseWipe reports the wiped account, nonce and balance', () {
      final List<WipeResult> results = parser.parseWipe(
        transactionWith(<TransactionEvent>[
          event('ESDTWipe', <Uint8List>[
            text('SFT-123456'),
            bytes(<int>[0x02]),
            bytes(<int>[0x98, 0x96, 0x80]),
            hexBytes(holderHex),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.userAddress, equals(holderBech32));
      expect(results.single.tokenIdentifier, equals('SFT-123456'));
      expect(results.single.nonce, equals(BigInt.two));
      expect(results.single.balance, equals(BigInt.from(10000000)));
    });

    test('parseFreeze yields an empty account when the topic is missing', () {
      final List<FreezeResult> results = parser.parseFreeze(
        transactionWith(<TransactionEvent>[
          event('ESDTFreeze', <Uint8List>[
            text('AAA-29c4c9'),
            empty(),
            bytes(<int>[0x98, 0x96, 0x80]),
          ]),
        ]),
      );

      expect(results.single.userAddress, equals(''));
      expect(results.single.balance, equals(BigInt.from(10000000)));
    });
  });

  group('metadata outcomes', () {
    test('parseUpdateAttributes reports the new attribute bytes', () {
      final List<UpdateAttributesResult> results = parser.parseUpdateAttributes(
        transactionWith(<TransactionEvent>[
          event('ESDTNFTUpdateAttributes', <Uint8List>[
            text('NFT-f01d1e'),
            bytes(<int>[0x01]),
            empty(),
            text('metadata'),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('NFT-f01d1e'));
      expect(results.single.nonce, equals(BigInt.one));
      expect(utf8.decode(results.single.attributes), equals('metadata'));
    });

    test('parseUpdateAttributes yields empty attributes when unset', () {
      final List<UpdateAttributesResult> results = parser.parseUpdateAttributes(
        transactionWith(<TransactionEvent>[
          event('ESDTNFTUpdateAttributes', <Uint8List>[
            text('NFT-f01d1e'),
            bytes(<int>[0x01]),
            empty(),
            empty(),
          ]),
        ]),
      );

      expect(results.single.attributes, isEmpty);
    });

    test('parseModifyRoyalties reports the new royalties', () {
      final List<ModifyRoyaltiesResult> results = parser.parseModifyRoyalties(
        transactionWith(<TransactionEvent>[
          event('ESDTModifyRoyalties', <Uint8List>[
            text('TEST-123456'),
            bytes(<int>[0x01]),
            empty(),
            bytes(<int>[0x04, 0xd2]),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('TEST-123456'));
      expect(results.single.nonce, equals(BigInt.one));
      expect(results.single.royalties, equals(BigInt.from(1234)));
    });

    test('parseModifyRoyalties reports zero royalties for an empty topic', () {
      final List<ModifyRoyaltiesResult> results = parser.parseModifyRoyalties(
        transactionWith(<TransactionEvent>[
          event('ESDTModifyRoyalties', <Uint8List>[
            text('TEST-123456'),
            bytes(<int>[0x01]),
            empty(),
            empty(),
          ]),
        ]),
      );

      expect(results.single.royalties, equals(BigInt.zero));
    });

    test('parseSetNewUris reports every URI', () {
      final List<SetNewUrisResult> results = parser.parseSetNewUris(
        transactionWith(<TransactionEvent>[
          event('ESDTSetNewURIs', <Uint8List>[
            text('TEST-123456'),
            bytes(<int>[0x01]),
            empty(),
            text('firstURI'),
            text('secondURI'),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('TEST-123456'));
      expect(results.single.nonce, equals(BigInt.one));
      expect(results.single.uris, equals(<String>['firstURI', 'secondURI']));
    });

    test('parseModifyCreator reports the token and nonce', () {
      final List<ModifyCreatorResult> results = parser.parseModifyCreator(
        transactionWith(<TransactionEvent>[
          event('ESDTModifyCreator', <Uint8List>[
            text('TEST-123456'),
            bytes(<int>[0x01]),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('TEST-123456'));
      expect(results.single.nonce, equals(BigInt.one));
    });

    test('parseUpdateMetadata reports the new metadata bytes', () {
      final List<UpdateMetadataResult> results = parser.parseUpdateMetadata(
        transactionWith(<TransactionEvent>[
          event('ESDTMetaDataUpdate', <Uint8List>[
            text('TEST-123456'),
            bytes(<int>[0x01]),
            empty(),
            text('metadata'),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('TEST-123456'));
      expect(results.single.nonce, equals(BigInt.one));
      expect(utf8.decode(results.single.metadata), equals('metadata'));
    });

    test('parseMetadataRecreate reports the recreated metadata bytes', () {
      final List<MetadataRecreateResult> results = parser.parseMetadataRecreate(
        transactionWith(<TransactionEvent>[
          event('ESDTMetaDataRecreate', <Uint8List>[
            text('TEST-123456'),
            bytes(<int>[0x01]),
            empty(),
            text('metadata'),
          ]),
        ]),
      );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('TEST-123456'));
      expect(results.single.nonce, equals(BigInt.one));
      expect(utf8.decode(results.single.metadata), equals('metadata'));
    });
  });

  group('dynamic token outcomes', () {
    test('parseChangeTokenToDynamic reports name, ticker and type', () {
      final List<ChangeToDynamicResult> results = parser
          .parseChangeTokenToDynamic(
            transactionWith(<TransactionEvent>[
              event('changeToDynamic', <Uint8List>[
                text('NFT-f01d1e'),
                text('NFTEST'),
                text('NFT'),
                text('DynamicNonFungibleESDT'),
              ]),
            ]),
          );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('NFT-f01d1e'));
      expect(results.single.tokenName, equals('NFTEST'));
      expect(results.single.tickerName, equals('NFT'));
      expect(results.single.tokenType, equals('DynamicNonFungibleESDT'));
    });

    test('parseRegisterDynamicToken reports the decimal precision', () {
      final List<RegisterDynamicResult> results = parser
          .parseRegisterDynamicToken(
            transactionWith(<TransactionEvent>[
              event('registerDynamic', <Uint8List>[
                text('METATEST-e05d11'),
                text('METATEST'),
                text('META'),
                text('DynamicMetaESDT'),
                bytes(<int>[0x12]),
              ]),
            ]),
          );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('METATEST-e05d11'));
      expect(results.single.tokenName, equals('METATEST'));
      expect(results.single.tokenTicker, equals('META'));
      expect(results.single.tokenType, equals('DynamicMetaESDT'));
      expect(results.single.numOfDecimals, equals(18));
    });

    test('parseRegisterDynamicToken reports zero decimals when absent', () {
      final List<RegisterDynamicResult> results = parser
          .parseRegisterDynamicToken(
            transactionWith(<TransactionEvent>[
              event('registerDynamic', <Uint8List>[
                text('NFT-f01d1e'),
                text('NFTEST'),
                text('NFT'),
                text('DynamicNonFungibleESDT'),
              ]),
            ]),
          );

      expect(results.single.numOfDecimals, equals(0));
    });

    test('parseRegisterDynamicTokenAndSettingRoles decodes the same shape', () {
      final List<RegisterDynamicResult> results = parser
          .parseRegisterDynamicTokenAndSettingRoles(
            transactionWith(<TransactionEvent>[
              event('registerAndSetAllRolesDynamic', <Uint8List>[
                text('METATEST-e05d11'),
                text('METATEST'),
                text('META'),
                text('DynamicMetaESDT'),
                bytes(<int>[0x12]),
              ]),
            ]),
          );

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('METATEST-e05d11'));
      expect(results.single.tokenName, equals('METATEST'));
      expect(results.single.tokenTicker, equals('META'));
      expect(results.single.tokenType, equals('DynamicMetaESDT'));
      expect(results.single.numOfDecimals, equals(18));
    });

    test(
      'parseRegisterDynamicToken ignores the non-dynamic register event',
      () {
        final List<RegisterDynamicResult> results = parser
            .parseRegisterDynamicToken(
              transactionWith(<TransactionEvent>[
                event('registerAndSetAllRolesDynamic', <Uint8List>[
                  text('METATEST-e05d11'),
                ]),
              ]),
            );

        expect(results, isEmpty);
      },
    );
  });

  group('failure handling', () {
    test('a signalError event aborts parsing and names the reason', () {
      final TransactionOnNetwork failed = transactionWith(<TransactionEvent>[
        event(
          'signalError',
          <Uint8List>[hexBytes(holderHex), text('ticker name is not valid')],
          emitter: esdtContract,
          additionalData: <Uint8List>[text('@75736572206572726f72')],
        ),
      ]);

      expect(
        () => parser.parseIssueFungible(failed),
        throwsA(
          isA<TokenManagementParseException>().having(
            (TokenManagementParseException e) => e.message,
            'message',
            contains('ticker name is not valid'),
          ),
        ),
      );
    });

    test('a signalError aborts every parse method', () {
      final TransactionOnNetwork failed = transactionWith(<TransactionEvent>[
        event('signalError', <Uint8List>[
          hexBytes(holderHex),
          text('insufficient funds'),
        ]),
      ]);

      expect(
        () => parser.parseNftCreate(failed),
        throwsA(isA<TokenManagementParseException>()),
      );
      expect(
        () => parser.parseSetSpecialRole(failed),
        throwsA(isA<TokenManagementParseException>()),
      );
      expect(
        () => parser.parseFreeze(failed),
        throwsA(isA<TokenManagementParseException>()),
      );
      expect(
        () => parser.parseRegisterDynamicToken(failed),
        throwsA(isA<TokenManagementParseException>()),
      );
    });

    test('a transaction without logs cannot be parsed', () {
      final TransactionOnNetwork withoutLogs = TransactionOnNetwork(
        transaction: baseTransaction,
        status: TransactionStatus.success,
        txHash: '00' * 32,
      );

      expect(
        () => parser.parseIssueFungible(withoutLogs),
        throwsA(isA<TokenManagementParseException>()),
      );
    });

    test('an unrelated event yields no results', () {
      final List<IssueFungibleResult> results = parser.parseIssueFungible(
        transactionWith(<TransactionEvent>[
          event('completedTxEvent', <Uint8List>[text('AAA-29c4c9')]),
        ]),
      );

      expect(results, isEmpty);
    });
  });
}
