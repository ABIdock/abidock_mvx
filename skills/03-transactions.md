---
name: transactions
title: Transaction Lifecycle
summary: Build, nonce, sign, broadcast and await a MultiversX transaction with abidock_mvx, including relayed v3 and every token-transfer shape.
reads: [07-network-providers.md]
verified_against: abidock_mvx 3.1.0 (Dart 3.13)
---

**When to use this**: you have to produce a `Transaction`, get it on-chain, and read the result.

Single import for everything below:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
```

Later snippets reuse identifiers introduced in §2 (`provider`, `sender`, `factory`, `receiver`, `txHash`, `watcher`) without re-declaring them.

---

## 1. `Transaction` — the exact constructor

`lib/src/core/transaction/transaction.dart:93`. `final class Transaction`, immutable.

| Parameter | Type | Required | Default |
|---|---|---|---|
| `nonce` | `Nonce` | yes | — |
| `sender` | `Address` | yes | — |
| `receiver` | `Address` | yes | — |
| `data` | `Uint8List` | yes | — |
| `gasLimit` | `GasLimit` | yes | — |
| `gasPrice` | `GasPrice` | yes | — |
| `chainId` | `ChainId` | yes | — |
| `version` | `TransactionVersion` | yes | — |
| `value` | `Balance?` | no | `Balance.zero()` |
| `senderUsername` | `String` | no | `''` |
| `receiverUsername` | `String` | no | `''` |
| `options` | `int` | no | `0` |
| `signature` | `Signature` | no | `const Signature.empty()` |
| `guardian` | `Address?` | no | `null` |
| `guardianSignature` | `Signature` | no | `const Signature.empty()` |
| `relayer` | `Address?` | no | `null` |
| `relayerSignature` | `Signature` | no | `const Signature.empty()` |

`data` is stored in a private field; the public read accessor is `Uint8List get data`, which returns a **copy** (`transaction.dart:176`). There is no setter — mutate through `copyWith`.

Every `copyWith` parameter is prefixed with `new`: `newNonce`, `newValue`, `newSender`, `newReceiver`, `newData`, `newSenderUsername`, `newReceiverUsername`, `newGasPrice`, `newGasLimit`, `newChainId`, `newVersion`, `newOptions`, `newSignature`, `newGuardian`, `newGuardianSignature`, `newRelayer`, `newRelayerSignature` (`transaction.dart:221`). Writing `copyWith(nonce: ...)` will not compile.

Other members: `toJson()` / `toSendable()` (same map), `serializeForSigning()`, `isGuardedTransaction`, `Transaction.fromJson(Map<String, dynamic>)`, `Transaction.newFromPlainObject(Map<String, dynamic>)`.

**`Transaction.innerTransactions` does not exist.** Relayed v3 is flat — see §7.

```dart
final Transaction tx = Transaction(
  nonce: const Nonce(7),
  sender: Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  ),
  receiver: Address.fromBech32(
    'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx',
  ),
  data: Uint8List.fromList(utf8.encode('hello')),
  gasLimit: const GasLimit(57500),
  gasPrice: const GasPrice(1000000000),
  chainId: const ChainId('D'),
  version: const TransactionVersion(2),
  value: Balance.fromEgld(1.5),
);

final Transaction reNonced = tx.copyWith(newNonce: const Nonce(8));

const TransactionComputer computer = TransactionComputer();
final String hash = computer.computeTransactionHash(tx);
```

(`dart:convert` and `dart:typed_data` are needed for `utf8` / `Uint8List`.)

Value-type constructors you will need: `Nonce(int)` / `const Nonce.zero()`, `GasLimit(int)`, `GasPrice(int)`, `ChainId(String)` / `.mainnet()` / `.devnet()` / `.testnet()`, `TransactionVersion(int)` (asserts `> 0`) / `TransactionVersion.validated(int)` (throws `ArgumentError`), `Balance.fromEgld(num)` / `Balance.fromEgldString(String)` / `Balance.fromString(String)` / `Balance(BigInt)` / `Balance.zero()`, `Signature.fromUint8List(Uint8List)` / `Signature.fromBytes(List<int>)` / `const Signature.empty()`.

**`value` is attoEGLD on the wire, and only the two `fromEgld*` constructors take whole EGLD.** `Balance(BigInt)`, `Balance.fromString(String)` and `Balance.fromNum(num)` take the atomic unit; `Balance.fromEgld(num)` and `Balance.fromEgldString(String)` take EGLD and scale by `10^18`. Both EGLD constructors are exact — `Balance.fromEgld(0.1).value` and `Balance.fromEgldString('0.1').value` are both `100000000000000000` (`lib/src/core/balance.dart:97,159`). Reach for `fromEgld` when the amount is a literal in your source and `fromEgldString` when it arrives as text; `fromEgld` throws `ArgumentError` rather than truncate if the amount needs more than 18 decimals (`balance.dart:345-354`).

### Wire payload

`TransactionComputer.toPlainObject` emits exactly these keys, in this order, and nothing else (`transaction_computer.dart:196`): `nonce`, `value`, `receiver`, `sender`, `senderUsername`?, `receiverUsername`?, `gasPrice`, `gasLimit`, `data`?, `chainID`, `version`, `options`?, `guardian`?, `relayer`?, then `signature`?, `guardianSignature`?, `relayerSignature`? when `withSignature: true`. The `?` keys are omitted when empty/zero/null. Adding a key of your own invalidates the signature.

---

## 2. The lifecycle

build → set nonce → sign → broadcast → await.

```dart
/// `pemText` is the contents of a wallet PEM file.
final ApiNetworkProvider provider = ApiNetworkProvider.devnet();
final Account sender = await Account.fromPem(pemText);

