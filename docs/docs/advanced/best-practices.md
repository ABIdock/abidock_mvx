---
id: best-practices
title: Best Practices
sidebar_position: 3
description: Recommended patterns for wallet security, error handling, and performance in MultiversX applications.
---

# Best Practices

Recommended patterns for MultiversX applications.

## Wallet Security

### Never Hardcode Keys

```dart
// DON'T DO THIS
final mnemonic = 'abandon abandon abandon...';

// DO THIS
final mnemonic = Platform.environment['MVX_MNEMONIC'];
// Or load from secure storage
final mnemonic = await SecureStorage.read('wallet_mnemonic');
```

### Clear Sensitive Data

```dart
class SecureAccount {
  late final Account _account;
  bool _disposed = false;
  
  Future<void> init(String mnemonic) async {
    _account = await Account.fromMnemonic(mnemonic);
    // Clear mnemonic from memory after use
  }
  
  void dispose() {
    _disposed = true;
    // In production, zero out memory
  }
  
  void _checkDisposed() {
    if (_disposed) {
      throw StateError('Account has been disposed');
    }
  }
  
  Future<Transaction> sign(Transaction tx) async {
    _checkDisposed();
    final signature = await _account.signTransaction(tx);
    return tx.copyWith(newSignature: Signature.fromUint8List(signature));
  }
}
```

### Use Hardware Wallets for Production

```dart
// For high-value operations, integrate with Ledger
class LedgerSigner implements TransactionSigner {
  @override
  Future<String> sign(Transaction tx) async {
    // Send to Ledger for signing
    // User confirms on device
    throw UnimplementedError('Use @ledgerhq/hw-transport-webusb');
  }
}
```

## Transaction Safety

### Always Verify Before Sending

```dart
class TransactionValidator {
  static void validate(Transaction tx, AccountOnNetwork account) {
    // Check nonce (manual validation)
    if (tx.nonce != account.nonce) {
      throw ValidationException(
        'Nonce mismatch',
        parameterName: 'nonce',
        invalidValue: tx.nonce.value,
        constraint: 'expected: ${account.nonce.value}',
      );
    }
    
    // Check balance (manual validation)
    final totalCost = tx.value.value + 
      tx.gasLimit.toBigInt * tx.gasPrice.toBigInt;
    
    if (account.balance.value < totalCost) {
      throw ValidationException(
        'Insufficient balance',
        parameterName: 'balance',
        invalidValue: account.balance.value,
        constraint: 'required: $totalCost',
      );
    }
    
    // Check gas
    if (tx.gasLimit < GasLimit(50000)) {
      throw ValidationException(
        'Gas limit too low',
        parameterName: 'gasLimit',
        invalidValue: tx.gasLimit.value,
        constraint: 'must be >= 50000',
      );
    }
    
    // Check receiver
    if (tx.receiver.bech32.isEmpty) {
      throw ValidationException(
        'Receiver address is empty',
        parameterName: 'receiver',
        invalidValue: tx.receiver.bech32,
        constraint: 'must not be empty',
      );
    }
  }
}
```

### Use Transaction Simulation

```dart
/// Simulate before sending to catch errors
Future<void> simulateTransaction(
  GatewayNetworkProvider provider,
  Transaction tx,
) async {
  try {
    // Use VM query to simulate
    final result = await provider.simulateTransaction(tx);
    
    if (!result.isSuccessful) {
      // Check logs for error reason
      String reason = 'Unknown failure';
      if (result.logs != null) {
        for (final event in result.logs!.events) {
          if (event.identifier == 'signalError') {
            reason = event.topics.toString();
          }
        }
      }
      throw GasEstimationException(
        'Simulation failed: $reason',
      );
    }
    
    print('Simulation passed!');
  } on GasEstimationException catch (e) {
    print('Simulation failed: ${e.message}');
    print('Transaction may fail on-chain');
    rethrow;
  } on NetworkException catch (e) {
    print('Network error during simulation: ${e.message}');
    rethrow;
  }
}
```

### Nonce Management

