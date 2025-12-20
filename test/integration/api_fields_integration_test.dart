import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  late ApiNetworkProvider mainnetProvider;
  late ApiNetworkProvider devnetProvider;

  setUp(() {
    mainnetProvider = ApiNetworkProvider.mainnet();
    devnetProvider = ApiNetworkProvider.devnet();
  });

  group('NetworkConfig API Fields', () {
    test('should fetch all network config fields from mainnet', () async {
      final config = await mainnetProvider.getNetworkConfig();

      expect(config.chainId, equals('1'));
      expect(config.minGasPrice, greaterThan(0));
      expect(config.minGasLimit, greaterThan(0));
      expect(config.gasPerDataByte, greaterThan(0));
      expect(config.minTransactionVersion, greaterThanOrEqualTo(1));
      expect(config.numShards, greaterThan(0));
      expect(config.roundDuration, greaterThan(0));
      expect(config.roundsPerEpoch, greaterThan(0));
      expect(config.topUpFactor, isA<double>());
      expect(config.topUpFactor, greaterThan(0));

      expect(config.denomination, equals(18));
      expect(config.gasPriceModifier, isA<String>());
      expect(config.adaptivity, isA<bool>());
      expect(config.hysteresis, isA<String>());
    });

    test('should fetch all network config fields from devnet', () async {
      final config = await devnetProvider.getNetworkConfig();

      expect(config.chainId, equals('D'));
      expect(config.minGasPrice, greaterThan(0));
      expect(config.denomination, equals(18));
      expect(config.gasPriceModifier, isA<String>());
    });

    test('should have optional fields available when present', () async {
      final config = await mainnetProvider.getNetworkConfig();

      if (config.latestTagSoftwareVersion != null) {
        expect(config.latestTagSoftwareVersion, isNotEmpty);
      }
      if (config.metaConsensusGroupSize != null) {
        expect(config.metaConsensusGroupSize, greaterThan(0));
      }
      if (config.numMetachainNodes != null) {
        expect(config.numMetachainNodes, greaterThan(0));
      }
      if (config.numNodesInShard != null) {
        expect(config.numNodesInShard, greaterThan(0));
      }
      if (config.shardConsensusGroupSize != null) {
        expect(config.shardConsensusGroupSize, greaterThan(0));
      }
      if (config.startTime != null) {
        expect(config.startTime, greaterThan(0));
      }
    });
  });

  group('NetworkStatus API Fields', () {
    test('should fetch all network status fields', () async {
      final status = await mainnetProvider.getNetworkStatus();

      expect(status.currentRound, greaterThan(0));
      expect(status.epochNumber, greaterThan(0));
      expect(status.highestFinalNonce, greaterThan(0));
      expect(status.nonce, greaterThan(0));
      expect(status.nonceAtEpochStart, greaterThan(0));
      expect(status.noncesPassedInCurrentEpoch, greaterThanOrEqualTo(0));
      expect(status.roundAtEpochStart, greaterThan(0));
      expect(status.roundsPassedInCurrentEpoch, greaterThanOrEqualTo(0));
      expect(status.roundsPerEpoch, greaterThan(0));
    });
  });

  group('NetworkEconomics API Fields', () {
    test('should fetch all economics fields from mainnet', () async {
      final economics = await mainnetProvider.getNetworkEconomics();

      // Supply fields
      expect(economics.totalSupply, greaterThan(0));
      expect(economics.circulatingSupply, greaterThan(0));
      expect(economics.staked, greaterThan(0));

      // Market data
      expect(economics.price, greaterThan(0));
      expect(economics.marketCap, greaterThan(0));
      expect(economics.tokenMarketCap, greaterThanOrEqualTo(0));

      // APR fields
      expect(economics.apr, greaterThan(0));
      expect(economics.topUpApr, greaterThanOrEqualTo(0));
      expect(economics.baseApr, greaterThan(0));
    });

    test('should fetch economics from devnet', () async {
      final economics = await devnetProvider.getNetworkEconomics();

      // Supply fields
      expect(economics.totalSupply, greaterThan(0));
      expect(economics.circulatingSupply, greaterThan(0));

      // APR fields
      expect(economics.apr, greaterThanOrEqualTo(0));
    });

    test('gateway should throw UnsupportedError for economics', () async {
      final gateway = GatewayNetworkProvider.mainnet();
      try {
        expect(
          () => gateway.getNetworkEconomics(),
          throwsA(isA<UnsupportedError>()),
        );
      } finally {
        gateway.close();
      }
    });
  });

  group('AccountOnNetwork API Fields', () {
    const mainnetAccount =
        'erd1qqqqqqqqqqqqqpgqd77fnev2sthnczp2lnfx0y5jdycynjfhzzgq6p3rax';

    test('should fetch all account fields from mainnet', () async {
      final account = await mainnetProvider.getAccount(
        Address.fromBech32(mainnetAccount),
      );

      expect(account.address.bech32, equals(mainnetAccount));
      expect(account.balance.value, greaterThanOrEqualTo(BigInt.zero));
      expect(account.nonce.value, greaterThanOrEqualTo(0));

      expect(account.shard, greaterThanOrEqualTo(0));
      if (account.txCount != null) {
        expect(account.txCount, greaterThanOrEqualTo(0));
      }
      if (account.scrCount != null) {
        expect(account.scrCount, greaterThanOrEqualTo(0));
      }
    });

    test('should fetch smart contract account fields', () async {
      final contract = await mainnetProvider.getAccount(
        Address.fromBech32(mainnetAccount),
      );

      expect(contract.address.isSmartContract, isTrue);
      if (contract.ownerAddress != null) {
        expect(contract.ownerAddress, isNotEmpty);
      }
      if (contract.deployedAt != null) {
        expect(contract.deployedAt, greaterThan(0));
      }
    });

    test('should have assets when available', () async {
      final account = await mainnetProvider.getAccount(
        Address.fromBech32(mainnetAccount),
      );

      expect(account.assets, isA<Map<String, dynamic>?>());
    });
  });

  group('TransactionOnNetwork API Fields', () {
    const mainnetTxHashWithScResults =
        '105def9ba05e976de15c90048e4bdf36b7eed034372bc0805cbfd893562541f5';

    test('should fetch transaction with all basic fields', () async {
      final tx = await mainnetProvider.getTransaction(
        mainnetTxHashWithScResults,
      );

      expect(tx.txHash, equals(mainnetTxHashWithScResults));
      expect(tx.transaction.sender.bech32, isNotEmpty);
      expect(tx.transaction.receiver.bech32, isNotEmpty);
      expect(tx.transaction.value.value, greaterThanOrEqualTo(BigInt.zero));
      expect(tx.transaction.nonce.value, greaterThanOrEqualTo(0));
      expect(tx.transaction.gasLimit.value, greaterThan(0));
      expect(tx.transaction.gasPrice.value, greaterThan(0));
      expect(tx.gasUsed, greaterThanOrEqualTo(0));
      expect(tx.status, isA<TransactionStatus>());
    });

    test('should have timestamp fields', () async {
      final tx = await mainnetProvider.getTransaction(
        mainnetTxHashWithScResults,
      );

      expect(tx.timestamp, greaterThan(0));
      if (tx.completedAt != null) {
        expect(tx.completedAt, greaterThan(0));
      }
    });

    test('should have fee fields', () async {
      final tx = await mainnetProvider.getTransaction(
        mainnetTxHashWithScResults,
      );

      expect(tx.fee, isNotEmpty);
      if (tx.initiallyPaidFee != null) {
        expect(tx.initiallyPaidFee, isNotEmpty);
      }
    });

    test('should have shard information', () async {
      final tx = await mainnetProvider.getTransaction(
        mainnetTxHashWithScResults,
      );

      expect(tx.senderShard, greaterThanOrEqualTo(0));
      expect(tx.receiverShard, greaterThanOrEqualTo(0));
    });

    test('should have hyperblock info when available', () async {
      final tx = await mainnetProvider.getTransaction(
        mainnetTxHashWithScResults,
      );

      if (tx.hyperblockNonce != null) {
        expect(tx.hyperblockNonce, greaterThan(0));
      }
      if (tx.hyperblockHash != null) {
        expect(tx.hyperblockHash, isNotEmpty);
      }
    });

    test('should have smart contract results when present', () async {
      final tx = await mainnetProvider.getTransaction(
        mainnetTxHashWithScResults,
      );

      expect(tx.smartContractResults, isA<List<Map<String, dynamic>>?>());
      if (tx.smartContractResults != null &&
          tx.smartContractResults!.isNotEmpty) {
        final scr = tx.smartContractResults!.first;
        expect(scr['hash'], isNotEmpty);
        expect(scr['sender'], isNotEmpty);
        expect(scr['receiver'], isNotEmpty);
      }
    });

    test('should have logs when present', () async {
      final tx = await mainnetProvider.getTransaction(
        mainnetTxHashWithScResults,
      );

      expect(tx.logs, isA<TransactionLogs?>());
      if (tx.logs != null && tx.logs!.events.isNotEmpty) {
        final event = tx.logs!.events.first;
        expect(event.identifier, isNotEmpty);
        expect(event.address.bech32, isNotEmpty);
        expect(event.order, greaterThanOrEqualTo(0));
      }
    });

    test('should have action when available', () async {
      final tx = await mainnetProvider.getTransaction(
        mainnetTxHashWithScResults,
      );

      if (tx.action != null) {
        expect(tx.action, isA<Map<String, dynamic>>());
        expect(tx.action!['category'], isA<String?>());
        expect(tx.action!['name'], isA<String?>());
      }
    });

    test('should have operations when available', () async {
      final tx = await mainnetProvider.getTransaction(
        mainnetTxHashWithScResults,
      );

      if (tx.operations != null && tx.operations!.isNotEmpty) {
        final op = tx.operations!.first;
        expect(op, isA<Map<String, dynamic>>());
      }
    });
  });

  group('TransactionEvent API Fields', () {
    const mainnetTxWithEvents =
        '105def9ba05e976de15c90048e4bdf36b7eed034372bc0805cbfd893562541f5';

    test('should have event order field', () async {
      final tx = await mainnetProvider.getTransaction(mainnetTxWithEvents);

      if (tx.logs != null && tx.logs!.events.isNotEmpty) {
        for (final event in tx.logs!.events) {
          expect(event.order, greaterThanOrEqualTo(0));
        }
      }
    });

    test('should have addressAssets when available', () async {
      final tx = await mainnetProvider.getTransaction(mainnetTxWithEvents);

      if (tx.logs != null && tx.logs!.events.isNotEmpty) {
        final event = tx.logs!.events.first;
        expect(event.addressAssets, isA<Map<String, dynamic>?>());
      }
    });

    test('should have all event fields', () async {
      final tx = await mainnetProvider.getTransaction(mainnetTxWithEvents);

      if (tx.logs != null && tx.logs!.events.isNotEmpty) {
        final event = tx.logs!.events.first;
        expect(event.address.bech32, isNotEmpty);
        expect(event.identifier, isNotEmpty);
        expect(event.topics, isA<List<Uint8List>>());
        expect(event.order, isA<int>());
      }
    });
  });

  group('TokenOnNetwork API Fields', () {
    const mainnetAccountWithTokens =
        'erd1qqqqqqqqqqqqqpgqd77fnev2sthnczp2lnfx0y5jdycynjfhzzgq6p3rax';

    test('should fetch fungible tokens with all fields', () async {
      final tokens = await mainnetProvider.getFungibleTokensOfAccount(
        Address.fromBech32(mainnetAccountWithTokens),
      );

      if (tokens.isNotEmpty) {
        final token = tokens.first;
        expect(token.identifier, isNotEmpty);
        expect(token.balance, isNotEmpty);
        expect(token.decimals, greaterThanOrEqualTo(0));
        expect(token.type, isNotNull);
      }
    });

    test('should have token metadata fields', () async {
      final tokens = await mainnetProvider.getFungibleTokensOfAccount(
        Address.fromBech32(mainnetAccountWithTokens),
      );

      if (tokens.isNotEmpty) {
        final token = tokens.first;
        expect(token.name, isA<String?>());
        expect(token.ticker, isA<String?>());
        expect(token.owner, isA<String?>());
      }
    });

    test('should have token permission fields', () async {
      final tokens = await mainnetProvider.getFungibleTokensOfAccount(
        Address.fromBech32(mainnetAccountWithTokens),
      );

      if (tokens.isNotEmpty) {
        final token = tokens.first;
        expect(token.canBurn, isA<bool?>());
        expect(token.canMint, isA<bool?>());
        expect(token.canPause, isA<bool?>());
        expect(token.canFreeze, isA<bool?>());
        expect(token.canWipe, isA<bool?>());
        expect(token.canUpgrade, isA<bool?>());
        expect(token.canChangeOwner, isA<bool?>());
        expect(token.canAddSpecialRoles, isA<bool?>());
        expect(token.canTransferNftCreateRole, isA<bool?>());
      }
    });

    test('should have supply fields when available', () async {
      final tokens = await mainnetProvider.getFungibleTokensOfAccount(
        Address.fromBech32(mainnetAccountWithTokens),
      );

      if (tokens.isNotEmpty) {
        final token = tokens.first;
        expect(token.supply, isA<String?>());
        expect(token.circulatingSupply, isA<String?>());
        expect(token.minted, isA<String?>());
        expect(token.burnt, isA<String?>());
        expect(token.initialMinted, isA<String?>());
      }
    });

    test('should have price fields when available', () async {
      final tokens = await mainnetProvider.getFungibleTokensOfAccount(
        Address.fromBech32(mainnetAccountWithTokens),
      );

      if (tokens.isNotEmpty) {
        final token = tokens.first;
        expect(token.price, isA<double?>());
        expect(token.marketCap, isA<double?>());
        expect(token.valueUsd, isA<double?>());
      }
    });
  });

  group('Gateway Provider - NetworkConfig Fields', () {
    late GatewayNetworkProvider gatewayMainnet;
    late GatewayNetworkProvider gatewayDevnet;

    setUp(() {
      gatewayMainnet = GatewayNetworkProvider.mainnet();
      gatewayDevnet = GatewayNetworkProvider.devnet();
    });

    test(
      'should fetch all network config fields from mainnet gateway',
      () async {
        final config = await gatewayMainnet.getNetworkConfig();

        expect(config.chainId, equals('1'));
        expect(config.minGasPrice, greaterThan(0));
        expect(config.minGasLimit, greaterThan(0));
        expect(config.gasPerDataByte, greaterThan(0));
        expect(config.minTransactionVersion, greaterThanOrEqualTo(1));
        expect(config.numShards, greaterThan(0));
        expect(config.roundDuration, greaterThan(0));
        expect(config.roundsPerEpoch, greaterThan(0));
        expect(config.topUpFactor, isA<double>());
        expect(config.topUpFactor, greaterThan(0));
        expect(config.denomination, equals(18));
        expect(config.gasPriceModifier, isA<String>());
      },
    );

    test(
      'should fetch all network config fields from devnet gateway',
      () async {
        final config = await gatewayDevnet.getNetworkConfig();

        expect(config.chainId, equals('D'));
        expect(config.minGasPrice, greaterThan(0));
        expect(config.denomination, equals(18));
      },
    );
  });

  group('Gateway Provider - NetworkStatus Fields', () {
    late GatewayNetworkProvider gatewayMainnet;

    setUp(() {
      gatewayMainnet = GatewayNetworkProvider.mainnet();
    });

    test('should fetch all network status fields from gateway', () async {
      final status = await gatewayMainnet.getNetworkStatus();

      expect(status.currentRound, greaterThan(0));
      expect(status.epochNumber, greaterThan(0));
      expect(status.highestFinalNonce, greaterThan(0));
      expect(status.nonce, greaterThan(0));
      expect(status.nonceAtEpochStart, greaterThan(0));
      expect(status.noncesPassedInCurrentEpoch, greaterThanOrEqualTo(0));
      expect(status.roundAtEpochStart, greaterThan(0));
      expect(status.roundsPassedInCurrentEpoch, greaterThanOrEqualTo(0));
      expect(status.roundsPerEpoch, greaterThan(0));
    });
  });

  group('Gateway Provider - AccountOnNetwork Fields', () {
    late GatewayNetworkProvider gatewayMainnet;
    const mainnetAccount =
        'erd1qqqqqqqqqqqqqpgqd77fnev2sthnczp2lnfx0y5jdycynjfhzzgq6p3rax';

    setUp(() {
      gatewayMainnet = GatewayNetworkProvider.mainnet();
    });

    test('should fetch all account fields from gateway', () async {
      final account = await gatewayMainnet.getAccount(
        Address.fromBech32(mainnetAccount),
      );

      expect(account.address.bech32, equals(mainnetAccount));
      expect(account.balance.value, greaterThanOrEqualTo(BigInt.zero));
      expect(account.nonce.value, greaterThanOrEqualTo(0));
    });

    test('should fetch smart contract account fields from gateway', () async {
      final contract = await gatewayMainnet.getAccount(
        Address.fromBech32(mainnetAccount),
      );

      expect(contract.address.isSmartContract, isTrue);
      if (contract.ownerAddress != null) {
        expect(contract.ownerAddress, isNotEmpty);
      }
    });
  });

  group('Gateway Provider - TransactionOnNetwork Fields', () {
    late GatewayNetworkProvider gatewayMainnet;
    const mainnetTxHash =
        '105def9ba05e976de15c90048e4bdf36b7eed034372bc0805cbfd893562541f5';

    setUp(() {
      gatewayMainnet = GatewayNetworkProvider.mainnet();
    });

    test(
      'should fetch transaction with all basic fields from gateway',
      () async {
        final tx = await gatewayMainnet.getTransaction(mainnetTxHash);

        expect(tx.txHash, equals(mainnetTxHash));
        expect(tx.transaction.sender.bech32, isNotEmpty);
        expect(tx.transaction.receiver.bech32, isNotEmpty);
        expect(tx.transaction.value.value, greaterThanOrEqualTo(BigInt.zero));
        expect(tx.transaction.nonce.value, greaterThanOrEqualTo(0));
        expect(tx.transaction.gasLimit.value, greaterThan(0));
        expect(tx.transaction.gasPrice.value, greaterThan(0));
        expect(tx.status, isA<TransactionStatus>());
      },
    );

    test('should have timestamp fields from gateway', () async {
      final tx = await gatewayMainnet.getTransaction(mainnetTxHash);

      expect(tx.timestamp, greaterThan(0));
    });

    test('should have shard information from gateway', () async {
      final tx = await gatewayMainnet.getTransaction(mainnetTxHash);

      if (tx.senderShard != null) {
        expect(tx.senderShard, greaterThanOrEqualTo(0));
      }
      if (tx.receiverShard != null) {
        expect(tx.receiverShard, greaterThanOrEqualTo(0));
      }
    });

    test('should have hyperblock info from gateway', () async {
      final tx = await gatewayMainnet.getTransaction(mainnetTxHash);

      if (tx.hyperblockNonce != null) {
        expect(tx.hyperblockNonce, greaterThan(0));
      }
      if (tx.hyperblockHash != null) {
        expect(tx.hyperblockHash, isNotEmpty);
      }
    });

    test(
      'should have smart contract results from gateway when present',
      () async {
        final tx = await gatewayMainnet.getTransaction(mainnetTxHash);

        expect(tx.smartContractResults, isA<List<Map<String, dynamic>>?>());
        if (tx.smartContractResults != null &&
            tx.smartContractResults!.isNotEmpty) {
          final scr = tx.smartContractResults!.first;
          expect(scr['hash'], isNotEmpty);
        }
      },
    );

    test('should have logs from gateway when present', () async {
      final tx = await gatewayMainnet.getTransaction(mainnetTxHash);

      expect(tx.logs, isA<TransactionLogs?>());
      if (tx.logs != null && tx.logs!.events.isNotEmpty) {
        final event = tx.logs!.events.first;
        expect(event.identifier, isNotEmpty);
        expect(event.address.bech32, isNotEmpty);
        expect(event.order, greaterThanOrEqualTo(0));
      }
    });
  });

  group('Gateway Provider - TransactionEvent Fields', () {
    late GatewayNetworkProvider gatewayMainnet;
    const mainnetTxWithEvents =
        '105def9ba05e976de15c90048e4bdf36b7eed034372bc0805cbfd893562541f5';

    setUp(() {
      gatewayMainnet = GatewayNetworkProvider.mainnet();
    });

    test('should have event order field from gateway', () async {
      final tx = await gatewayMainnet.getTransaction(mainnetTxWithEvents);

      if (tx.logs != null && tx.logs!.events.isNotEmpty) {
        for (final event in tx.logs!.events) {
          expect(event.order, greaterThanOrEqualTo(0));
        }
      }
    });

    test('should have all event fields from gateway', () async {
      final tx = await gatewayMainnet.getTransaction(mainnetTxWithEvents);

      if (tx.logs != null && tx.logs!.events.isNotEmpty) {
        final event = tx.logs!.events.first;
        expect(event.address.bech32, isNotEmpty);
        expect(event.identifier, isNotEmpty);
        expect(event.topics, isA<List<Uint8List>>());
        expect(event.order, isA<int>());
      }
    });
  });

  group('Gateway Provider - TokenOnNetwork Fields', () {
    late GatewayNetworkProvider gatewayMainnet;
    const mainnetAccountWithTokens =
        'erd1qqqqqqqqqqqqqpgqd77fnev2sthnczp2lnfx0y5jdycynjfhzzgq6p3rax';

    setUp(() {
      gatewayMainnet = GatewayNetworkProvider.mainnet();
    });

    test('should fetch fungible tokens from gateway', () async {
      final tokens = await gatewayMainnet.getFungibleTokensOfAccount(
        Address.fromBech32(mainnetAccountWithTokens),
      );

      if (tokens.isNotEmpty) {
        final token = tokens.first;
        expect(token.identifier, isNotEmpty);
        expect(token.balance, isNotEmpty);
      }
    });

    test('should fetch specific token from gateway', () async {
      final tokens = await gatewayMainnet.getFungibleTokensOfAccount(
        Address.fromBech32(mainnetAccountWithTokens),
      );

      if (tokens.isNotEmpty) {
        final tokenId = tokens.first.identifier;
        final token = await gatewayMainnet.getTokenOfAccount(
          Address.fromBech32(mainnetAccountWithTokens),
          tokenId,
        );

        expect(token.identifier, equals(tokenId));
        expect(token.balance, isNotEmpty);
      }
    });
  });
}