final TransferTransactionsFactory transfers = TransferTransactionsFactory(
  config: const TransferTransactionsConfig(chainId: ChainId('D')),
);

Transaction tx = transfers.createTransactionForNativeTokenTransfer(
  sender: sender.address,
  receiver: Address.fromBech32(
    'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx',
  ),
  nativeAmount: Balance.fromEgld(0.1),
);

final AccountOnNetwork onNetwork = await provider.getAccount(sender.address);
tx = tx.copyWith(newNonce: onNetwork.nonce);

tx = tx.copyWith(
  newSignature: Signature.fromUint8List(await sender.signTransaction(tx)),
);

final String txHash = await provider.sendTransaction(tx);

final TransactionWatcher watcher = TransactionWatcher(
  networkProvider: provider,
);
final TransactionOnNetwork result = await watcher.awaitCompleted(txHash);
provider.close();
```

Rules that will bite you otherwise:

- **Factories return nonce `0`.** Every `create...` on `TransferTransactionsFactory` builds with `nonce: const Nonce(0)`, `gasPrice: const GasPrice(1000000000)`, `version: const TransactionVersion(1)`, empty signature (`transfer_transactions_factory.dart:166`, `:278`, `:311`). You must `copyWith(newNonce: ...)` before signing.
- **Sign last.** `sender`, `receiver`, `value`, `data`, `gasLimit`, `gasPrice`, `chainId`, `version`, `options`, `guardian` and `relayer` are all inside the signed payload. Change any of them after signing and the chain rejects the transaction.
- **Controllers do the nonce + signing for you** (§8). Factories do not.
- `TransactionWatcher.close()` closes the **network provider** it was given (`transaction_watcher.dart:342`). Do not call it if you still need the provider.

---

## 3. Nonce management

`NonceManager` — `lib/src/core/transaction/nonce_manager.dart:53`. A per-address, in-memory counter that stays ahead of the network so back-to-back sends never collide.

Constructor: `NonceManager({required Address address, required NetworkProvider networkProvider, Duration resyncInterval = const Duration(minutes: 5)})`.

| Member | Signature | Behaviour (verified) |
|---|---|---|
| `next()` | `Future<Nonce>` | Reserves the next nonce. First call fetches `getAccount`. Released nonces are handed out first, lowest first (`nonce_manager.dart:85`). Calls are serialized. |
| `applyNonce(Nonce)` | `void` | Records a nonce as broadcast. Becomes the floor for `resync()`. |
| `release(Nonce)` | `void` | Returns an unused nonce. No-op if `<= highestApplied`. If it is the last reserved one the counter rewinds; otherwise it is queued for reuse. |
| `resync()` | `Future<void>` | Forces `getAccount` and moves the counter **forward only** (`nonce_manager.dart:154`). |
| `peek` | `int?` | Current local counter, `null` before the first sync. |
| `address` / `networkProvider` / `resyncInterval` | fields | As passed in. |

`resyncInterval: Duration.zero` disables the timed refresh. There is no `close()` / `dispose()`.

```dart
final NonceManager nonces = NonceManager(
  address: sender.address,
  networkProvider: provider,
);

final List<Transaction> batch = <Transaction>[];
for (int i = 0; i < 3; i++) {
  final Nonce nonce = await nonces.next();
  Transaction tx = factory
      .createTransactionForNativeTokenTransfer(
        sender: sender.address,
        receiver: receiver,
        nativeAmount: Balance.fromEgld(0.01),
      )
      .copyWith(newNonce: nonce);
  tx = tx.copyWith(
    newSignature: Signature.fromUint8List(await sender.signTransaction(tx)),
  );
  nonces.applyNonce(nonce);
  batch.add(tx);
}

final SendTransactionsResult result = await provider.sendTransactions(batch);
print(result.numSent);
for (final String? hash in result.txHashes) {
  print(hash);
}
```

`SendTransactionsResult` carries `int numSent`, `List<String?> txHashes` (one slot per input, `null` on failure) and `List<SendTxOutcome> outcomes` — a sealed hierarchy of `SendTxSuccess(index, hash)` / `SendTxFailure(index, {reason})`.

`Account` also has its own local counter (`Nonce nonce`, `incrementNonce()`, `getNonceThenIncrement()`), but it is not seeded from the network — `NonceManager` is.

---

## 4. Gas

### Composition rule

Factory-built transactions charge **data-movement gas + execution gas**:

```
gasLimit = minGasLimit + gasLimitPerByte * data.length   // data movement
         + <execution gas for this operation>            // execution
