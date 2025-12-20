---
id: cookbook-breakdown
title: Cookbook Breakdown
sidebar_position: 4
description: In-depth explanations of cookbook examples with line-by-line breakdowns for token swaps and relayed transactions.
---

# Cookbook Breakdown

In-depth explanations of each cookbook example, covering every line of code.

## Token Swap {#token-swap}

The token swap example demonstrates swapping WEGLD for MEX on the xExchange DEX.

### Step 1: Logger Configuration

```dart
final logger = ConsoleLogger(
  minLevel: LogLevel.debug,      // Show all log levels
  includeTimestamp: true,        // Add timestamps to logs
  prettyPrintContext: true,      // Format JSON nicely
  showBorders: true,             // Visual separators
  useColors: true,               // Colored output
);
```

**Why this matters:** During development, verbose logging helps trace transaction flow and debug issues. In production, set `minLevel: LogLevel.warning`.

### Step 2: Wallet Loading

```dart
final pem = File('assets/alice.pem').readAsStringSync();
final account = await Account.fromPem(pem);
```

**The `Account` object:**
- Contains the private key for signing
- Provides the public address
- Never transmits the private key over the network

**PEM format:**
```
-----BEGIN PRIVATE KEY for erd1...-----
<base64 encoded key>
-----END PRIVATE KEY for erd1...-----
```

### Step 3: Network Provider

```dart
final provider = ApiNetworkProvider.devnet(logger: logger);
```

**Provider types:**

| Type | Use Case |
|------|----------|
| `GatewayNetworkProvider` | Transaction submission, real-time data |
| `ApiNetworkProvider` | Historical data, token queries, indexing |

Both work for this example, but `ApiNetworkProvider` has better token query support.

### Step 4: Fresh Account State

```dart
final freshAccount = await provider.getAccount(aliceAddress);
final currentNonce = freshAccount.nonce;
```

**Critical:** Always fetch fresh nonce before transactions. Stale nonce = failed transaction.

**What `getAccount` returns:**
```dart
class AccountOnNetwork {
  final Address address;
  final Balance balance;    // EGLD balance
  final Nonce nonce;        // Transaction counter
  // ... more fields
}
```

### Step 5: ABI Loading

```dart
final abiJson = File('assets/pair.abi.json').readAsStringSync();
final abi = SmartContractAbi.fromJson(abiJson);
```

**The ABI contains:**
- Endpoint definitions (functions you can call)
- Event definitions (events the contract emits)
- Type definitions (structs, enums used by the contract)

**Inspecting the ABI:**
```dart
// List all endpoints
for (final endpoint in abi.endpoints) {
  print('${endpoint.name}: ${endpoint.inputs.length} inputs');
}

// Check for specific endpoint
final hasSwap = abi.endpoints.any((e) => e.name == 'swapTokensFixedInput');
```

### Step 6: Controller Setup

```dart
final controller = SmartContractController(
  contractAddress: SmartContractAddress.fromBech32('erd1qqq...'),
  abi: abi,
  networkProvider: provider,
  logger: logger,
);
```

**The controller:**
- Encodes arguments using ABI type information
- Builds transactions with correct data payload
- Decodes query results automatically

### Step 7: Token Definitions

```dart
final wegldAmount = BigInt.from(1) * BigInt.from(10).pow(17);
final wegldToken = TokenIdentifierValue('WEGLD-a28c59');
final mexToken = TokenIdentifierValue('MEX-a659d0');
```

**Understanding amounts:**
- EGLD has 18 decimals
- `10^17` = 0.1 tokens
- `10^18` = 1.0 token
- Always work with raw BigInt values

**Token identifier format:** `{TICKER}-{HEX_SUFFIX}`

### Step 8: Query Expected Output

```dart
final amountOutResult = await controller.query(
  endpointName: 'getAmountOut',
  arguments: [wegldToken, wegldAmount],
);
final amountOut = infer<BigInt>(amountOutResult[0]);
```

