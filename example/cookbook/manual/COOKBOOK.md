---
id: manual-sdk-cookbook
title: Manual SDK Cookbook
---

[comment]: # (mx-abstract)

Implementation guide for working with the MultiversX SDK without code generation. Learn to load ABIs manually, instantiate controllers, and drive blockchain interactions with complete control.

[comment]: # (mx-context-auto)

## Overview

This guide focuses on the "manual" path: loading ABIs yourself, instantiating controllers, and driving MultiversX interactions without generated code. Use it when you need complete control, want to understand the SDK internals, or are prototyping contract interfaces that change frequently.

[comment]: # (mx-context-auto)

## Network Providers

### Connecting to MultiversX

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

final logger = ConsoleLogger(
  minLevel: LogLevel.debug,         // [1]
  includeTimestamp: true,           // [2]
  prettyPrintContext: true,         // [3]
  showBorders: true,
  useColors: true,
);

final provider = GatewayNetworkProvider.devnet(logger: logger); // [4]
```

Where:
- **[1]** Log level: `debug`, `info`, `warning`, or `error`
- **[2]** Add timestamps to log entries
- **[3]** Format JSON output for readability
- **[4]** Connect to devnet; also available: `.mainnet()`, `.testnet()`

:::tip
Use `GatewayNetworkProvider` for transaction flows; switch to `ApiNetworkProvider` for explorer-style aggregation or account indexing.
:::

### Loading accounts

```dart
import 'dart:io';

final pem = File('assets/alice.pem').readAsStringSync();
final account = await Account.fromPem(pem);  // [1]
print('Address: ${account.address.bech32}'); // [2]
```

Where:
- **[1]** Parse PEM file to extract signing keys
- **[2]** Get bech32-encoded address (e.g., `erd1...`)

:::important
Always fetch a fresh nonce from the chain before submitting a new transaction.
:::

### Address helpers

```dart
final address = Address.fromBech32('erd1...');
final contract = SmartContractAddress.fromBech32('erd1...');
final fromHex = Address.fromHex('00ab...');
```

Use `SmartContractAddress` when referencing deployed contracts to enable ABI-aware helpers.

[comment]: # (mx-context-auto)

## Network Operations

### Fetching account data

```dart
final accountOnNetwork = await provider.getAccount(address);
print('Balance: ${accountOnNetwork.balance.toDenominatedTrimmed} EGLD'); // [1]
print('Nonce: ${accountOnNetwork.nonce.value}');                         // [2]

final mex = await provider.getTokenOfAccount(address, 'MEX-a659d0');     // [3]
print('MEX balance: ${mex.denominatedBalance}');
```

Where:
- **[1]** Human-readable EGLD balance
- **[2]** Current transaction nonce
- **[3]** Query specific token balance

### Awaiting transaction finality

```dart
final txHash = await provider.sendTransaction(transaction);

// Option 1: Wait for transaction completion
final watcher = TransactionWatcher(networkProvider: provider);
final completed = await watcher.awaitCompleted(txHash);      // [1]

// Option 2: Wait for nonce increment
final awaiter = AccountAwaiter(networkProvider: provider);
final updatedAccount = await awaiter.awaitNonceIncrement(    // [2]
  address,
  currentNonce,
  options: const AccountAwaitingOptions(
    timeout: Duration(minutes: 2),
    pollingInterval: Duration(seconds: 5),
  ),
);
```

Where:
- **[1]** Blocks until transaction reaches final status
- **[2]** Blocks until account nonce increments

[comment]: # (mx-context-auto)

## Smart Contract Interaction

### Parsing an ABI

```dart
final abiJson = File('assets/pair.abi.json').readAsStringSync();
final abi = SmartContractAbi.fromJson(abiJson);
```

The ABI object lists endpoints, events, and custom structs/enums.

### Creating a controller

```dart
final controller = SmartContractController(
  contractAddress: SmartContractAddress.fromBech32(
    'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g'
  ),
  abi: abi,
  networkProvider: provider,
  logger: logger,
);
```

### Executing queries (read-only)

```dart
final result = await controller.query(
  endpointName: 'getAmountOut',                        // [1]
  arguments: [
    TokenIdentifierValue('WEGLD-a28c59'),              // [2]
    BigInt.from(100000000000000000),                   // [3]
  ],
);
final amountOut = infer<BigInt>(result.first);         // [4]
```

Where:
- **[1]** Name of the view function
- **[2]** Token identifier argument
- **[3]** Amount: 0.1 tokens (17 zeros)
- **[4]** Use `infer<T>()` for compile-time type safety

### Building transactions (state changes)

```dart
final payment = TokenTransferValue.fromPrimitives(
  tokenIdentifier: 'WEGLD-a28c59',
  amount: BigInt.from(100000000000000000),            // [1]
);