```

Defaults, from `TransactionsFactoryConfig` (`lib/src/core/transaction/transactions_factory_config.dart:34-35` — note this file sits one level **above** `factories/`): `minGasLimit = 50000`, `gasLimitPerByte = 1500`. The same two fields exist on the per-factory configs (`TransferTransactionsConfig` at `transfer_transactions_factory.dart:28-29`, `TokenManagementConfig`, …) with the same defaults.

Verified in code: `token_management_transactions_factory.dart:1254` computes `config.minGasLimit + config.gasLimitPerByte * dataPayload.length` and adds `executionGasLimit`; `smart_contract_transactions_factory.dart:128`; `transfer_transactions_factory.dart:413`. Pinned by `test/core/transaction/factories/factory_data_movement_gas_test.dart` (e.g. a fungible `issue` with a 243-byte data field costs `60414500 = 50000 + 1500*243 + 60000000`).

Execution-gas constants live on `TransactionsFactoryConfig` — a few of the ones you will meet: `gasLimitIssue = 60000000`, `gasLimitSetSpecialRole = 60000000`, `gasLimitEsdtTransfer = 200000`, `gasLimitEsdtNftTransfer = 200000`, `gasLimitMultiEsdtNftTransfer = 200000`, `gasLimitSetGuardian = 250000`, `gasLimitEsdtNftCreate = 3000000`, `extraGasLimitForGuardedTransactions = 50000`, `extraGasLimitForRelayedTransactions = 50000`.

Transfer-specific extras (`transfer_transactions_factory.dart:10`): `additionalGasForEsdtTransfer = 100000`, `additionalGasForEsdtNftTransfer = 800000`. A single fungible ESDT transfer therefore costs `50000 + 1500*len + 200000 + 100000`.

Loose top-level constants (`lib/src/core/network_configuration.dart`): `defaultMinGasLimit = 50000`, `defaultGasPerDataByte = 1500`, `defaultMinGasPrice = 1000000000`.

### When to pass an explicit gas limit

Pass one when the factory cannot know the cost:

- any smart-contract call, where execution gas depends on the contract;
- multi-transfers whose destination is a contract endpoint;
- anything you have measured and want to pin.

Every transfer factory method takes `GasLimit? gasLimit`; when non-null it **replaces** the whole computation, it is not added (`transfer_transactions_factory.dart:163`, `:272`, `:308`). Controllers take `BaseControllerInput(gasLimit: ...)`, which sets the execution budget outright and skips estimation (`base_controller.dart:369-374`) — the guardian and relayer allowances are still added on top of it (`:405`). So the number you pass is the execution budget, not necessarily the final `gasLimit` field.

### Estimating instead

`GasEstimator implements IGasLimitEstimator` (`gas_models/gas_estimator.dart:14`):
`GasEstimator({required NetworkProvider networkProvider, double gasMultiplier = 1.1, Logger? logger})`.

- `Future<GasLimit> estimate(Transaction)` — simulates via `networkProvider.estimateTransactionCost`, multiplies by `gasMultiplier`, `.floor()`.
- `Future<int> estimateGasLimit({required Transaction transaction})` — the `IGasLimitEstimator` method.
- `Future<List<GasLimit>> estimateBatchGasLimits(List<Transaction>)` — sequential.
- `Future<GasEstimationResult> estimateGasLimitWithConfidence(Transaction)` — `{GasLimit gasLimit, double confidence}`.

```dart
final Map<String, dynamic> cost = await provider.estimateTransactionCost(draft);
print(cost['gasLimit']);
print(cost['returnMessage']);
print(cost['status']);

final GasEstimator estimator = GasEstimator(
  networkProvider: provider,
  gasMultiplier: 1.1,
);
final GasLimit estimated = await estimator.estimate(draft);

