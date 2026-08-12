import '../../abi/smart_contract/query/query.dart';
import '../../core/account/account_on_network.dart';
import '../../core/address.dart';
import '../../core/token_on_network.dart';
import '../../core/transaction/chain_id.dart';
import '../../core/transaction/transaction.dart';
import '../../core/transaction/transaction_on_network.dart';
import '../../core/transaction/transaction_status.dart';
import 'account_storage.dart';
import 'account_storage_entry.dart';
import 'block_on_network.dart';
import 'guardian_data.dart';
import 'network_config.dart';
import 'network_economics.dart';
import 'network_status.dart';
import 'send_transactions_result.dart';

/// Network provider interface for interacting with MultiversX blockchain.
/// Implementations include `ApiNetworkProvider` and `GatewayNetworkProvider`.
///
/// #### Example
/// ```dart
/// // Using API provider
/// final provider = ApiNetworkProvider.devnet();
///
/// // Fetch account
/// final account = await provider.getAccount(address);
/// print('Balance: ${account.balance.toDenominatedTrimmed} EGLD');
///
/// // Send transaction
/// final txHash = await provider.sendTransaction(signedTx);
///
/// // Wait for completion
/// final watcher = TransactionWatcher(networkProvider: provider);
/// final tx = await watcher.awaitCompleted(txHash);
///
/// // Query smart contract
/// final query = SmartContractQuery.view(
///   contract: SmartContractAddress.fromBech32('erd1qqqqqq...'),
///   function: SmartContractFunction('getBalance'),
///   arguments: [arg1, arg2],
/// );
/// final response = await provider.queryContract(query);
///
/// // Cleanup
/// provider.close();
/// ```
abstract interface class NetworkProvider {
  /// Base URL for network provider.
  String get baseUrl;

  /// Chain ID.
  ChainId get chainId;

  /// Fetches network configuration.
  ///
  /// #### Returns
  /// `NetworkConfig` - Network configuration with gas costs and chain parameters
  ///
  /// #### Example
  /// ```dart
  /// final config = await provider.getNetworkConfig();
  /// print('Chain ID: ${config.chainId}');
  /// print('Min gas limit: ${config.minGasLimit}');
  /// print('Gas per data byte: ${config.gasPerDataByte}');
  /// ```
  Future<NetworkConfig> getNetworkConfig();

  /// Fetches network status for a given shard.
  ///
  /// #### Parameters
  /// - `shard` - Shard ID (0, 1, 2, or `4294967295` for the metachain;
  ///   defaults to the metachain, whose status covers the whole network).
  ///
  /// #### Returns
  /// `NetworkStatus` - Network status with current round, epoch, and nonce
  ///
  /// #### Example
  /// ```dart
  /// final meta = await provider.getNetworkStatus();
  /// final shard0 = await provider.getNetworkStatus(shard: 0);
  /// print('Shard 0 round: ${shard0.currentRound}');
  /// ```
  Future<NetworkStatus> getNetworkStatus({int shard});

  /// Fetches network economics data including supply, staking, and market info.
  ///
  /// #### Returns
  /// `NetworkEconomics` - Economics data with supply, staking, price, and APR
  ///
  /// #### Throws
  /// - `UnsupportedError` - If called on Gateway provider
  ///
  /// #### Example
  /// ```dart
  /// final economics = await provider.getNetworkEconomics();
  /// print('Total Supply: ${economics.totalSupply} EGLD');
  /// print('Staked: ${economics.staked} EGLD');
  /// print('Price: \$${economics.price}');
  /// print('APR: ${(economics.apr * 100).toStringAsFixed(2)}%');
  /// ```
  Future<NetworkEconomics> getNetworkEconomics();

  /// Fetches account state from blockchain.
  ///
  /// #### Parameters
  /// - `address` - Account address to query
  ///
  /// #### Returns
  /// `AccountOnNetwork` - Account state with balance, nonce, code, etc.
  ///
  /// #### Example
  /// ```dart
  /// final account = await provider.getAccount(myAddress);
  /// print('Balance: ${account.balance.toDenominatedTrimmed} EGLD');
  /// print('Nonce: ${account.nonce.value}');
  /// if (account.isContract) {
  ///   print('Smart contract account');
  /// }
  /// ```
  Future<AccountOnNetwork> getAccount(Address address);

