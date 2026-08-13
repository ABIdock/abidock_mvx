---
name: quickstart
title: Quickstart
summary: After reading this an agent can install abidock_mvx, build a signed EGLD transfer, broadcast it and await the result, without guessing a single symbol name.
reads: [01-public-api.md]
verified_against: abidock_mvx 3.1.0 (Dart 3.13)
---

**When to use this** — first contact with the package: you need a working
transaction on the MultiversX chain and you have no prior knowledge of the API.

## 1. Install

`pubspec.yaml` of the consuming project (version at `pubspec.yaml:3`, SDK floor
at `pubspec.yaml:10`):

```yaml
environment:
  sdk: ^3.13.0

dependencies:
  abidock_mvx: ^3.1.0
```

## 2. The single import

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
```

That one barrel re-exports the six subsystem barrels — `abi`, `core`,
`entrypoints`, `infrastructure`, `utils`, `wallet` (`lib/abidock_mvx.dart:5-10`).
`lib/abidock_mvx.dart` is the package's only public entry point; **never import
a `package:abidock_mvx/src/...` path.** The full symbol list is in
`01-public-api.md`.

## 3. Mental model

```
NetworkEntrypoint      picks URL + ChainId, caches one NetworkProvider
  -> NetworkProvider   reads chain state, broadcasts transactions
  -> Factory           builds an UNSIGNED Transaction (nonce 0, empty signature)
  -> Controller        wraps a factory: sets nonce/gas/version AND signs
  -> Account           holds the secret key, produces the signature
  -> provider.sendTransaction(tx)   returns the transaction hash (String)
  -> TransactionWatcher.awaitCompleted(hash) -> TransactionOnNetwork
```

Two build paths, pick one:

| Path | Returns | Use when |
|---|---|---|
| `*TransactionsFactory.createTransactionFor*(...)` | unsigned `Transaction`, `nonce == Nonce(0)`, `signature.isEmpty == true` | you sign/broadcast yourself, or you need the draft for gas simulation |
| `*Controller.createTransactionFor*(account, nonce, input)` | signed `Transaction` | normal case |

Verified in `lib/src/core/transaction/factories/transfer_transactions_factory.dart:166-177`
(factory draft) and `lib/src/core/transaction/controllers/base_controller.dart:181-215`
(controller sets nonce/version/gas, then signs).

## 4. Complete end-to-end example

Compiles clean under `dart analyze`.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  /// 1. Entrypoint: URL + chain id in one object.
  final entrypoint = DevnetEntrypoint();
  final provider = entrypoint.createNetworkProvider();

  /// 2. Load the signing account.
  final account = await Account.fromMnemonic(
    'moral volcano peasant talk indicate electric select man money speak '
    'country exclude parent book gain pen fine fruit sun bench truly muscle '
    'guitar armed',
  );

  /// 3. Read the on-chain nonce and copy it onto the account.
  final onNetwork = await provider.getAccount(account.address);
  account.nonce = onNetwork.nonce;

  /// 4. Build + sign through a controller.
  final controller = TransfersController(chainId: const ChainId.devnet());
  final tx = await controller.createTransactionForNativeTransfer(
    account,
    account.getNonceThenIncrement(),
    NativeTransferInput(
      receiver: Address.fromBech32(
        'erd1cux02zersde0l7hhklzhywcxk4u9n4py5tdxyx7vrvhnza2r4gmq4vw35r',
      ),
      /// Whole EGLD; the attoEGLD integer is exact — see §5(b).
      amount: Balance.fromEgld(0.1),
    ),
  );

  /// 5. Broadcast and wait for a final status.
  final hash = await provider.sendTransaction(tx);
  final watcher = entrypoint.createTransactionWatcher();
  try {
    final completed = await watcher.awaitCompleted(hash);
    print('${completed.status.status} at ${completed.executedAt}');
  } finally {
    watcher.close();
  }
}
```

### Exact signatures used above