const TransactionComputer computer = TransactionComputer();
final BigInt fee = computer.computeTransactionFee(
  draft,
  NetworkConfiguration.devnet(),
);
```

`computeTransactionFee(Transaction, NetworkConfiguration)` throws `ArgumentError` when `gasLimit` is below the move-balance floor (`transaction_computer.dart:334`). Note `NetworkConfiguration` (local presets, `lib/src/core/network_configuration.dart`) is a different type from `NetworkConfig` (fetched from the chain).

---

## 5. Awaiting

### `TransactionWatcher`

`TransactionWatcher({required NetworkProvider networkProvider})` (`transaction_watcher.dart:143`).

| Method | Signature |
|---|---|
| `awaitCompleted` | `Future<TransactionOnNetwork> awaitCompleted(String txHash, {TransactionAwaitingOptions options = const TransactionAwaitingOptions()})` |
| `awaitOnCondition` | `Future<TransactionOnNetwork> awaitOnCondition(String txHash, bool Function(TransactionStatus status) predicate, {TransactionAwaitingOptions options = const TransactionAwaitingOptions()})` |
| `fetchTransaction` | `Future<TransactionOnNetwork> fetchTransaction(String txHash)` |
| `isCompleted` | `Future<bool> isCompleted(String txHash)` — one fetch, then `TransactionOnNetwork.isCompleted`, i.e. `status.isCompleted` (`transaction_watcher.dart:318-322`); swallows errors and returns `false`. It is not the loop predicate — `awaitCompleted` stops on `isFinal` (see §6) |
| `close` | `void close()` — closes the **provider** |

`TransactionAwaitingOptions` defaults (`transaction_watcher.dart:54`, pinned by `test/core/transaction/transaction_watcher_defaults_test.dart`):

| Field | Type | Default |
|---|---|---|
| `timeout` | `Duration` | `Duration(seconds: 9)` |
| `pollingInterval` | `Duration` | `Duration(milliseconds: 600)` |
| `patience` | `Duration` | `Duration.zero` |
| `maxConsecutiveErrors` | `int` | `5` |
| `awaitCrossShardCompletion` | `bool` | `false` |
| `numShards` | `int?` | `null` |
| `roundDuration` | `Duration?` | `null` |

9 s is exactly 15 polling intervals. **It is short.** Raise `timeout` for anything cross-shard.

What "completed" means here: `awaitCompleted` waits for `status.isFinal`, i.e. `isExecuted || isFailed || isNotExecutableInBlock` (`transaction_watcher.dart:192`, `transaction_status.dart:175`). That is a terminal *status*, not "all cross-shard results have landed". For that set `awaitCrossShardCompletion: true`, which additionally requires a log event named `completedTxEvent`, `SCDeploy` or `signalError` (`transaction_watcher.dart:329`).

When both `numShards` and `roundDuration` are set, the effective timeout becomes `max(timeout, roundDuration * (numShards + 1) * 3)` (`transaction_watcher.dart:245`).

On error the watcher backs off exponentially (`pollingInterval * 2^(n-1)`) and throws `TransactionWatcherException` after `maxConsecutiveErrors` consecutive failures; on expiry it throws `TransactionWatcherTimeoutException`.

```dart
const TransactionAwaitingOptions options = TransactionAwaitingOptions(
  timeout: Duration(seconds: 60),
  pollingInterval: Duration(seconds: 1),
  patience: Duration(seconds: 2),
  maxConsecutiveErrors: 5,
  awaitCrossShardCompletion: true,
  numShards: 3,
  roundDuration: Duration(milliseconds: 600),
);

final TransactionOnNetwork done = await watcher.awaitCompleted(
  txHash,
  options: options,
);