  /// Fetches account storage.
  ///
  /// #### Parameters
  /// - `address` - Account address to query
  ///
  /// #### Returns
  /// `AccountStorage` - All key-value pairs in account storage
  Future<AccountStorage> getAccountStorage(Address address);

  /// Fetches specific storage entry.
  ///
  /// #### Parameters
  /// - `address` - Account address to query
  /// - `key` - Storage key to retrieve
  ///
  /// #### Returns
  /// `AccountStorageEntry` - Storage entry with key and value
  Future<AccountStorageEntry> getAccountStorageEntry(
    Address address,
    String key,
  );

  /// Broadcasts signed transaction to network.
  ///
  /// #### Parameters
  /// - `tx` - Signed transaction to broadcast
  ///
  /// #### Returns
  /// `String` - Transaction hash (ID on blockchain)
  ///
  /// #### Throws
  /// - `Exception` - If transaction rejected or network error
  ///
  /// #### Example
  /// ```dart
  /// // Sign transaction
  /// final signature = await account.signTransaction(tx);
  /// final signedTx = tx.copyWith(newSignature: Signature.fromUint8List(signature));
  ///
  /// // Send to network
  /// final txHash = await provider.sendTransaction(signedTx);
  /// print('Transaction hash: $txHash');
  ///
  /// // Wait for completion
  /// final watcher = TransactionWatcher(networkProvider: provider);
  /// final txOnNetwork = await watcher.awaitCompleted(txHash);
  /// ```
  Future<String> sendTransaction(Transaction tx);

  /// Broadcasts multiple signed transactions.
  ///
  /// #### Parameters
  /// - `txs` - List of signed transactions
  ///
  /// #### Returns
  /// `SendTransactionsResult` - Result with count sent and transaction hashes
  ///
  /// #### Example
  /// ```dart
  /// final result = await provider.sendTransactions([tx1, tx2, tx3]);
  /// print('Sent ${result.numSent} of ${result.txHashes.length} transactions');
  /// for (int i = 0; i < result.txHashes.length; i++) {
  ///   if (result.txHashes[i] != null) {
  ///     print('TX $i: ${result.txHashes[i]}');
  ///   }
  /// }
  /// ```
  Future<SendTransactionsResult> sendTransactions(List<Transaction> txs);

  /// Fetches transaction state from network.
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash to query
  /// - `withProcessStatus` - Include processing status and results (default: false)
  ///
  /// #### Returns
  /// `TransactionOnNetwork` - Transaction with status, block info, results, logs
  ///
  /// #### Example
  /// ```dart
  /// final tx = await provider.getTransaction(txHash, withProcessStatus: true);
  /// if (tx.isSuccessful) {
  ///   print('Success in block ${tx.blockNonce}');
  ///   if (tx.smartContractResults != null) {
  ///     for (final scr in tx.smartContractResults!) {
  ///       print('Result: ${scr}');
  ///     }
  ///   }
  /// }
  /// ```
  Future<TransactionOnNetwork> getTransaction(
    String txHash, {
    bool withProcessStatus = false,
  });

  /// Fetches transaction status.
  ///
  /// #### Parameters
  /// - `txHash` - Transaction hash to query
  ///
  /// #### Returns
  /// `TransactionStatus` - Transaction status with state
  Future<TransactionStatus> getTransactionStatus(String txHash);

  /// Simulates transaction processing.
  ///
  /// #### Parameters
  /// - `tx` - Transaction to simulate
  ///
  /// #### Returns
  /// `TransactionOnNetwork` - Simulated execution results
  Future<TransactionOnNetwork> simulateTransaction(Transaction tx);

  /// Estimates gas cost.
  ///
  /// #### Parameters
  /// - `tx` - Transaction to estimate
  ///
  /// #### Returns
  /// `Map<String, dynamic>` - Gas cost estimation
  Future<Map<String, dynamic>> estimateTransactionCost(Transaction tx);