**Queries vs Transactions:**
- Queries are free (no gas)
- Queries are read-only
- Queries execute instantly
- Results are automatically decoded

### Step 9: Slippage Calculation

```dart
final minAmountOut = (amountOut * BigInt.from(9900)) ~/ BigInt.from(10000);
```

**Why slippage matters:**
- Prices change between query and execution
- Other transactions may front-run yours
- Without minimum, you could get 0 tokens

**Common slippage values:**
- 0.5% = multiply by 9950, divide by 10000
- 1% = multiply by 9900, divide by 10000
- 3% = multiply by 9700, divide by 10000

### Step 10: Token Transfer Attachment

```dart
final tokenTransfer = TokenTransferValue.fromPrimitives(
  tokenIdentifier: wegldToken.identifier,
  amount: wegldAmount,
);
```

**Multi-transfer capability:**
```dart
tokenTransfers: [
  tokenTransfer1,
  tokenTransfer2,
  // Can attach multiple tokens
],
```

### Step 11: Transaction Building

```dart
final tx = await controller.call(
  account: account,
  nonce: currentNonce,
  endpointName: 'swapTokensFixedInput',
  arguments: [mexToken, minAmountOut],
  tokenTransfers: [tokenTransfer],
  options: BaseControllerInput(gasLimit: GasLimit(25000000)),
);
```

**What `controller.call` does:**
1. Encodes endpoint name and arguments
2. Builds the data payload
3. Signs the transaction with sender's key

### Step 12: Transaction Submission

```dart
final txHash = await provider.sendTransaction(tx);
```

**The transaction hash:**
- 64-character hex string
- Unique identifier for tracking
- Use in explorer: `https://devnet-explorer.multiversx.com/transactions/{hash}`

### Step 13: Awaiting Completion

```dart
final watcher = TransactionWatcher(networkProvider: provider);
final result = await watcher.awaitCompleted(txHash);
```

**Transaction states:**
- `pending` - In mempool
- `success` - Executed successfully
- `invalid` - Validation failed
- `fail` - Execution failed (reverted)

---

## Relayed Transaction {#relayed-transaction}

Relayed transactions enable gas-free user experiences.

### The Two Signer Pattern

```dart
// User: performs the action
final account = await Account.fromPem(pem);

// Relayer: pays for gas
final accountRelayer = UserSigner.fromPem(pemRelayer);
```

**Why `UserSigner` for relayer?**
- `Account` loads the full wallet (for transaction building)
- `UserSigner` is lighter (only for signing)
- Relayer only needs to sign, not build transactions

### Specifying the Relayer

```dart
options: BaseControllerInput(
  gasLimit: GasLimit(25000000),
  relayer: relayerAddress,
),
```

This embeds the relayer address in the transaction structure, enabling the protocol to:
1. Charge gas to relayer's account
2. Verify relayer signature
3. Execute on behalf of user

### Dual Signature Process

```dart
// Step 1: User signs (happens in controller.call)
final innerTx = await controller.call(...);

// Step 2: Relayer signs
final fullySignedTx = await innerTx.signAsRelayer(accountRelayer);
```

**Signature verification:**
- Inner transaction has user's signature
- Outer wrapper has relayer's signature
- Both must be valid for execution

### Economic Model

| Party | Responsibility |
|-------|---------------|
| User | Signs action, owns assets |
| Relayer | Pays gas, provides UX |
| Protocol | Verifies both signatures |

---

## EGLD Transfer {#egld-transfer}

The simplest transaction type - sending native EGLD.

### TransfersController

```dart
final controller = TransfersController(chainId: const ChainId.devnet());
```

**Difference from SmartContractController:**
- No ABI needed
- Simpler interface
- Optimized for transfers

### Balance Creation

```dart
Balance.fromEgld(0.1)
```

**Under the hood:**
```dart
static Balance fromEgld(double egld) {
  final raw = BigInt.from(egld * 1e18);
  return Balance(raw);
}
```