final TransactionOnNetwork inBlock = await watcher.awaitOnCondition(
  txHash,
  (TransactionStatus status) => status.isExecuted,
);
```

`ApiNetworkProvider` has two shortcuts that build a watcher with default options: `awaitTransactionCompleted(String)` and `awaitTransactionOnCondition(String, bool Function(TransactionStatus))` (`api_network_provider.dart:116`, `:129`). They are not on `GatewayNetworkProvider` and not on the `NetworkProvider` interface.

### `AccountAwaiter`

`AccountAwaiter({required NetworkProvider networkProvider})` (`account_awaiter.dart:48`). Use it when you care that the sender's nonce moved rather than about a specific hash.

| Method | Signature |
|---|---|
| `awaitOnCondition` | `Future<AccountOnNetwork> awaitOnCondition(Address address, bool Function(AccountOnNetwork) condition, {AccountAwaitingOptions? options})` |
| `awaitNonceIncrement` | `Future<AccountOnNetwork> awaitNonceIncrement(Address address, Nonce currentNonce, {AccountAwaitingOptions? options})` |
| `awaitMinimumBalance` | `Future<AccountOnNetwork> awaitMinimumBalance(Address address, Balance targetBalance, {AccountAwaitingOptions? options})` |
| `awaitBalanceChange` | `Future<AccountOnNetwork> awaitBalanceChange(Address address, Balance currentBalance, {AccountAwaitingOptions? options})` |

`AccountAwaitingOptions` (`account_awaiter.dart:24`) has the same four defaults as the watcher: `timeout: Duration(seconds: 9)`, `pollingInterval: Duration(milliseconds: 600)`, `patience: Duration.zero`, `maxConsecutiveErrors: 5`. Throws `AccountAwaiterTimeoutException` / `AccountAwaiterException`.

```dart
final AccountAwaiter awaiter = AccountAwaiter(networkProvider: provider);
final AccountOnNetwork account = await awaiter.awaitNonceIncrement(
  Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  ),
  const Nonce(41),
  options: const AccountAwaitingOptions(
    timeout: Duration(seconds: 30),
    pollingInterval: Duration(milliseconds: 600),
  ),
);
```

---

## 6. Reading `TransactionOnNetwork`

`lib/src/core/transaction/transaction_on_network.dart:38`. Built by the providers via `TransactionOnNetwork.fromApiResponse` (API) or `.fromProxyResponse` (Gateway) — the two differ in whether SCR/event payloads are base64 or plain, so never feed a gateway body to the API factory.

### Fields you will actually read

| Member | Type | Notes |
|---|---|---|
| `txHash` | `String` | required |
| `status` | `TransactionStatus` | required |
| `transaction` | `Transaction` | the reconstructed original |
| `sender` / `receiver` / `value` / `nonce` | `Address` / `Address` / `Balance` / `Nonce` | shortcuts onto `transaction` |
| `data` | `dynamic` | shortcut onto `transaction.data` (a `Uint8List` at runtime, typed `dynamic`) |
| `blockNonce`, `hyperblockNonce`, `round`, `epoch` | `int?` | |
| `blockHash`, `hyperblockHash`, `miniBlockHash` | `String?` | |
| `senderShard`, `receiverShard` | `int?` | |
| `gasUsed` | `int?` | |
| `fee`, `initiallyPaidFee` | `String?` | atomic units as strings |
| `function` | `String?` | |
| `smartContractResults` | `List<SmartContractResult>?` | typed, already decoded |
| `logs` | `TransactionLogs?` | `.address`, `.events` |
| `isRelayed` | `bool?` | |
| `relayer`, `relayerSignature` | `String?` | bech32 / hex, **not** `Address` |
| `relayedVersion` | `String?` | `'v1'` / `'v2'` / `'v3'`, `null` when not relayed. It is a `String?` — never an enum or int |
| `guardianAddress`, `guardianSignature` | `String?` | |
| `timestamp`, `timestampMs`, `completedAt` | `int?` | see the hazard below |
| `searchOrder` | `int?` | Supernova ordering index |
| `miniBlockType` | `String?` | from the node's `miniblockType` spelling |
| `type`, `originalTxHash`, `pendingResults`, `isScCall`, `action`, `operations`, `scamInfo`, `price`, `senderAssets`, `receiverAssets` | assorted | API-only enrichments |

`SmartContractResult` fields: `hash`, `nonce`, `value` (`String`), `sender`, `receiver` (`Address`), `data` (`Uint8List`), `returnCode` (`ReturnCode`, read `.code` / `.message` — there is no `.value`), `returnData` (`List<Uint8List>`), `previousHash`, `originalHash`, `gasLimit`, `gasPrice`, `callType`, `errorMessage`, `logs`, `raw`.

`TransactionEvent` fields: `address` (`Address`), `identifier` (`String`), `topics` (`List<Uint8List>`), `data` (`Uint8List`), `additionalData` (`List<Uint8List>`), `order` (`int`), `addressAssets`, `raw`.

### Status

Getters on `TransactionOnNetwork` (`transaction_on_network.dart:698`+):

| Getter | Delegates to |
|---|---|
| `isSuccessful` | `status.isSuccessful` (`:760`) |
| `isPending` | `status.isPending` (`:796`) |
| `hasFailed` | `status.isFailed` (`:781`) — **there is no `isFailed` on `TransactionOnNetwork`** |
| `isCompleted` | `status.isCompleted` (`:703`) |
| `isFinal` | `status.isFinal` (`:723`) |
| `isInBlock` | `blockNonce != null` (`:810`) |

Every one of these forwards to the identically-named getter on `status`, so
`tx.isCompleted` and `tx.status.isCompleted` always answer the same, and so do
`tx.isFinal` and `tx.status.isFinal`. Read whichever object you already hold.

Getters on `TransactionStatus` (`transaction_status.dart`), all case-insensitive on the raw string:

| Getter | True for |
|---|---|
| `isPending` | `pending`, `received` |
| `isExecuted` | `executed`, `success`, `successful` |
| `isSuccessful` | same as `isExecuted` |
| `isFailed` | `fail`, `failed`, `unsuccessful`, `invalid` |
| `isInvalid` | `invalid` |
| `isNotExecutableInBlock` | `not-executable-in-block` |
| `isFinal` | `isExecuted \|\| isFailed \|\| isNotExecutableInBlock` (`transaction_status.dart:175`) |
| `isCompleted` | `isExecuted \|\| isFailed` (`transaction_status.dart:189`) |

Constants: `TransactionStatus.pending/received/executed/success/successful/fail/failed/unsuccessful/invalid/notExecutableInBlock/rewardReverted/unknown`. Raw string is `.status`.
**`TransactionStatus.recalled` and `isRecalled` were removed in 3.0.0 — do not reference them.**

#### `isCompleted` vs `isFinal` — two questions, one answer each

The pair differ by exactly one status, `not-executable-in-block`: a transaction
that appeared in a proposed block but was absent from that block's execution
result. It carries no logs and no smart contract results, and its status will
not change again.

| You want to know | Getter | `not-executable-in-block` |
|---|---|---|
| "did the chain produce an outcome I can read?" | `isCompleted` | `false` |
| "will the status change again — can I stop polling?" | `isFinal` | `true` |

`isFinal` is the wider predicate and the one a polling loop must use;
`awaitCompleted` uses it (`transaction_watcher.dart:192`). Both spellings of each
getter agree, so `tx.isCompleted`, `tx.status.isCompleted` and
`await watcher.isCompleted(hash)` all mean "executed or failed". Pinned by
`test/core/transaction/transaction_status_supernova_test.dart:221-234`, the group
named *"not-executable-in-block is final but not completed"*.

### Timestamps — the seconds/milliseconds hazard

At the Supernova epoch the chain switched several timestamp fields from seconds to milliseconds **without renaming them**, and the unit differs per route: the Gateway `/transaction/:hash` route reports `timestamp` in milliseconds once Supernova is active, while the block routes and the public API keep reporting seconds (`transaction_on_network.dart:536`).

- `timestamp` — raw, unit unknown. Do not multiply it by anything.
- `timestampMs` — present only when the provider emitted `timestampMs`.
- **`executedAt` → `DateTime?` — use this.** It prefers `timestampMs`, falls back to `timestamp`, and decides the unit by magnitude through `ChainTimestamp` (`transaction_on_network.dart:566`).

`ChainTimestamp` (`lib/src/infrastructure/network/network_status.dart:13`): `static const int millisecondThreshold = 100000000000`; `static int? toMilliseconds(int?)`; `static DateTime? toDateTime(int?)`. Both return `null` for `null` **and for `0`**. Values `>= millisecondThreshold` are read as milliseconds, everything else as seconds. The same normalisation backs `NetworkStatus.blockTime`.

```dart
final TransactionOnNetwork tx = await provider.getTransaction(txHash);