final tx = await controller.call(
  account: account,
  nonce: freshAccount.nonce,                          // [2]
  endpointName: 'swapTokensFixedInput',
  arguments: [
    TokenIdentifierValue('MEX-a659d0'),
    BigInt.from(1000000),                             // [3]
  ],
  tokenTransfers: [payment],
  options: BaseControllerInput(gasLimit: GasLimit(25000000)),
);
```

Where:
- **[1]** Send 0.1 WEGLD with the transaction
- **[2]** Use freshly fetched nonce
- **[3]** Minimum output amount (slippage protection)

Broadcast with `provider.sendTransaction(tx)` and monitor as shown earlier.

### Raw queries without ABI

When you don't have an ABI, use `SmartContractController.withoutAbi()` and `queryRaw()`:

```dart
final controller = SmartContractController.withoutAbi(
  contractAddress: SmartContractAddress.fromBech32('erd1qqq...'),
  networkProvider: provider,
);

final result = await controller.queryRaw(
  endpointName: 'getBalance',
  arguments: [AddressValue.fromBech32('erd1user...')],
);

if (result.isSuccess && !result.isEmpty) {
  final codec = BinaryCodec.withDefaults();
  final balance = codec.decodeTopLevel(
    result.first!,
    BigUIntType.type,
  ) as BigUIntValue;
  print('Balance: ${balance.value}');
}
```

### Parsing nested types without ABI

For complex return types (structs, lists of structs, options), define the type structure manually:

```dart
// Define struct type matching the contract's definition
final tokenPaymentType = StructBuilder('EsdtTokenPayment')
    .field('token_identifier', TokenIdentifierType.type)
    .field('token_nonce', U64Type.type)
    .field('amount', BigUIntType.type)
    .build();

// For List<EsdtTokenPayment>
final paymentsListType = ListType(tokenPaymentType);

// Query and decode
final result = await controller.queryRaw(
  endpointName: 'getAllPayments',
  arguments: [],
);

if (result.isSuccess && !result.isEmpty) {
  final codec = BinaryCodec.withDefaults();
  final listValue = codec.decodeTopLevel(
    result.first!,
    paymentsListType,
  ) as ListValue;
  
  for (final item in listValue.items) {
    final payment = item as StructValue;
    final tokenId = payment.getField('token_identifier').nativeValue;
    print('Token: $tokenId');
  }
}
```

For nested structs (struct within struct):

```dart
final userInfoType = StructBuilder('UserInfo')
    .field('user_address', AddressType.type)
    .field('user_id', U64Type.type)
    .field('last_payment', tokenPaymentType) // Nested struct
    .build();
```

For Option types:

```dart
final optionPaymentType = OptionType(tokenPaymentType);

// Decode and check
final optionValue = codec.decodeTopLevel(bytes, optionPaymentType) as OptionValue;
if (optionValue.isNone) {
  print('Not found');
} else {
  final payment = optionValue.value as StructValue;
  print('Found: ${payment.getField('amount').nativeValue}');
}
```

:::tip
Field order and types must exactly match the contract's struct definition. Field names are for your convenience only.
:::

[comment]: # (mx-context-auto)

## Event Monitoring

### WebSocket streams

```dart
final config = WebSocketEventStreamConfig.byIdentifiers(
  websocketUrl: 'wss://kepler-api.projectx.mx/devnet/events',
  identifiers: const ['swap'],                        // [1]
  contractAddress: controller.contractAddress,
  headers: {'Api-Key': 'your-api-key'},               // [2]
  abi: abi,
  logger: logger,
);