| Symbol | Signature | Declared at |
|---|---|---|
| `DevnetEntrypoint` | `DevnetEntrypoint({NetworkProviderConfig? networkProviderConfig, String? clientName, IGasLimitEstimator? gasLimitEstimator})` | `lib/src/entrypoints/network_entrypoint.dart:223` |
| `NetworkEntrypoint.createNetworkProvider` | `ApiNetworkProvider createNetworkProvider()` (returns one cached instance) | `lib/src/entrypoints/network_entrypoint.dart:110` |
| `NetworkEntrypoint.createTransactionWatcher` | `TransactionWatcher createTransactionWatcher()` | `lib/src/entrypoints/network_entrypoint.dart:181` |
| `Account.fromMnemonic` | `static Future<Account> fromMnemonic(String mnemonic, {int addressIndex = 0})` | `lib/src/core/account/account.dart:93` |
| `Account.fromPem` | `static Future<Account> fromPem(String pemContent, {int index = 0})` | `lib/src/core/account/account.dart:51` |
| `Account.fromKeystore` | `static Future<Account> fromKeystore(String keystoreJson, String password, {int? addressIndex})` | `lib/src/core/account/account.dart:126` |
| `Account.fromSecretKey` | `static Future<Account> fromSecretKey(UserSecretKey secretKey)` | `lib/src/core/account/account.dart:71` |
| `NetworkProvider.getAccount` | `Future<AccountOnNetwork> getAccount(Address address)` | `lib/src/infrastructure/network/network_provider.dart:121` |
| `Account.getNonceThenIncrement` | `Nonce getNonceThenIncrement()` | `lib/src/core/account/account.dart:179` |
| `TransfersController` | `TransfersController({required ChainId chainId, IGasLimitEstimator? gasLimitEstimator})` | `lib/src/core/transaction/controllers/transfers_controller.dart:119` |
| `createTransactionForNativeTransfer` | `Future<Transaction> createTransactionForNativeTransfer(IAccount sender, Nonce nonce, NativeTransferInput options, {BaseControllerInput? baseOptions})` | `lib/src/core/transaction/controllers/transfers_controller.dart:151` |
| `NativeTransferInput` | `const NativeTransferInput({required Address receiver, required Balance amount, Uint8List? data})` | `lib/src/core/transaction/controllers/transfers_controller.dart:31` |
| `NetworkProvider.sendTransaction` | `Future<String> sendTransaction(Transaction tx)` — returns the hash | `lib/src/infrastructure/network/network_provider.dart:170` |
| `TransactionWatcher.awaitCompleted` | `Future<TransactionOnNetwork> awaitCompleted(String txHash, {TransactionAwaitingOptions options = const TransactionAwaitingOptions()})` | `lib/src/core/transaction/transaction_watcher.dart:186` |

Note the **positional** argument order on controller methods: `(account, nonce,
input)` — the input object is third and positional, only `baseOptions` is named.

### Picking an entrypoint

| Class | Backing host | Constant |
|---|---|---|
| `DevnetEntrypoint` | `https://devnet-api.multiversx.com` | `EntrypointUrls.devnet` |
| `TestnetEntrypoint` | `https://testnet-api.multiversx.com` | `EntrypointUrls.testnet` |
| `MainnetEntrypoint` | `https://api.multiversx.com` | `EntrypointUrls.mainnet` |
| `DevnetProxyEntrypoint` | `https://devnet-gateway.multiversx.com` | `EntrypointUrls.devnetGateway` |
| `TestnetProxyEntrypoint` | `https://testnet-gateway.multiversx.com` | `EntrypointUrls.testnetGateway` |
| `MainnetProxyEntrypoint` | `https://gateway.multiversx.com` | `EntrypointUrls.mainnetGateway` |

Values at `lib/src/entrypoints/network_entrypoint.dart:26-41`. The `*Entrypoint`
family builds an `ApiNetworkProvider`; the `*ProxyEntrypoint` family builds a
`GatewayNetworkProvider` (`lib/src/entrypoints/network_entrypoint.dart:102` and
`:310`). Use a custom host with the base classes:
`NetworkEntrypoint(url: ..., chainId: ...)` /
`ProxyNetworkEntrypoint(url: ..., chainId: ...)`.

Every entrypoint in both families takes an optional
`networkProviderConfig:` and forwards it whole to the provider it builds, so
client name, headers, request timeout, retry, throttle and cache settings apply
the same way on an API host and on a Gateway host. `01-public-api.md` §9 has the
detail.

## 5. The three things that go wrong first

All three snippets below compile clean.

### (a) The nonce is not fetched for you

`Account.nonce` is initialised to `const Nonce.zero()`
(`lib/src/core/account/account.dart:153`). If you never load it from the chain,
every transaction you sign carries nonce 0 and the node rejects all but the first.

```dart
Future<void> pitfallNonce(NetworkProvider provider, Account account) async {
  /// `account.nonce` starts at zero; it is never fetched for you.
  final AccountOnNetwork state = await provider.getAccount(account.address);
  account.nonce = state.nonce;
  final Nonce next = account.getNonceThenIncrement();
  print(next.value);
}
```

### (b) `Balance` is atomic units unless the constructor says EGLD

`denomination == 18` and `oneEGLD == 10^18` (`lib/src/core/balance.dart:2,5`).
`Balance(...)`, `Balance.fromNum(...)` and `Balance.fromString(...)` all take
**attoEGLD**; only `fromEgld` / `fromEgldString` take whole EGLD
(`lib/src/core/balance.dart:36,58,75,97,159`). Getting that distinction wrong is
a factor of 10^18, in either direction.

The two whole-EGLD constructors differ only in what they accept:

| Constructor | Takes | `0.1` becomes |
|---|---|---|
| `Balance.fromEgld(num value)` | a Dart `num` — `1`, `2.5`, `0.1` | `100000000000000000` |
| `Balance.fromEgldString(String value)` | a decimal string — `'1'`, `'2.5'`, `'0.1'` | `100000000000000000` |

Both are exact. `fromEgld` scales an `int` with integer arithmetic and converts a
`double` from its shortest decimal representation — the literal that produced it —
rescaling the digits to attoEGLD without rounding
(`lib/src/core/balance.dart:159-173,318-361`). Write whichever matches the value
you hold: a number in source, or a string off a form, a config file or an API.