if (tx.isSuccessful) {
  print('block ${tx.blockNonce}, gasUsed ${tx.gasUsed}, fee ${tx.fee}');
} else if (tx.hasFailed) {
  print('failed: ${tx.status.status}');
} else if (tx.isPending) {
  print('still pending');
}

final DateTime? at = tx.executedAt;

for (final SmartContractResult scr in tx.smartContractResults ?? const []) {
  print('${scr.returnCode.code} ${scr.returnData.length} ${scr.errorMessage}');
}

final TransactionLogs? logs = tx.logs;
if (logs != null) {
  for (final TransactionEvent event in logs.events) {
    print('${event.identifier} @ ${event.address.bech32}');
  }
}
```

---

## 7. Relayed v3

**A relayed-v3 transaction is one flat transaction.** It is the user's own transaction with two extra fields, `relayer` (an `Address`) and `relayerSignature` (a `Signature`). There is no outer wrapper, no inner-transaction list, no `createRelayedTransaction` helper, and no `Transaction.innerTransactions` field. Pinned by `test/core/transaction/factories/relayed_transactions_factory_test.dart:74` ("produces a flat transaction without inner transactions").

Three steps, in this order:

1. `RelayedTransactionsFactory.applyRelayer(tx, relayerAddress, {int numberOfShards = 3})` on the **unsigned** transaction.
2. Sender signs: `tx.signWith(userSigner)`.
3. Relayer signs: `tx.signAsRelayer(relayerSigner, {int numberOfShards = 3})`.

Both parties sign the identical serialized payload, so steps 2 and 3 may be swapped (`relayed_transactions_factory_test.dart:146`).

`RelayedTransactionsFactory(RelayedTransactionsConfig config)` — positional, not named. `RelayedTransactionsConfig({required ChainId chainId, int extraGasLimitForRelayedTransactions = 50000, int defaultGasPrice = 1000000000})`, plus `RelayedTransactionsConfig.fromShared(TransactionsFactoryConfig)`.

`applyRelayer` (`relayed_transactions_factory.dart:87`) returns a copy with `relayer` set, `version` raised to at least 2, and `extraGasLimitForRelayedTransactions` added to the gas limit — added only once, so re-applying the same relayer is idempotent. It throws:

- `ArgumentError` if any signature (sender, relayer or guardian) is already present;
- `ArgumentError` if `transaction.chainId` differs from the config's;
- `ArgumentError` if `relayer == guardian`;
- `ArgumentError` if relayer and sender are in different shards;
- `StateError` if a *different* relayer is already set.

```dart
final UserSigner senderSigner = UserSigner.fromPem(senderPem);
final UserSigner relayerSigner = UserSigner.fromPem(relayerPem);
final Address senderAddress = await senderSigner.getAddress();
final Address relayerAddress = await relayerSigner.getAddress();

final TransferTransactionsFactory transfers = TransferTransactionsFactory(
  config: const TransferTransactionsConfig(chainId: ChainId('D')),
);
Transaction tx = transfers.createTransactionForNativeTokenTransfer(
  sender: senderAddress,
  receiver: Address.fromBech32(
    'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx',
  ),
  nativeAmount: Balance.fromEgld(0.1),
);

final AccountOnNetwork account = await provider.getAccount(senderAddress);
tx = tx.copyWith(newNonce: account.nonce);

final RelayedTransactionsFactory relayedFactory = RelayedTransactionsFactory(
  const RelayedTransactionsConfig(chainId: ChainId('D')),
);
tx = relayedFactory.applyRelayer(tx, relayerAddress);

tx = await tx.signWith(senderSigner);
tx = await tx.signAsRelayer(relayerSigner);