final stream = WebSocketEventStream(config);
await stream.connect();

stream.events.listen((result) {
  final event = result.parsedEvent!;
  print('Swap: ${event.toMap()}');                    // [3]
});
```

Where:
- **[1]** Event identifiers for server-side filtering
- **[2]** API key for authentication
- **[3]** Access structured event data

:::caution
Remember to close the stream when finished to free resources.
:::

[comment]: # (mx-context-auto)

## Token Transfers

### Using TransfersController

```dart
final transferController = TransfersController(chainId: const ChainId.devnet());

final tx = await transferController.createTransactionForNativeTransfer(
  account,
  accountOnNetwork.nonce,
  NativeTransferInput(
    receiver: Address.fromBech32('erd1...'),
    amount: Balance.fromEgld(0.1),
  ),
);
```

### Token transfer (ESDT/NFT/SFT)

```dart
final tx = await transferController.createTransactionForTokenTransfer(
  account,
  accountOnNetwork.nonce,
  TokenTransferInput(
    receiver: Address.fromBech32('erd1...'),
    transfers: [
      TokenTransfer.fungible(
        tokenIdentifier: 'WEGLD-a28c59',
        amount: BigInt.from(1e18),
      ),
    ],
  ),
);
```

### NFT/SFT transfer

```dart
final tx = await transferController.createTransactionForTokenTransfer(
  account,
  accountOnNetwork.nonce,
  TokenTransferInput(
    receiver: Address.fromBech32('erd1...'),
    transfers: [
      TokenTransfer.nonFungible(
        tokenIdentifier: 'COLLECTION-abc123',
        tokenNonce: 42,
      ),
    ],
  ),
);
```

### Multi-token transfer

```dart
final tx = await transferController.createTransactionForMultiTokenTransfer(
  account,
  accountOnNetwork.nonce,
  TokenTransferInput(
    receiver: Address.fromBech32('erd1...'),
    transfers: [
      TokenTransfer.fungible(tokenIdentifier: 'WEGLD-a28c59', amount: BigInt.from(1e18)),
      TokenTransfer.fungible(tokenIdentifier: 'MEX-a659d0', amount: BigInt.from(5e18)),
    ],
  ),
);
```

[comment]: # (mx-context-auto)

## Token Management

### Using TokenManagementController

Issue, manage roles, and control ESDT tokens.

```dart
final tokenController = TokenManagementController(chainId: const ChainId.devnet());
```

### Issuing a fungible token

```dart
final tx = await tokenController.createTransactionForIssuingFungible(
  account,
  accountOnNetwork.nonce,
  IssueFungibleInput(
    tokenName: 'MyToken',                    // [1]
    tokenTicker: 'MTK',                      // [2]
    initialSupply: BigInt.from(1000000),     // [3]
    numDecimals: BigInt.from(18),            // [4]
    canFreeze: false,
    canWipe: false,
    canPause: false,
    canChangeOwner: true,
    canUpgrade: true,
    canAddSpecialRoles: true,
  ),
  const BaseControllerInput(),
);
```

Where:
- **[1]** Human-readable token name
- **[2]** 3-10 uppercase alphanumeric ticker
- **[3]** Initial mint amount
- **[4]** Decimal places (18 = EGLD-like precision)

:::important
Issuing tokens requires 0.05 EGLD fee sent with the transaction.
:::

### Issuing an NFT collection

```dart
final tx = await tokenController.createTransactionForIssuingNonFungible(
  account,
  accountOnNetwork.nonce,
  IssueNonFungibleInput(
    tokenName: 'MyNFTCollection',
    tokenTicker: 'MNFT',
    canFreeze: false,
    canWipe: false,
    canPause: false,
    canChangeOwner: true,
    canUpgrade: true,
    canAddSpecialRoles: true,
    canTransferNFTCreateRole: true,          // [1]
  ),
  const BaseControllerInput(),
);
```

Where:
- **[1]** Allow transferring NFT creation rights to other addresses

### Setting special roles

```dart
// Grant minting rights to an address
final tx = await tokenController.createTransactionForSettingSpecialRoleOnFungibleToken(
  account,
  accountOnNetwork.nonce,
  FungibleSpecialRoleInput(
    tokenIdentifier: 'MTK-abc123',
    user: Address.fromBech32('erd1...'),
    addRoleLocalMint: true,                  // [1]
    addRoleLocalBurn: true,                  // [2]
    addRoleESDTTransferRole: false,
  ),
  const BaseControllerInput(),
);
```

Where:
- **[1]** Allow address to mint new tokens
- **[2]** Allow address to burn tokens

### Minting tokens (local mint)

```dart
final tx = await tokenController.createTransactionForLocalMinting(
  account,
  accountOnNetwork.nonce,
  LocalMintInput(
    tokenIdentifier: 'MTK-abc123',
    supplyToMint: BigInt.from(1000) * BigInt.from(10).pow(18),
  ),
  const BaseControllerInput(),
);
```

### Creating an NFT

```dart
final tx = await tokenController.createTransactionForCreatingNft(
  account,
  accountOnNetwork.nonce,
  MintInput(
    tokenIdentifier: 'MNFT-abc123',
    initialQuantity: BigInt.one,
    name: 'My First NFT',
    royalties: 500,                          // [1]
    hash: '',
    attributes: Uint8List.fromList(utf8.encode('metadata:ipfs://...')),
    uris: ['https://ipfs.io/ipfs/Qm...'],
  ),
  const BaseControllerInput(),
);
```

Where:
- **[1]** Royalties in basis points (500 = 5%)

[comment]: # (mx-context-auto)

## Staking & Delegation

### Using DelegationController

Manage staking operations with validator pools.

```dart
final delegationController = DelegationController(chainId: const ChainId.mainnet());
```

### Delegating EGLD

```dart
final tx = await delegationController.createTransactionForDelegating(
  account,
  accountOnNetwork.nonce,
  DelegateInput(
    delegationContract: Address.fromBech32('erd1qqqqqqqqqqqqqqpgq...'), // [1]
    amount: Balance.fromEgld(100),                                       // [2]
  ),
);
```

Where:
- **[1]** Staking provider's delegation contract
- **[2]** Amount to delegate (minimum varies by provider)

### Claiming rewards

```dart
final tx = await delegationController.createTransactionForClaimingRewards(
  account,
  accountOnNetwork.nonce,
  WithdrawInput(
    delegationContract: Address.fromBech32('erd1qqqqqqqqqqqqqqpgq...'),
  ),
);
```

### Undelegating

```dart
final tx = await delegationController.createTransactionForUndelegating(
  account,
  accountOnNetwork.nonce,
  UndelegateInput(
    delegationContract: Address.fromBech32('erd1qqqqqqqqqqqqqqpgq...'),
    amount: Balance.fromEgld(50),
  ),
);
```

:::caution
Undelegated funds enter a 10-day unbonding period before withdrawal.
:::

### Withdrawing (after unbonding)

```dart
final tx = await delegationController.createTransactionForWithdrawing(
  account,
  accountOnNetwork.nonce,
  WithdrawInput(
    delegationContract: Address.fromBech32('erd1qqqqqqqqqqqqqqpgq...'),
  ),
);
```

### Redelegating rewards (compound)

```dart
final tx = await delegationController.createTransactionForRedelegatingRewards(
  account,
  accountOnNetwork.nonce,
  WithdrawInput(
    delegationContract: Address.fromBech32('erd1qqqqqqqqqqqqqqpgq...'),
  ),
);
```

[comment]: # (mx-context-auto)

## Account Security

### Using AccountController

Manage account storage and guardian protection.

```dart
final accountController = AccountController(chainId: const ChainId.devnet());
```

### Saving key-value data

```dart
import 'dart:convert';
import 'dart:typed_data';