```dart
void balanceUnits() {
  /// Atomic units (attoEGLD, 10^-18 EGLD).
  final Balance atomic = Balance(BigInt.from(1));
  final Balance alsoAtomic = Balance.fromNum(1);
  final Balance fromAtomicString = Balance.fromString('1000000000000000000');

  /// Whole-EGLD units, from a num or from a string.
  final Balance oneEgld = Balance.fromEgld(1);
  final Balance fraction = Balance.fromEgld(0.3);
  final Balance parsedFromText = Balance.fromEgldString('0.3');

  print(fraction.value == parsedFromText.value); /// true
  print([atomic, alsoAtomic, fromAtomicString, oneEgld]);
}
```

Two properties of `fromEgld` worth knowing, both by design:

- It converts the `double` you actually pass, which is not always the decimal it
  looks like — Dart evaluates `0.1 + 0.2` to the double `0.30000000000000004`
  before `fromEgld` ever sees it. Do arithmetic in `BigInt` attoEGLD, or state
  the amount once as text with `fromEgldString('0.3')`.
- It throws `ArgumentError` for an amount needing more than 18 decimal places
  (`lib/src/core/balance.dart:345-354`) rather than truncating it — attoEGLD is
  the smallest unit the chain has.

`Balance(...)` asserts non-negative (`lib/src/core/balance.dart:36-37`).

### (c) A factory result is not broadcastable

```dart
Future<void> pitfallFactoryVsController(Account account) async {
  /// A factory returns an UNSIGNED draft: nonce 0, empty signature.
  final TransferTransactionsFactory factory = TransferTransactionsFactory(
    config: const TransferTransactionsConfig(chainId: ChainId.devnet()),
  );
  final Transaction draft = factory.createTransactionForNativeTokenTransfer(
    sender: account.address,
    receiver: account.address,
    nativeAmount: Balance.fromEgld(1),
  );
  print('${draft.nonce.value} ${draft.signature.isEmpty}');

  /// A controller sets nonce/gas/version and signs.
  final TransfersController controller = TransfersController(
    chainId: const ChainId.devnet(),
  );
  final Transaction signed = await controller.createTransactionForNativeTransfer(
    account,
    const Nonce(7),
    NativeTransferInput(
      receiver: account.address,
      amount: Balance.fromEgld(1),
    ),
  );
  print(signed.signature.isEmpty);
}
```

Also note: `Transaction.copyWith` after signing invalidates the signature —
the signature covers the serialized payload
(`lib/src/core/transaction/transaction.dart:287` `serializeForSigning()`), so
change gas/nonce **before** signing, not after.

## 6. Gas

Without a `gasLimitEstimator`, the controller keeps the gas limit the factory
computed (`lib/src/core/transaction/controllers/base_controller.dart:398-403`).
To simulate against the node instead:

```dart
final estimator = GasEstimator(networkProvider: provider);
final controller = TransfersController(
  chainId: const ChainId.devnet(),
  gasLimitEstimator: estimator,
);
```

`GasEstimator({required NetworkProvider networkProvider, double gasMultiplier = 1.1, Logger? logger})`
— `lib/src/core/transaction/gas_models/gas_estimator.dart:21`. An explicit
`BaseControllerInput(gasLimit: GasLimit(n))` sets the execution budget outright
and skips estimation (`base_controller.dart:369-374`). The guardian and relayer
allowances of 50 000 each are then added on top of whichever budget was chosen —
explicit, estimated or drafted — so a guarded or relayed transaction is always
funded past its execution cost (`base_controller.dart:405`, `:119-150`).

Factory gas is always `minGasLimit + gasLimitPerByte * data.length` (data
movement) **plus** the endpoint's execution gas — see
`lib/src/core/transaction/factories/token_management_transactions_factory.dart:1254-1262`.

## 7. Never write these — removed in 3.0.0

`SignableMessage` · `ValidatorSigner(secretKey)` · `ValidatorSigner.fromPem` ·
`TransactionStatus.recalled` / `isRecalled` · `NetworkConfig.gasPriceModifierString` ·
`functionCallHexParts` · `RelayedTransactionsFactory.createRelayedTransaction` ·
`createTransactionForDelegatingVote` · `createTransactionForUnsettingBurnRoleForAll` ·
`Transaction.innerTransactions`.

Each was checked against the 3.1.0 barrel and does not resolve. Replacements are
tabulated in `CHANGELOG.md` under **Removed**.

## Not verified

- Runtime behaviour against a live network. Every snippet above was verified by
  `dart analyze` only; no transaction was broadcast.
- The devnet mnemonic and receiver bech32 in the example are syntactically valid
  and parse, but their on-chain balances were not checked.
- `TransactionAwaitingOptions` defaults (`timeout: 9s`, `pollingInterval: 600ms`,
  `maxConsecutiveErrors: 5`) are read from
  `lib/src/core/transaction/transaction_watcher.dart:55-61`; whether those
  defaults suffice for cross-shard completion on a busy network was not measured.
