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

### Keep Signing Behind an Interface

Anything that can produce a signature over `tx.serializeForSigning()` can stand in for a local key:
a hardware device, a remote signing service, a mobile secure enclave. `IAccount` is that seam --
implement it and every controller keeps working unchanged.

```dart
/// Signs on an external device instead of holding the key in this process.
class RemoteSigningAccount implements IAccount {
  RemoteSigningAccount(this.address, this._client);

  @override
  final Address address;
  final ExternalSigningClient _client;

  /// True when the device can only display short payloads and must sign the
  /// Keccak-256 hash of the signing JSON instead of the JSON itself.
  @override
  bool get prefersHashSigning => true;

  @override
  Future<Uint8List> sign(Uint8List data) => _client.sign(data);

  @override
  Future<Uint8List> signTransaction(Transaction transaction) =>
      _client.sign(transaction.serializeForSigning());

  @override
  Future<List<Uint8List>> signTransactions(List<Transaction> transactions) async {
    final List<Uint8List> signatures = <Uint8List>[];
    for (final Transaction transaction in transactions) {
      signatures.add(await signTransaction(transaction));
    }
    return signatures;
  }

  // Guardian and relayer signatures cover exactly the same bytes as the
  // sender's, so both delegate to signTransaction.
  @override
  Future<Uint8List> signAsGuardian(Transaction transaction) =>
      signTransaction(transaction);

  @override
  Future<Uint8List> signAsRelayer(Transaction transaction) =>
      signTransaction(transaction);

  @override
  Future<Uint8List> signMessage(Message message) =>
      _client.sign(const MessageComputer().computeBytesForSigning(message));

  @override
  Future<bool> verifyTransactionSignature(
    Transaction transaction,
    Uint8List signature,
  ) async {
    return UserVerifier.fromAddress(address)
        .verify(transaction.serializeForSigning(), signature);
  }

  @override
  Future<bool> verifyMessageSignature(
    Message message,
    Uint8List signature,
  ) async {
    return UserVerifier.fromAddress(address).verify(
      const MessageComputer().computeBytesForSigning(message),
      signature,
    );
  }
}
```

`prefersHashSigning` matters for devices with a small display: when it is `true`, apply
`TransactionComputer.applyOptionsForHashSigning(tx)` before signing, or the chain rejects the
result.

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
        transactionType: 'call', // 'call' | 'deploy' | 'upgrade'
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

Do not hand-roll a nonce counter -- the SDK ships `NonceManager`, which keeps a local counter ahead
of the network, serialises concurrent callers, and can hand a reserved nonce back when a send falls
through.

```dart
final nonces = NonceManager(
  address: sender.address,
  networkProvider: provider,
  resyncInterval: const Duration(minutes: 5), // Duration.zero disables it
);

Future<String> sendOne(Transaction draft, UserSigner signer) async {
  final nonce = await nonces.next();          // reserves it
  try {
    final signed = await draft.copyWith(newNonce: nonce).signWith(signer);
    final hash = await provider.sendTransaction(signed);
    nonces.applyNonce(nonce);                 // broadcast succeeded
    return hash;
  } catch (_) {
    nonces.release(nonce);                    // give it back for reuse
    rethrow;
  }
}
```