final String txHash = await provider.sendTransaction(tx);
```

Signing extensions on `Transaction` (`lib/src/abi/extensions/transaction_signing_extensions.dart`):

| Member | Signature |
|---|---|
| `signWith` | `Future<Transaction> signWith(UserSigner signer)` |
| `signAsRelayer` | `Future<Transaction> signAsRelayer(UserSigner relayerSigner, {int numberOfShards = 3})` — throws `TransactionException` if `relayer` is unset or in another shard |
| `signAsGuardian` | `Future<Transaction> signAsGuardian(UserSigner guardianSigner)` — throws `TransactionException` if `guardian` is unset |
| `isRelayedTransaction` | `bool` — `relayer != null && !relayer!.isEmpty` |
| `isFullySigned` | `bool` |
| `missingSignatures` | `List<String>` — subset of `['user', 'relayer', 'guardian']` |

Do **not** stack the two relayer paths. `BaseController.setupAndSignTransaction` already adds 50 000 gas when `BaseControllerInput.relayer` is set (`base_controller.dart:136-137`), and `applyRelayer` adds 50 000 too. Use either the controller's `relayer` option or the relayed factory, not both on the same transaction.

`TransactionComputer.isRelayedV3Transaction(tx)` is simply `tx.relayer != null`.

---

## 8. Transfers

### Factory — `TransferTransactionsFactory`

`TransferTransactionsFactory({required TransferTransactionsConfig config})`.
`TransferTransactionsConfig({required ChainId chainId, int minGasLimit = 50000, int gasLimitPerByte = 1500, int gasLimitEsdtTransfer = 200000, int gasLimitEsdtNftTransfer = 200000, int gasLimitMultiEsdtNftTransfer = 200000})`, plus `TransferTransactionsConfig.fromShared(TransactionsFactoryConfig)`.

| Method | Signature |
|---|---|
| EGLD | `Transaction createTransactionForNativeTokenTransfer({required Address sender, required Address receiver, required Balance nativeAmount, Uint8List? data, GasLimit? gasLimit})` |
| ESDT / NFT / multi | `Transaction createTransactionForEsdtTransfer({required Address sender, required Address receiver, required List<TokenTransfer> tokenTransfers, GasLimit? gasLimit})` |
| either | `Transaction createTransactionForTransfer({required Address sender, required Address receiver, Balance? nativeAmount, List<TokenTransfer>? tokenTransfers, Uint8List? data, GasLimit? gasLimit})` |

`createTransactionForEsdtTransfer` throws `ArgumentError('No token transfers provided')` on an empty list, and dispatches on the list itself (`transfer_transactions_factory.dart:194`):

| Payload | Wire form | `receiver` field of the transaction |
|---|---|---|
| one fungible ESDT | `ESDTTransfer` | the actual receiver |
| one NFT/SFT (nonce > 0) | `ESDTNFTTransfer` | **the sender** |
| one EGLD entry | `MultiESDTNFTTransfer` | **the sender** |
| two or more | `MultiESDTNFTTransfer` | **the sender** |

That receiver rewrite is protocol-correct — the built-in function is addressed to the sender's own account and carries the destination inside the data field. Do not "fix" it.

`TokenTransfer` constructors (`transfer_transactions_factory.dart:63`):

- `const TokenTransfer({required String tokenIdentifier, required BigInt amount, int nonce = 0})`
- `TokenTransfer.fungible({required String tokenIdentifier, required BigInt amount})`
- `TokenTransfer.nonFungible({required String tokenIdentifier, required int nonce, required BigInt amount})`
- `TokenTransfer.egld(BigInt amount)` — positional
- getters `isFungible` (`nonce == 0`), `isNonFungible`, `isEgld`, `baseIdentifier`

`const String egldIdentifierForMultiTransfer = 'EGLD-000000'` — the sentinel used for native EGLD inside a multi-transfer. Sending a bare `EGLD` is invalid on-chain; the constant is pinned by `test/core/transaction/factories/egld_sentinel_pinning_test.dart`.

```dart
final Transaction esdt = factory.createTransactionForEsdtTransfer(
  sender: sender,
  receiver: receiver,
  tokenTransfers: <TokenTransfer>[
    TokenTransfer.fungible(
      tokenIdentifier: 'TEST-38f249',
      amount: BigInt.from(1000000),
    ),
  ],
);

final Transaction nft = factory.createTransactionForEsdtTransfer(
  sender: sender,
  receiver: receiver,
  tokenTransfers: <TokenTransfer>[
    TokenTransfer.nonFungible(
      tokenIdentifier: 'NFT-123456',
      nonce: 1,
      amount: BigInt.one,
    ),
  ],
);