### Transfer Input

```dart
NativeTransferInput(
  receiver: bobAddress,
  amount: Balance.fromEgld(0.1),
)
```

**Other transfer inputs:**
```dart
// ESDT transfer
EsdtTransferInput(
  receiver: bobAddress,
  tokenIdentifier: 'MEX-a659d0',
  amount: BigInt.from(1000000),
)

// NFT transfer
NftTransferInput(
  receiver: bobAddress,
  tokenIdentifier: 'NFT-abc123',
  nonce: 1,
)
```

### Nonce Awaiting

```dart
final awaiter = AccountAwaiter(networkProvider: provider);
final newAccount = await awaiter.awaitNonceIncrement(
  alice.address,
  currentNonce,
  options: const AccountAwaitingOptions(
    timeout: Duration(minutes: 2),
    pollingInterval: Duration(seconds: 5),
  ),
);
```

**Why await nonce instead of transaction?**
- More reliable for chains of transactions
- Provides updated account state
- Useful for UX (show new balance immediately)

---

## WebSocket Events {#websocket-events}

Real-time event streaming for live dApps.

### Configuration

```dart
WebSocketEventStreamConfig.byIdentifiers(
  websocketUrl: 'wss://kepler-api.projectx.mx/devnet/events',
  identifiers: const ['swap'],
  contractAddress: controller.contractAddress,
  headers: {'Api-Key': 'your-api-key'},
  abi: abi,
  logger: logger,
)
```

**Filter hierarchy:**
1. `identifiers` - Event names (swap, transfer, etc.)
2. `contractAddress` - Specific contract
3. ABI - Enable parsing

### Event Stream

```dart
swapStream.events.listen((result) {
  final parsed = result.parsedEvent!;
  print(parsed.toMap());
});
```

**Stream properties:**
- Continuous until disconnected
- Automatic reconnection (configurable)
- Back-pressure handling

### Parsed Event Structure

```dart
// Example swap event
{
  'identifier': 'swap',
  'tokenIn': 'WEGLD-a28c59',
  'tokenOut': 'MEX-a659d0',
  'amountIn': BigInt.from(...),
  'amountOut': BigInt.from(...),
  'caller': 'erd1...',
}
```

### Production Considerations

```dart
// Handle connection lifecycle
swapStream.events.listen(
  onData: (event) => handleEvent(event),
  onError: (error) => reconnect(),
  onDone: () => cleanup(),
  cancelOnError: false,  // Keep listening after errors
);

// Graceful shutdown
Future<void> shutdown() async {
  await swapStream.disconnect();
}
```

---

## Common Patterns

### Error Recovery

```dart
Future<T> withRetry<T>(Future<T> Function() operation) async {
  for (var i = 0; i < 3; i++) {
    try {
      return await operation();
    } catch (e) {
      if (i == 2) rethrow;
      await Future.delayed(Duration(seconds: 1 << i));
    }
  }
  throw StateError('Unreachable');
}
```

### Balance Checking

```dart
Future<void> ensureSufficientBalance(
  NetworkProvider provider,
  Address address,
  Balance required,
) async {
  final account = await provider.getAccount(address);
  if (account.balance < required) {
    throw ValidationException(
      'Insufficient balance',
      parameterName: 'balance',
      invalidValue: account.balance.value,
      constraint: 'required: ${required.toDenominatedTrimmed}',
    );
  }
}
```

### Transaction Batching

```dart
// Send multiple transactions with incrementing nonce
var nonce = freshAccount.nonce;
for (final transfer in transfers) {
  final tx = await controller.call(
    account: account,
    nonce: nonce,
    endpointName: 'transfer',
    arguments: [transfer.recipient, transfer.amount],
    options: BaseControllerInput(gasLimit: GasLimit(10000000)),
  );
  await provider.sendTransaction(tx);
  nonce = nonce.increment();
}
```