  /// Executes smart contract query (view function).
  ///
  /// #### Parameters
  /// - `query` - Smart contract query with contract, function, and arguments
  ///
  /// #### Returns
  /// `SmartContractQueryResponse` - Query response with return data and status
  ///
  /// #### Throws
  /// - `Exception` - If query execution fails
  ///
  /// #### Example
  /// ```dart
  /// final query = SmartContractQuery.view(
  ///   contract: SmartContractAddress.fromBech32('erd1qqqqqq...'),
  ///   function: SmartContractFunction('getStakingBalance'),
  ///   arguments: [AddressValue.fromBech32('erd1user...')],
  /// );
  ///
  /// final response = await provider.queryContract(query);
  /// final balance = response.returnData[0] as BigUIntValue;
  /// print('Staked: ${balance.value}');
  /// ```
  Future<SmartContractQueryResponse> queryContract(SmartContractQuery query);

  /// Fetches token balance.
  ///
  /// #### Parameters
  /// - `address` - Account address to query
  /// - `tokenIdentifier` - Token identifier (e.g., 'USDC-abc123')
  ///
  /// #### Returns
  /// `TokenOnNetwork` - Token balance and metadata
  Future<TokenOnNetwork> getTokenOfAccount(
    Address address,
    String tokenIdentifier,
  );

  /// Fetches all fungible tokens.
  ///
  /// #### Parameters
  /// - `address` - Account address to query
  /// - `from` - Optional pagination offset; `null` lets the server pick the default.
  /// - `size` - Optional page size; `null` lets the server pick the default.
  ///
  /// #### Returns
  /// `List<TokenOnNetwork>` - All fungible tokens owned by account
  Future<List<TokenOnNetwork>> getFungibleTokensOfAccount(
    Address address, {
    int? from,
    int? size,
  });

  /// Fetches all non-fungible tokens.
  ///
  /// #### Parameters
  /// - `address` - Account address to query
  /// - `from` - Optional pagination offset; `null` lets the server pick the default.
  /// - `size` - Optional page size; `null` lets the server pick the default.
  ///
  /// #### Returns
  /// `List<TokenOnNetwork>` - All NFTs owned by account
  Future<List<TokenOnNetwork>> getNonFungibleTokensOfAccount(
    Address address, {
    int? from,
    int? size,
  });

  /// Fetches the guardian data for an account.
  ///
  /// Calls `/accounts/{bech32}/guardian-data` on the API and
  /// `/address/{bech32}/guardian-data` on the Gateway.
  ///
  /// #### Parameters
  /// - `address` - Account address to query.
  ///
  /// #### Returns
  /// `GuardianData` - `guarded` flag plus optional active / pending guardians.
  Future<GuardianData> getGuardianData(Address address);

  /// Fetches on-chain definition of a fungible ESDT.
  ///
  /// Returns metadata such as name, ticker, decimals, supply, and capability
  /// flags (`canMint`, `canBurn`, `canPause`, ...). The result is balance-less
  /// — this is token-level data, not account-bound.
  ///
  /// #### Parameters
  /// - `identifier` - Token identifier (e.g., `WEGLD-bd4d79`)
  ///
  /// #### Returns
  /// `TokenOnNetwork` - Token definition with metadata and capabilities
  ///
  /// #### Throws
  /// - `UnsupportedError` - If called on a provider that does not index token metadata
  /// - `NetworkException` - If the token does not exist or the request fails
  ///
  /// #### Example
  /// ```dart
  /// final token = await provider.getDefinitionOfFungibleToken('WEGLD-bd4d79');
  /// print('${token.name} (${token.ticker}) — ${token.decimals} decimals');
  /// print('Supply: ${token.supply}');
  /// ```
  Future<TokenOnNetwork> getDefinitionOfFungibleToken(String identifier);