final Transaction multi = factory.createTransactionForEsdtTransfer(
  sender: sender,
  receiver: receiver,
  tokenTransfers: <TokenTransfer>[
    TokenTransfer.fungible(
      tokenIdentifier: 'TEST-38f249',
      amount: BigInt.from(500),
    ),
    TokenTransfer.nonFungible(
      tokenIdentifier: 'NFT-123456',
      nonce: 1,
      amount: BigInt.one,
    ),
    TokenTransfer.egld(BigInt.from(10).pow(17)),
  ],
  gasLimit: const GasLimit(5000000),
);
```

`createTransactionForTransfer` is the "either" method: it dispatches on what you actually supplied (`transfer_transactions_factory.dart:263-299`).

| You pass | Branch taken |
|---|---|
| a positive `nativeAmount`, no `tokenTransfers` | native EGLD transfer (`:278-286`) |
| a non-empty `data`, no `tokenTransfers` | native EGLD transfer, memo included — `nativeAmount` may be zero |
| `tokenTransfers` only | `createTransactionForEsdtTransfer` (`:293-298`) |
| both `nativeAmount` and `tokenTransfers` | ESDT transfer with the EGLD appended as a `TokenTransfer.egld` leg (`:288-291`) |
| nothing at all | ESDT branch on an empty list → `ArgumentError('No token transfers provided')` (`:201`) |

An empty `data` — `Uint8List(0)` as well as `null` — counts as no data (`:273`), so passing `data: Uint8List(0)` alongside tokens still sends the tokens. A **non-empty** `data` together with a non-empty `tokenTransfers` is a genuine conflict and throws `ArgumentError('Cannot set data field when sending ESDT tokens')` (`:275-277`): the ESDT branch needs the data field for the built-in function call, so it cannot also carry a memo.

### Controller — `TransfersController`

`TransfersController({required ChainId chainId, IGasLimitEstimator? gasLimitEstimator})`. It builds its own `TransferTransactionsFactory` (exposed as `.factory`) and returns a **signed** transaction: it applies guardian/relayer, sets version/options for a guardian, resolves gas, and signs with the account you pass.

All three methods take `(IAccount sender, Nonce nonce, <input> options, {BaseControllerInput? baseOptions})` — positional sender/nonce/options, named `baseOptions`:

| Method | Options type |
|---|---|
| `Future<Transaction> createTransactionForNativeTransfer` | `NativeTransferInput({required Address receiver, required Balance amount, Uint8List? data})` |
| `Future<Transaction> createTransactionForTokenTransfer` | `TokenTransferInput({required Address receiver, required List<TokenTransfer> transfers})` |
| `Future<Transaction> createTransactionForMultiTokenTransfer` | `TokenTransferInput` — delegates verbatim to `createTransactionForTokenTransfer` |

`BaseControllerInput({Address? guardian, Address? relayer, GasPrice? gasPrice, GasLimit? gasLimit})`.

```dart
final TransfersController controller = TransfersController(
  chainId: const ChainId('D'),
  gasLimitEstimator: GasEstimator(networkProvider: provider),
);

final Nonce nonce = (await provider.getAccount(sender.address)).nonce;

final Transaction egldTx = await controller.createTransactionForNativeTransfer(
  sender,
  nonce,
  NativeTransferInput(
    receiver: Address.fromBech32(
      'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx',
    ),
    amount: Balance.fromEgld(0.1),
    data: Uint8List.fromList(utf8.encode('memo')),
  ),
);

final Transaction tokenTx = await controller.createTransactionForTokenTransfer(
  sender,
  Nonce(nonce.value + 1),
  TokenTransferInput(
    receiver: Address.fromBech32(
      'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx',
    ),
    transfers: <TokenTransfer>[
      TokenTransfer.fungible(
        tokenIdentifier: 'TEST-38f249',
        amount: BigInt.from(1000),
      ),
    ],
  ),
  baseOptions: const BaseControllerInput(gasLimit: GasLimit(600000)),
);
```

Gas resolution inside the controller (`setTransactionGasOptions`, `base_controller.dart:343-406`), in order:
1. `baseOptions.gasPrice` overrides the gas price if set (`:361-367`).
2. The execution budget is chosen once, first match wins (`:369-403`):
   - `baseOptions.gasLimit` if you passed one — estimation is skipped;
   - else the `gasLimitEstimator`, if one is wired. If it throws, the drafted limit is kept (a warning is logged, nothing is rethrown);
   - else the limit the factory drafted.
3. `addExtraGasLimitIfRequired` then adds 50 000 for a guardian and 50 000 for a relayer, on top of whichever budget step 2 produced (`:405`, `:119-150`). Both allowances apply when the transaction is guarded *and* relayed.

So `BaseControllerInput(gasLimit: GasLimit(600000))` on a guarded transaction broadcasts with `gasLimit == 650000`.

A guardian on the transaction also forces `version >= 2` and ORs `options` with `0x02` (`base_controller.dart:257`). Option-bit constants: `transactionOptionsDefault = 0`, `transactionOptionsTxHashSign = 1`, `transactionOptionsTxGuarded = 2`, `minTransactionVersionThatSupportsOptions = 2`.

---

## 9. Removed in 3.0.0 — never emit these

`SignableMessage`, `ValidatorSigner(secretKey)`, `ValidatorSigner.fromPem`, `TransactionStatus.recalled` / `isRecalled`, `NetworkConfig.gasPriceModifierString`, `functionCallHexParts`, `createRelayedTransaction`, `createTransactionForDelegatingVote`, `createTransactionForUnsettingBurnRoleForAll`, `Transaction.innerTransactions`. None of these identifiers exists anywhere under `lib/` in 3.1.0 (verified by grep). `relayedVersion` is a `String?`.

---

## Not verified

- The exact behaviour of `TransactionWatcher` and `AccountAwaiter` against a live node (timeout/backoff paths were read from source, not exercised).
- Whether the `GasEstimator.gasMultiplier` default of 1.1 is sufficient for any particular contract.
- Guardian (2FA) end-to-end flow beyond the field/option mechanics quoted above.