`resync()` re-reads the account and moves the counter **forward only**, so a lagging network view
can never rewind nonces you have already used.

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
  TransactionService(this._provider, IAccount account)
      : _nonces = NonceManager(
          address: account.address,
          networkProvider: _provider,
        ),
        _transfers = TransfersController(chainId: _provider.chainId);

  final GatewayNetworkProvider _provider;
  final NonceManager _nonces;
  final TransfersController _transfers;

  Future<String> sendEgld(
    IAccount account,
    Address recipient,
    Balance amount,
  ) async {
    final nonce = await _nonces.next();
    final tx = await _transfers.createTransactionForNativeTransfer(
      account,
      nonce,
      NativeTransferInput(receiver: recipient, amount: amount),
    );
    final hash = await _provider.sendTransaction(tx);
    _nonces.applyNonce(nonce);
    return hash;
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
  
  factory App.production(IAccount account) {
    final provider = GatewayNetworkProvider.mainnet();
    return App._(
      provider: provider,
      walletService: WalletService(provider),
      txService: TransactionService(provider, account),
    );
  }

  factory App.development(IAccount account) {
    final provider = GatewayNetworkProvider.devnet();
    return App._(
      provider: provider,
      walletService: WalletService(provider),
      txService: TransactionService(provider, account),
    );
  }

  factory App.test(GatewayNetworkProvider mockProvider, IAccount account) {
    return App._(
      provider: mockProvider,
      walletService: WalletService(mockProvider),
      txService: TransactionService(mockProvider, account),
    );
  }
}
```

## Gas Optimization

### Batch Operations

A multi-transfer bundles **several tokens to one receiver** in a single transaction -- it does not
fan out to many recipients. Use it when you would otherwise send the same receiver two or three
transfers back to back:

```dart
// Inefficient: one transaction per token, three nonces, three fees
await sendToken(account, recipient, wegld);
await sendToken(account, recipient, usdc);
await sendToken(account, recipient, nft);

// Efficient: one MultiESDTNFTTransfer
final tx = await transfersController.createTransactionForTokenTransfer(
  account,
  nonce,
  TokenTransferInput(
    receiver: recipient,
    transfers: <TokenTransfer>[
      TokenTransfer.fungible(
        tokenIdentifier: 'WEGLD-bd4d79',
        amount: BigInt.parse('500000000000000000'),
      ),
      TokenTransfer.fungible(
        tokenIdentifier: 'USDC-c76f1f',
        amount: BigInt.from(500000000),
      ),
      TokenTransfer.nonFungible(
        tokenIdentifier: 'MYNFT-abc123',
        nonce: 42,
        amount: BigInt.one,
      ),
    ],
  ),
);
```

Different recipients still need one transaction each -- send them concurrently with `BatchHelper`
and consecutive nonces rather than serially.

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

Implement the `NetworkProvider` interface, not a concrete provider class. `noSuchMethod` supplies
forwarders for the members your test does not care about, so you only write the ones it exercises:

```dart
class MockNetworkProvider implements NetworkProvider {
  final Map<String, AccountOnNetwork> _accounts = <String, AccountOnNetwork>{};
  final Map<String, String> _transactionHashes = <String, String>{};

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
        AccountOnNetwork(
          address: address,
          balance: Balance.zero(),
          nonce: const Nonce(0),
        );
  }

  @override
  Future<String> sendTransaction(Transaction tx) async {
    final hash = 'mock_${DateTime.now().millisecondsSinceEpoch}';
    _transactionHashes[hash] = 'success';
    return hash;
  }

  // Everything else throws NoSuchMethodError if a test touches it.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

Build canned network responses with `TransactionOnNetwork.fromApiResponse(...)`:

```dart
final mockTx = TransactionOnNetwork.fromApiResponse(<String, dynamic>{
  'txHash': 'abc123',
  'status': 'success',
  'sender': senderAddress.bech32,
  'receiver': receiverAddress.bech32,
  'value': '1000000000000000000',
  'nonce': 5,
  'gasLimit': 50000,
  'gasPrice': 1000000000,
  'chainID': 'D',
});
```

## Logging

The SDK takes a `Logger` on providers and controllers; `ConsoleLogger` is the built-in
implementation. Keep secrets out of the context maps you hand it:

```dart
final logger = ConsoleLogger(
  minLevel: LogLevel.warning, // debug during development
  includeTimestamp: true,
);

final provider = GatewayNetworkProvider.devnet(logger: logger);

/// Strips key material before anything is logged.
Map<String, dynamic> sanitize(Map<String, dynamic> data) {
  return Map<String, dynamic>.from(data)
    ..remove('privateKey')
    ..remove('mnemonic')
    ..remove('password');
}

logger.info('Sending transaction', context: sanitize(<String, dynamic>{
  'sender': account.address.bech32,
  'nonce': nonce.value,
}));
```

Use `NullLogger()` to switch logging off entirely without changing call sites.

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