final tx = await accountController.createTransactionForSavingKeyValue(
  account,
  accountOnNetwork.nonce,
  SaveKeyValueInput(
    keyValuePairs: {
      Uint8List.fromList(utf8.encode('preferences')):              // [1]
        Uint8List.fromList(utf8.encode('{"theme":"dark"}')),       // [2]
    },
  ),
);
```

Where:
- **[1]** Key as bytes
- **[2]** Value as bytes (JSON, binary, etc.)

### Setting up a guardian (2FA)

```dart
// Step 1: Set the guardian address
final setTx = await accountController.createTransactionForSettingGuardian(
  account,
  accountOnNetwork.nonce,
  SetGuardianInput(
    guardianAddress: Address.fromBech32('erd1guardian...'),        // [1]
    serviceId: 'MultiversXTCSService',                             // [2]
  ),
);

// Step 2: Activate guardian protection (after 20-epoch delay)
final guardTx = await accountController.createTransactionForGuardingAccount(
  account,
  accountOnNetwork.nonce,
);
```

Where:
- **[1]** Guardian service address
- **[2]** Service identifier for 2FA provider

:::important
Once guarded, sensitive transactions require guardian co-signature.
:::

### Removing guardian protection

```dart
final tx = await accountController.createTransactionForUnguardingAccount(
  account,
  accountOnNetwork.nonce,
  options: BaseControllerInput(
    guardian: guardianAddress,               // [1]
  ),
);
```

Where:
- **[1]** Guardian must co-sign the removal transaction

[comment]: # (mx-context-auto)

## Controllers vs Factories

The SDK provides two levels of abstraction:

| Layer | Returns | Signing | Gas Estimation | Use Case |
| ----- | ------- | ------- | -------------- | -------- |
| **Controller** | Signed `Transaction` | Automatic | Optional auto-gas | Most applications |
| **Factory** | Unsigned `Transaction` | Manual | Manual | Custom signing flows, hardware wallets, relayed transactions |

### When to use Factories

- **Hardware wallets**: Need to sign on external device
- **Relayed transactions**: Third party signs and pays gas
- **Multi-signature**: Collect multiple signatures before broadcast
- **Deferred signing**: Build now, sign later
- **Custom gas logic**: Override default gas calculations

[comment]: # (mx-context-auto)

## Transaction Factories

### TransferTransactionsFactory

Build unsigned transfer transactions for any token type.

```dart
final factory = TransferTransactionsFactory(
  config: TransferTransactionsConfig(chainId: const ChainId.devnet()),
);