  /// Fetches on-chain definition of an NFT/SFT/MetaESDT collection.
  ///
  /// Returns collection-level metadata (name, ticker, type, capabilities).
  /// Individual NFT instances are retrieved via [getNonFungibleToken].
  ///
  /// #### Parameters
  /// - `collection` - Collection identifier (e.g., `EROBOT-527a29`)
  ///
  /// #### Returns
  /// `TokenOnNetwork` - Collection definition with metadata and capabilities
  ///
  /// #### Throws
  /// - `UnsupportedError` - If called on a provider that does not index collections
  /// - `NetworkException` - If the collection does not exist
  ///
  /// #### Example
  /// ```dart
  /// final collection = await provider.getDefinitionOfTokenCollection('EROBOT-527a29');
  /// print('Type: ${collection.type}');  // NonFungibleESDT, SemiFungibleESDT, MetaESDT
  /// ```
  Future<TokenOnNetwork> getDefinitionOfTokenCollection(String collection);

  /// Fetches a specific NFT / SFT / MetaESDT instance.
  ///
  /// Returns instance-level fields (nonce, attributes, URIs, royalties, metadata)
  /// in addition to collection metadata.
  ///
  /// #### Parameters
  /// - `collection` - Collection identifier (e.g., `EROBOT-527a29`)
  /// - `nonce` - Positive instance nonce
  ///
  /// #### Returns
  /// `TokenOnNetwork` - NFT instance with full metadata
  ///
  /// #### Throws
  /// - `UnsupportedError` - If called on a provider that does not index NFTs
  /// - `NetworkException` - If the instance does not exist
  ///
  /// #### Example
  /// ```dart
  /// final nft = await provider.getNonFungibleToken('EROBOT-527a29', 42);
  /// print('Name: ${nft.name}');
  /// print('URIs: ${nft.uris}');
  /// print('Royalties: ${nft.royalties}');
  /// ```
  Future<TokenOnNetwork> getNonFungibleToken(String collection, int nonce);

  /// Fetches block metadata by hash.
  ///
  /// #### Parameters
  /// - `hash` - Block hash (hex)
  /// - `shard` - Shard ID owning the block (0, 1, 2, or `4294967295` for the
  ///   metachain). Required by the Gateway URL scheme
  ///   (`block/{shard}/by-hash/{hash}`); ignored by the API provider, which
  ///   indexes blocks globally by hash. Defaults to the metachain.
  ///
  /// #### Returns
  /// `BlockOnNetwork` - Block metadata including round, epoch, shard, nonce, prevHash
  ///
  /// #### Throws
  /// - `NetworkException` - If block is not found
  Future<BlockOnNetwork> getBlock(String hash, {int shard});

  /// Fetches the most recently observed block for the given shard.
  ///
  /// #### Parameters
  /// - `shard` - Shard ID (0, 1, 2, or `4294967295` for metachain; defaults to metachain)
  ///
  /// #### Returns
  /// `BlockOnNetwork` - Latest block for the shard
  Future<BlockOnNetwork> getLatestBlock({int shard});

  /// Fetches a hyperblock (cross-shard finalized block) by nonce.
  ///
  /// A hyperblock aggregates the latest metablock and all shard miniblocks,
  /// representing a fully finalized snapshot across shards.
  ///
  /// #### Parameters
  /// - `nonce` - Hyperblock nonce
  ///
  /// #### Returns
  /// `HyperblockOnNetwork` - Hyperblock with nonce, hash, shard blocks, and included transactions
  ///
  /// #### Throws
  /// - `UnsupportedError` - If called on a provider that does not expose hyperblocks
  /// - `NetworkException` - If the hyperblock does not exist
  Future<HyperblockOnNetwork> getHyperblock(int nonce);

  /// Performs generic GET request.
  ///
  /// #### Parameters
  /// - `resourceUrl` - Resource endpoint path
  ///
  /// #### Returns
  /// `dynamic` - Raw response data
  Future<dynamic> doGetGeneric(String resourceUrl);

  /// Performs generic POST request.
  ///
  /// #### Parameters
  /// - `resourceUrl` - Resource endpoint path
  /// - `payload` - Request body data
  ///
  /// #### Returns
  /// `dynamic` - Raw response data
  Future<dynamic> doPostGeneric(String resourceUrl, dynamic payload);

  /// Closes provider and releases resources.
  void close();
}