```dart
/// Thread-safe nonce manager
class NonceManager {
  final GatewayNetworkProvider _provider;
  final Map<String, int> _localNonces = {};
  
  NonceManager(this._provider);
  
  Future<Nonce> getNextNonce(Address address) async {
    final key = address.bech32;
    
    // Get fresh nonce from network
    final account = await _provider.getAccount(address);
    final networkNonce = account.nonce.value;
    
    // Use higher of network or local
    final localNonce = _localNonces[key] ?? 0;
    final nextNonce = networkNonce > localNonce ? networkNonce : localNonce;
    
    // Increment local tracker
    _localNonces[key] = nextNonce + 1;
    
    return Nonce(nextNonce);
  }
  
  void reset(Address address) {
    _localNonces.remove(address.bech32);
  }
}
```

## Network Resilience

### Multiple Providers

```dart
class ResilientProvider {
  final List<GatewayNetworkProvider> _providers;
  int _currentIndex = 0;
  
  ResilientProvider(this._providers);
  
  factory ResilientProvider.mainnet() => ResilientProvider([
    GatewayNetworkProvider(
      baseUrl: 'https://gateway.multiversx.com',
      chainId: ChainId('1'),
    ),
    GatewayNetworkProvider(
      baseUrl: 'https://gateway-backup.example.com',
      chainId: ChainId('1'),
    ),
  ]);
  
  Future<T> execute<T>(
    Future<T> Function(GatewayNetworkProvider) operation,
  ) async {
    var lastError;
    
    for (var i = 0; i < _providers.length; i++) {
      final index = (_currentIndex + i) % _providers.length;
      
      try {
        final result = await operation(_providers[index]);
        _currentIndex = index; // Remember successful provider
        return result;
      } catch (e) {
        lastError = e;
        print('Provider $index failed: $e');
      }
    }
    
    throw lastError ?? StateError('All providers failed');
  }
}
```

### Rate Limiting

```dart
class RateLimitedProvider {
  final GatewayNetworkProvider _provider;
  final _queue = <_QueuedRequest>[];
  final int _requestsPerSecond;
  DateTime _lastRequest = DateTime.now();
  
  RateLimitedProvider(
    this._provider, {
    int requestsPerSecond = 10,
  }) : _requestsPerSecond = requestsPerSecond;
  
  Future<T> execute<T>(Future<T> Function() operation) async {
    final minInterval = Duration(
      milliseconds: 1000 ~/ _requestsPerSecond,
    );
    
    final now = DateTime.now();
    final elapsed = now.difference(_lastRequest);
    
    if (elapsed < minInterval) {
      await Future.delayed(minInterval - elapsed);
    }
    
    _lastRequest = DateTime.now();
    return await operation();
  }
}
```

## Code Organization

### Service Layer Pattern

```dart
/// Separate concerns into services
class WalletService {
  final GatewayNetworkProvider _provider;
  
  WalletService(this._provider);
  
  Future<AccountOnNetwork> getAccountInfo(Address address) =>
      _provider.getAccount(address);
  
  Future<List<TokenOnNetwork>> getTokens(Address address) =>
      _provider.getFungibleTokensOfAccount(address);
}

class TransactionService {
  final GatewayNetworkProvider _provider;
  final NonceManager _nonceManager;
  
  TransactionService(this._provider)
      : _nonceManager = NonceManager(_provider);
  
  Future<String> sendEgld(
    Wallet wallet,
    Address recipient,
    BigInt amount,
  ) async {
    // Implementation
  }
}

class ContractService {
  final SmartContractController _controller;
  
  ContractService(this._controller);
  
  Future<BigInt> getPrice(String token) async {
    final result = await _controller.query(
      endpointName: 'getPrice',
      arguments: [token],
    );
    return infer<BigInt>(result.first);
  }
}
```

### Dependency Injection

```dart
/// Use DI for testability
class App {
  final GatewayNetworkProvider provider;
  final WalletService walletService;
  final TransactionService txService;
  
  App._({
    required this.provider,
    required this.walletService,
    required this.txService,
  });
  
  factory App.production() {
    final provider = GatewayNetworkProvider.mainnet();
    return App._(
      provider: provider,
      walletService: WalletService(provider),
      txService: TransactionService(provider),
    );
  }
  
  factory App.development() {
    final provider = GatewayNetworkProvider.devnet();
    return App._(
      provider: provider,
      walletService: WalletService(provider),
      txService: TransactionService(provider),
    );
  }
  
  factory App.test(GatewayNetworkProvider mockProvider) {
    return App._(
      provider: mockProvider,
      walletService: WalletService(mockProvider),
      txService: TransactionService(mockProvider),
    );
  }
}
```