// EGLD transfer (unsigned)
final unsignedTx = factory.createTransactionForNativeTokenTransfer(
  sender: account.address,
  receiver: Address.fromBech32('erd1...'),
  nativeAmount: Balance.fromEgld(1.5),
  data: utf8.encode('payment for services'),        // [1]
);

// Sign manually
unsignedTx.nonce = accountOnNetwork.nonce;          // [2]
final signedTx = account.signTransaction(unsignedTx);
await provider.sendTransaction(signedTx);
```

Where:
- **[1]** Optional data payload
- **[2]** Set nonce before signing

### ESDT transfer (unsigned)

```dart
final unsignedTx = factory.createTransactionForEsdtTransfer(
  sender: account.address,
  receiver: Address.fromBech32('erd1...'),
  tokenTransfers: [
    TokenTransfer.fungible(
      tokenIdentifier: 'WEGLD-a28c59',
      amount: BigInt.from(1e18),
    ),
  ],
);
```

### Multi-transfer (unsigned)

```dart
final unsignedTx = factory.createTransactionForTransfer(
  sender: account.address,
  receiver: Address.fromBech32('erd1...'),
  nativeAmount: Balance.fromEgld(0.5),              // [1]
  tokenTransfers: [
    TokenTransfer.fungible(tokenIdentifier: 'WEGLD-a28c59', amount: BigInt.from(1e18)),
    TokenTransfer.nonFungible(tokenIdentifier: 'NFT-abc123', tokenNonce: 1),
  ],
  data: utf8.encode('mixed transfer'),
);
```

Where:
- **[1]** Combine EGLD + tokens in single transaction

### TokenManagementTransactionsFactory

Build unsigned token issuance and management transactions.

```dart
final factory = TokenManagementTransactionsFactory(
  config: TokenManagementConfig(chainId: const ChainId.devnet()),
);