## Gas Optimization

### Batch Operations

```dart
// Inefficient: Multiple transactions
for (final recipient in recipients) {
  await sendEgld(wallet, recipient, amount);
}

// Efficient: Multi-transfer when possible
final transfers = recipients.map((r) => 
  TokenTransfer.fungible(
    tokenIdentifier: 'WEGLD-bd4d79',
    amount: amount,
  )
).toList();

// Use TransfersController or TransferTransactionsFactory
await controller.createTransactionForTokenTransfer(
  account,
  nonce,
  TokenTransferInput(receiver: mainRecipient, transfers: transfers),
);
```

### Cache Network Config

```dart
class CachedNetworkConfig {
  final GatewayNetworkProvider _provider;
  NetworkConfig? _config;
  DateTime? _fetchedAt;
  final Duration _ttl;
  
  CachedNetworkConfig(
    this._provider, {
    Duration ttl = const Duration(minutes: 5),
  }) : _ttl = ttl;
  
  Future<NetworkConfig> get() async {
    if (_config != null && 
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < _ttl) {
      return _config!;
    }
    
    _config = await _provider.getNetworkConfig();
    _fetchedAt = DateTime.now();
    return _config!;
  }
}
```

## Testing

### Mock Providers

```dart
class MockNetworkProvider implements GatewayNetworkProvider {
  final Map<String, AccountOnNetwork> _accounts = {};
  final Map<String, String> _transactionHashes = {};
  
  void addAccount(Address address, BigInt balance, int nonce) {
    _accounts[address.bech32] = AccountOnNetwork(
      address: address,
      balance: Balance(balance),
      nonce: Nonce(nonce),
    );
  }
  
  @override
  Future<AccountOnNetwork> getAccount(Address address) async {
    return _accounts[address.bech32] ?? 
      AccountOnNetwork(address: address, balance: Balance.zero(), nonce: Nonce(0));
  }
  
  @override
  Future<String> sendTransaction(Transaction tx) async {
    // Generate mock hash
    final hash = 'mock_${DateTime.now().millisecondsSinceEpoch}';
    _transactionHashes[hash] = 'success';
    return hash;
  }
  
  // For testing, use TransactionOnNetwork.fromApiResponse to create mock responses:
  // final mockTx = TransactionOnNetwork.fromApiResponse({
  //   'txHash': hash,
  //   'status': 'success',
  //   'sender': senderAddress.bech32,
  //   'receiver': receiverAddress.bech32,
  //   'value': '1000000000000000000',
  //   'nonce': 5,
  //   'gasLimit': 50000,
  //   'gasPrice': 1000000000,
  //   'chainID': 'D',
  // });
}
```

## Logging

```dart
class Logger {
  static void transaction(String action, Map<String, dynamic> data) {
    final sanitized = Map.from(data)
      ..remove('privateKey')
      ..remove('mnemonic');
    
    print('[TX] $action: $sanitized');
  }
  
  static void error(String context, Object error, [StackTrace? stack]) {
    print('[ERROR] $context: $error');
    if (stack != null) {
      print(stack);
    }
  }
  
  static void network(String method, String url, int statusCode) {
    print('[NET] $method $url -> $statusCode');
  }
}
```

## Checklist

### Before Production

- [ ] Remove all hardcoded keys/mnemonics
- [ ] Enable error tracking (Sentry, etc.)
- [ ] Set up monitoring for failed transactions
- [ ] Implement rate limiting
- [ ] Test with real tokens on devnet
- [ ] Review gas settings
- [ ] Add transaction simulation
- [ ] Set up backup providers

### Security Audit

- [ ] No secrets in code or logs
- [ ] Input validation on all user data
- [ ] Proper error handling (no leaking info)
- [ ] Dependencies are up to date
- [ ] Using latest SDK version

## Next Steps

- [Error Handling](/docs/advanced/error-handling) - Handle all errors
- [Custom Serialization](/docs/advanced/custom-serialization) - Extend types
- [Getting Started](/docs/getting-started/installation) - Fresh start