// Issue fungible token (unsigned)
final unsignedTx = factory.createTransactionForIssuingFungible(
  sender: account.address,
  tokenName: 'MyToken',
  tokenTicker: 'MTK',
  initialSupply: BigInt.from(1000000) * BigInt.from(10).pow(18),
  decimals: 18,
  properties: TokenProperties(
    canFreeze: false,
    canWipe: false,
    canPause: false,
    canChangeOwner: true,
    canUpgrade: true,
    canAddSpecialRoles: true,
  ),
);

// Sign and send
unsignedTx.nonce = accountOnNetwork.nonce;
final signedTx = account.signTransaction(unsignedTx);
```

### Issue NFT collection (unsigned)

```dart
final unsignedTx = factory.createTransactionForIssuingNonFungible(
  sender: account.address,
  tokenName: 'MyNFTs',
  tokenTicker: 'MNFT',
  properties: TokenProperties(
    canFreeze: false,
    canWipe: false,
    canPause: false,
    canChangeOwner: true,
    canUpgrade: true,
    canAddSpecialRoles: true,
    canTransferNFTCreateRole: true,
  ),
);
```

### DelegationTransactionsFactory

Build unsigned staking transactions.

```dart
final factory = DelegationTransactionsFactory(
  DelegationTransactionsConfig(chainId: const ChainId.mainnet()),
);

// Delegate EGLD (unsigned)
final unsignedTx = factory.createTransactionForDelegating(
  sender: account.address,
  delegationContract: Address.fromBech32('erd1qqqqqqqqqqqqqqpgq...'),
  amount: Balance.fromEgld(100),
);

// Claim rewards (unsigned)
final claimTx = factory.createTransactionForClaimingRewards(
  sender: account.address,
  delegationContract: Address.fromBech32('erd1qqqqqqqqqqqqqqpgq...'),
);

// Undelegate (unsigned)
final undelegateTx = factory.createTransactionForUndelegating(
  sender: account.address,
  delegationContract: Address.fromBech32('erd1qqqqqqqqqqqqqqpgq...'),
  amount: Balance.fromEgld(50),
);
```

### AccountTransactionsFactory

Build unsigned account management transactions.

```dart
final factory = AccountTransactionsFactory(
  AccountTransactionsConfig(chainId: const ChainId.devnet()),
);

// Save key-value data (unsigned)
final unsignedTx = factory.createTransactionForSavingKeyValue(
  sender: account.address,
  keyValuePairs: {
    Uint8List.fromList(utf8.encode('settings')):
      Uint8List.fromList(utf8.encode('{"theme":"dark"}')),
  },
);

// Set guardian (unsigned)
final guardianTx = factory.createTransactionForSettingGuardian(
  sender: account.address,
  guardianAddress: Address.fromBech32('erd1guardian...'),
  serviceId: 'MultiversXTCSService',
);
```

[comment]: # (mx-context-auto)

## Factory Summary

| Factory | Produces | Controller Equivalent |
| ------- | -------- | --------------------- |
| `TransferTransactionsFactory` | Unsigned EGLD/ESDT/NFT transfers | `TransfersController` |
| `TokenManagementTransactionsFactory` | Unsigned token issuance/roles | `TokenManagementController` |
| `DelegationTransactionsFactory` | Unsigned staking operations | `DelegationController` |
| `AccountTransactionsFactory` | Unsigned account management | `AccountController` |

:::tip
Use **Factories** when you need unsigned transactions for external signing.
Use **Controllers** when you want automatic signing and optional gas estimation.
:::

[comment]: # (mx-context-auto)

## Controller Summary

| Controller | Purpose | Common Methods |
| ---------- | ------- | -------------- |
| `SmartContractController` | Generic contract calls | `query()`, `call()` |
| `TransfersController` | Token transfers | `createTransactionForNativeTransfer()`, `createTransactionForTokenTransfer()` |
| `TokenManagementController` | ESDT lifecycle | `createTransactionForIssuingFungible()`, `createTransactionForCreatingNft()` |
| `DelegationController` | Staking operations | `createTransactionForDelegating()`, `createTransactionForClaimingRewards()` |
| `AccountController` | Account management | `createTransactionForSavingKeyValue()`, `createTransactionForSettingGuardian()` |

[comment]: # (mx-context-auto)

## Complete Example: DEX Swap

```dart title="example/cookbook/manual/controller_swap.dart"
import 'dart:io';
import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  // Step 1: Setup logging
  final logger = ConsoleLogger(
    minLevel: LogLevel.debug,
    includeTimestamp: true,
    prettyPrintContext: true,
    showBorders: true,
    useColors: true,
  );

  // Step 2: Connect to network
  final provider = ApiNetworkProvider.devnet(logger: logger);

  // Step 3: Load account
  final pem = File('assets/alice.pem').readAsStringSync();
  final account = await Account.fromPem(pem);
  final accountOnNetwork = await provider.getAccount(account.address);

  // Step 4: Load ABI and create controller
  final abiJson = File('assets/pair.abi.json').readAsStringSync();
  final abi = SmartContractAbi.fromJson(abiJson);
  final controller = SmartContractController(
    contractAddress: SmartContractAddress.fromBech32(
      'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g'
    ),
    abi: abi,
    networkProvider: provider,
    logger: logger,
  );

  // Step 5: Query expected output
  final amountIn = BigInt.from(10).pow(17); // 0.1 WEGLD
  final result = await controller.query(
    endpointName: 'getAmountOut',
    arguments: [TokenIdentifierValue('WEGLD-a28c59'), amountIn],
  );
  final expectedOut = infer<BigInt>(result[0]);

  // Step 6: Apply slippage (1%)
  final minAmountOut = (expectedOut * BigInt.from(99)) ~/ BigInt.from(100);

  // Step 7: Build transaction
  final payment = TokenTransferValue.fromPrimitives(
    tokenIdentifier: 'WEGLD-a28c59',
    amount: amountIn,
  );

  final tx = await controller.call(
    account: account,
    nonce: accountOnNetwork.nonce,
    endpointName: 'swapTokensFixedInput',
    arguments: [TokenIdentifierValue('MEX-a659d0'), minAmountOut],
    tokenTransfers: [payment],
    options: BaseControllerInput(gasLimit: GasLimit(25000000)),
  );

  // Step 8: Send and wait
  final txHash = await provider.sendTransaction(tx);
  print('Transaction submitted: $txHash');

  final watcher = TransactionWatcher(networkProvider: provider);
  final completed = await watcher.awaitCompleted(txHash);
  print('Transaction status: ${completed.status}');
}
```

[comment]: # (mx-context-auto)

## Best Practices

### Nonce management

:::important
Read the latest nonce before every transaction. If pipelining multiple operations, increment the nonce locally.
:::

```dart
// ❌ Wrong - stale nonce
final tx1 = await createTransaction(account.nonce);
final tx2 = await createTransaction(account.nonce);  // Fails!

// ✅ Correct - fresh nonce or manual increment
final accountState = await provider.getAccount(account.address);
final tx1 = await createTransaction(accountState.nonce);
final tx2 = await createTransaction(accountState.nonce + 1);
```

### Gas management

Use `simulateGas` for automatic estimation, or specify a `gasLimit` when you know the required gas. Only override `gasLimit` when protocol rules demand it.

### Error handling

Wrap network calls in `try/catch` and surface context in logs:

```dart
try {
  final tx = await provider.sendTransaction(transaction);
  print('Success: $tx');
} catch (e) {
  print('Transaction failed: $e');
}
```

### Resource cleanup

Close WebSocket streams and providers when finished:

```dart
await stream.close();
provider.close();
```

[comment]: # (mx-context-auto)

## Troubleshooting

| Symptom | Resolution |
| ------- | ---------- |
| `Transaction nonce mismatch` | Fetch current nonce just before signing |
| `Insufficient gas limit` | Switch to auto-gas or raise manual `GasLimit` |
| `ABI parsing error` | Rebuild ABI (`sc-meta all build`) and verify JSON path |
| WebSocket disconnects | Verify endpoint, API key, and connectivity; implement retries |

[comment]: # (mx-context-auto)

## Next Steps

If you prefer type-safe wrappers, continue with [CODEGEN_COOKBOOK.md](../generated/CODEGEN_COOKBOOK.md). Otherwise, explore the rest of `example/` and `test/` for additional manual patterns.
