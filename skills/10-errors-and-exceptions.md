---
name: errors-and-exceptions
title: Errors and Exceptions
summary: Catch the right type for every failure abidock_mvx can produce, and know which failures are your bug to fix rather than an exception to handle.
reads: [skills/12-pitfalls.md, skills/07-network-providers.md]
verified_against: abidock_mvx 3.1.0 (Dart 3.13)
---

## When to use this

You are writing `try`/`catch` around anything in this package — building,
signing, broadcasting, awaiting, querying, decoding — and you need the exact
type names and the exact set of things that can escape.

Single import for every type below:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
```

## 1. The rule that decides your catch clause

There are **two** disjoint groups.

| Group | What it is | Do |
|---|---|---|
| A. `AbidockException` subtypes | Every exception this package raises to model a runtime failure | Catch and handle |
| B. Dart `Error` subtypes (`ArgumentError`, `StateError`, `UnsupportedError`, `UnimplementedError`) and `FormatException` | Programmer mistakes, unimplemented surfaces, and malformed provider bodies | Fix the call — or, for `FormatException`, guard the body |

**One clause covers the SDK.** Every exception type declared in `lib/` extends
`AbidockException`, so `on AbidockException catch (e)` catches all of them and
gives you `message`, `cause` and `stackTrace` on every one. Runtime-checked
across the whole exported set: `e is AbidockException` is `true`.

Catch a specific type first only when you want its extra fields (a status code,
a transaction hash, a timeout) or a different recovery. Clause order is
most-specific-first, as always in Dart.

One failure channel is not a `catch` at all: `WebSocketEventStream.errors` is a
`Stream<WebSocketEventError>` of delivered values, not thrown exceptions
(`lib/src/abi/smart_contract/event_streaming/websocket_event_stream.dart:305,449`).
Subscribe to it if you consume that stream.

## 2. Group A — the `AbidockException` tree

Base: `abstract class AbidockException implements Exception`
(`lib/src/utils/sdk_exceptions.dart:47`). Every member carries
`String message`, `Object? cause`, `StackTrace? stackTrace`, all positional
message + named `cause`/`stackTrace` in the constructor.

### Wallet and crypto

| Type | Declared | Extra fields | Thrown when / by |
|---|---|---|---|
| `WalletException` | `sdk_exceptions.dart:87` | — | Base only; nothing throws it directly |
| `PemException` | `:107` | — | PEM parse failure — `lib/src/wallet/pem.dart`, `lib/src/wallet/validator_keys.dart` |
| `MnemonicException` | `:122` | — | Invalid mnemonic — `lib/src/wallet/mnemonic.dart` |
| `SignerException` | `:137` | — | `UserSigner.sign` failed — `lib/src/wallet/user_signer.dart:199` |
| `DecryptorException` | `:152` | — | MAC mismatch / wrong password — `lib/src/wallet/crypto/decryptor.dart:75`; tampered or unverifiable payload — `lib/src/wallet/crypto/pubkey_decryptor.dart:67,99` |
| `WalletLengthException` | `:167` | — | Key/buffer length mismatch — `lib/src/wallet/assertions.dart:29` |

### Network

| Type | Declared | Extra fields | Thrown when / by |
|---|---|---|---|
| `NetworkException` | `sdk_exceptions.dart:186` | `int? statusCode`, `String? endpoint` | Every HTTP-layer failure — see §5 |
| `AccountAwaiterTimeoutException` | `:227` | `String? address`, `Duration? timeout` | `AccountAwaiter` gave up — `lib/src/infrastructure/network/account_awaiter.dart:112` |
| `AccountAwaiterException` | `:268` | inherits `statusCode`/`endpoint` | `maxConsecutiveErrors` polling failures in a row — `account_awaiter.dart:92` |

`AccountAwaiterTimeoutException` and `AccountAwaiterException` **extend
`NetworkException`**, so `on NetworkException` swallows them. Order your
clauses most-specific first.

### Transaction

| Type | Declared | Extra fields | Thrown when / by |
|---|---|---|---|
| `TransactionException` | `sdk_exceptions.dart:291` | — | `signAsRelayer` with no `relayer` set (`:42`); relayer and sender in different shards (`:57`); `signAsGuardian` with no `guardian` set (`:84`) — all in `lib/src/abi/extensions/transaction_signing_extensions.dart` |
| `TransactionCreationException` | `:319` | `String? transactionHash` | The `executeTransaction` wrapper converts any unrecognised error raised while building a transaction — `lib/src/utils/helpers.dart:108` |
| `TransactionWatcherTimeoutException` | `:354` | `String? transactionHash`, `Duration? timeout` | Watcher deadline elapsed — `lib/src/core/transaction/transaction_watcher.dart:256` |
| `TransactionWatcherException` | `:397` | `String? transactionHash` | `maxConsecutiveErrors` fetch failures, or any fetch failure inside `fetchTransaction` — `transaction_watcher.dart:284,309` |
| `EventParsingException` | `:434` | `String? eventIdentifier` | Unknown event identifier, or decode failure of a known event — `lib/src/core/transaction/transaction_event_parser.dart` (8 sites) |
| `UnexpectedEventCountException` | `lib/src/core/transaction/transaction_logs.dart:13` | `String identifier` | A `TransactionLogs` single-event lookup matched more than one event — `transaction_logs.dart:249` |
| `TokenManagementParseException` | `.../outcome_parsers/token_management_outcome_parser.dart:16` | — | `TokenManagementOutcomeParser` — including a `signalError` found anywhere in the transaction's logs or its results |
| `SmartContractParseException` | `.../outcome_parsers/smart_contract_outcome_parser.dart:16` | — | `SmartContractOutcomeParser` |
| `DelegationParseException` | `.../outcome_parsers/delegation_outcome_parser.dart:15` | — | `DelegationOutcomeParser` |
| `GovernanceParseException` | `.../outcome_parsers/governance_outcome_parser.dart:24` | — | `GovernanceOutcomeParser` |

The five parser/lookup types above all extend `TransactionException`, so
`on TransactionException` catches them as a family — see §3 for their
constructor shapes.

### Smart contract

| Type | Declared | Extra fields | Thrown when / by |
|---|---|---|---|
| `SmartContractException` | `sdk_exceptions.dart:472` | — | Base only |
| `ArgumentEncodingException` | `core_types.dart:123` | `endpointName`, `argumentIndex`, `argumentValue`, `expectedType` (all optional) | Native → ABI encoding failed — `lib/src/abi/serializers/argument_encoder.dart`, `.../smart_contract/query/query.dart` |
| `ResponseParsingException` | `core_types.dart:183` | `endpointName`, `returnIndex`, `rawData`, `expectedType` | Return-value decode failed — `lib/src/abi/smart_contract/query/response_parser.dart` |
| `EndpointNotFoundException` | `core_types.dart:243` | **required** `String endpointName`, plus `abi`, `availableEndpoints` | Endpoint name absent from the ABI, always via `.withSuggestions` — `endpoint_resolver.dart:60`, `smart_contract_controller.dart:375`, `query.dart:157,250,303` |
| `ArgumentValidationException` | `core_types.dart:354` | **required** `endpointName`, `expectedCount`, `actualCount`; optional `validationErrors` | Argument count mismatch via `.countMismatch` (`endpoint_resolver.dart:181,197`); argument type mismatch via `.typeErrors` (`:291,318`) |
| `ResponseValidationException` | `core_types.dart:460` | **required** `endpointName`, `expectedCount`, `actualCount` | Return-value count mismatch, via `.countMismatch` — `endpoint_resolver.dart:396` |
| `GasEstimationException` | `core_types.dart:521` | **required** `transactionType`; optional `endpointName`, `reason`, `status`, `rawResponse`, `contract`, `hint` | Simulation-based gas estimation failed — `gas_estimator.dart:96,116` (`.fromApiResponse`) and `:155` |
| `SmartContractQueryException` | `query.dart:23` | **required** named `message` and `code`; optional `response` | A query response carried a non-`ok` return code — `smart_contract_query_runner.dart:401`, via `.fromResponse`. With the bundled providers the `NetworkException` at `base_network_provider.dart:814` fires first — see §5 |
| `MultisigParseException` | `.../controller/multisig_controller.dart:694` | — | `MultisigController` outcome parsing |
| `ValidatorsParseException` | `.../controller/validators_controller.dart:551` | — | `ValidatorsController` outcome parsing |

(`core_types.dart` = `lib/src/abi/core/core_types.dart`;
`endpoint_resolver.dart` = `lib/src/abi/core/endpoint_resolver.dart`;
`gas_estimator.dart` = `lib/src/core/transaction/gas_models/gas_estimator.dart`;
`query.dart` = `lib/src/abi/smart_contract/query/query.dart`.)

Using a controller built with `withoutAbi()` on an ABI-dependent path is a
programmer error, not an exception to handle: it throws
`StateError('ABI is not available. Controller was created with withoutAbi().')`
(`smart_contract_controller.dart:181`) — group B, not group A.

### Serialization

| Type | Declared | Extra fields | Thrown by |
|---|---|---|---|
| `SerializationException` | `sdk_exceptions.dart:492` | — | Base only |
| `AbiBinaryCodecException` | `:512` | `String? typeName`, `dynamic value` | 76 throw sites in `lib/`: 65 under `lib/src/abi/codecs/**`, 11 in `lib/src/abi/core/validation_mixin.dart` |
| `AbiNativeSerializationException` | `:553` | `String? typeName`, `dynamic value` | `lib/src/abi/serializers/native_serializer.dart` |
| `AbiArgumentSerializationException` | `:594` | `int? argumentIndex`, `String? typeName` | `lib/src/abi/serializers/arg_serializer.dart` |
| `DeserializationException` | `:637` | `String? typeName`, `String? rawData` | `lib/src/abi/serializers/deserializer.dart` |
| `AbiTypeFormulaParseException` | `:678` | `String? formula` | `lib/src/abi/core/type_formula_parser.dart` |

### Other direct children of `AbidockException`

| Type | Declared | Extra fields | Thrown by |
|---|---|---|---|
| `ValidationException` | `sdk_exceptions.dart:714` | **required** `parameterName`, `invalidValue`, `constraint` | Token identifier / ticker validation — `lib/src/core/tokens/token.dart`, `token_computer.dart` |
| `AddressException` | `lib/src/core/address.dart:24` | — | Wrong byte length, bad bech32, bad hex, missing HRP separator, `numberOfShards <= 0` — `address.dart:71,99,128,135,261,272` |
| `CircuitBreakerOpenException` | `lib/src/infrastructure/resilience/circuit_breaker_exception.dart:7` | `DateTime lastFailureTime`, `Duration retryDelay` | `CircuitBreaker` rejected the call while open — but the providers convert it, see §5 |

`Address.fromBech32` wraps the underlying `ArgumentError` into
`AddressException`, so bad address input is group A, not group B
(`address.dart:95-103`; runtime-checked).

## 3. Parser and resilience failures: constructor shapes

These are the types you are most likely to name explicitly, because they mark
"the chain did something the parser cannot turn into a result". All of them sit
inside the tree, so `on AbidockException` already covers them; name them when
you want to handle a parse failure differently from a network failure.

| Type | Parent | Shape |
|---|---|---|
| `SmartContractParseException` | `TransactionException` | `(message, [cause])` |
| `TokenManagementParseException` | `TransactionException` | `(message, [cause])` |
| `DelegationParseException` | `TransactionException` | `(message, [cause])` |
| `GovernanceParseException` | `TransactionException` | `(message, [cause])` |
| `UnexpectedEventCountException` | `TransactionException` | `(message, identifier)` |
| `MultisigParseException` | `SmartContractException` | `(message)` — `cause` is inherited but never set |
| `ValidatorsParseException` | `SmartContractException` | `(message)` — `cause` is inherited but never set |
| `SmartContractQueryException` | `SmartContractException` | named, **required** `message` and `code`, optional `response`; factories `.fromResponse` and `.networkError` |
| `CircuitBreakerOpenException` | `AbidockException` | `(message, lastFailureTime, retryDelay)` |

All nine are exported from `package:abidock_mvx/abidock_mvx.dart`, so you can
name them in a catch clause. Runtime-checked for every one:
`e is AbidockException` is `true`, `e is Exception` is `true`. Only the four
`(message, [cause])` types populate `cause`; the rest carry the fields listed
above.

## 4. Group B — plain Dart errors: fix, do not catch

| Error | Meaning here | Examples |
|---|---|---|
| `ArgumentError` | You passed a value the API rejects up front (264 `throw ArgumentError` sites in `lib/`; 448 mentions once doc comments are counted) | Empty function name `lib/src/abi/core/core_types.dart:43`; empty endpoint name `lib/src/abi/core/endpoint.dart:58`; unregistered type `lib/src/abi/core/types.dart:102`; a smart-contract call with neither `gasLimit` nor a `gasLimitEstimator` `lib/src/abi/smart_contract/controller/smart_contract_controller.dart:693`; relayer set after signing / chain-id mismatch / cross-shard relayer `lib/src/core/transaction/factories/relayed_transactions_factory.dart` |
| `StateError` | The object is not configured for what you asked | Controller or call factory created without an ABI — `smart_contract_controller.dart:181`; a *different* relayer is already set — `relayed_transactions_factory.dart` |
| `FormatException` | Provider JSON did not have the shape the parser requires, or a string amount is not a number | `requireAs<T>` `lib/src/utils/helpers.dart:29-31`, `requireInt` `:165-173`, `optionalInt` `:197-203`; `Balance.fromEgldString('')` `lib/src/core/balance.dart:98` |
| `UnsupportedError` | The route or the value has no wire form on this path | Routes the Gateway does not serve (`skills/12-pitfalls.md` §12); `CompositeValue.toBytes` `lib/src/abi/types/special/composite.dart:242`; `MultiValueValue.toBytes` `.../multi_value.dart:152`; `TokenTransferValue.toBytes` `.../token_transfer_value.dart:187`; `BigUIntValue operator ~` `.../biguint.dart:383` |
| `UnimplementedError` | Deliberately absent implementation | `BigFloatValue.toBytes` `lib/src/abi/types/primitives/big_float.dart:86`; `ValidatorSecretKey.sign` (pure-Dart BLS is not available) `lib/src/wallet/validator_keys.dart:250` |

`FormatException` from a malformed provider body is **not** wrapped: it escapes
`NetworkStatus.fromApiResponse`, `TransactionOnNetwork.fromApiResponse` and
friends unchanged.

## 5. Network and HTTP failures

All of the following raise `NetworkException`, in
`lib/src/infrastructure/network/base_network_provider.dart`:

| Condition | Site | `statusCode` | `endpoint` | `cause` |
|---|---|---|---|---|
| GET status != 200 | `:1118` | set | set | null |
| POST status not 200/201 | `:1215` | set | set | null |
| Query POST status not 200/201 | `:775` | set | null | null |
| `DioException` (connection refused, DNS, TLS, Dio's own connect/receive/send timeout) on GET | `:1154` | `e.response?.statusCode` (may be null) | set | the `DioException` |
| Same on POST | `:1251` | as above | set | the `DioException` |
| Body carried a provider-level error field | `:1134` (GET), `:1231` (POST), `:795` (query) | null | set on GET/POST | null |
| Contract query returned a non-`ok` return code | `:814` | null | null | null |
| Circuit breaker open | `:1285` | null | null | null — `CircuitBreakerOpenException` is caught at `:1275` and converted, so it never escapes the provider |

Two consequences worth planning for:

1. **A failed contract query is a `NetworkException`, not a
   `SmartContractException`** (`:814`). The message embeds the return message
   and return code. `SmartContractQueryRunner` has its own check for the same
   condition (`smart_contract_query_runner.dart:391-401`), but it runs *after*
   `queryContract` returns, and the two use complementary predicates
   (`SmartContractQueryResponse.isSuccess` / `isFailure`, `query.dart:459-462`),
   so with a provider derived from `BaseNetworkProvider` the `NetworkException`
   is what you catch. Handle both types if you also drive a provider of your
   own.
2. **Not every request failure is a `NetworkException`.** Each request is also
   raced against `requestTimeout` with `Future.timeout`
   (`:1108`, `:1204`, `:762`), and the surrounding handler only catches
   `DioException` — so a `TimeoutException` from that race escapes unwrapped.
   The same type escapes `RetryHelper` when retries are enabled and every
   attempt timed out (`lib/src/infrastructure/resilience/retry_helper.dart:104-124`).
   Catch `TimeoutException` from `dart:async` alongside `NetworkException`.

Defaults, from `lib/src/infrastructure/network/network_provider_config.dart:193-201`
and `base_network_provider.dart:55,190`: retries **disabled**, throttle
**disabled**, response cache **disabled**, circuit breaker **disabled**,
`requestTimeout` **30 s**. Set them through `NetworkProviderConfig` and hand
that to the provider or the entrypoint.

## 6. Compiled sample: broadcast + await

```dart
import 'dart:async';

import 'package:abidock_mvx/abidock_mvx.dart';

/// Broadcast a signed transaction and await its outcome with full error
/// handling. Every catch clause below is reachable on this code path.
Future<TransactionOnNetwork?> broadcastAndAwait(
  ApiNetworkProvider provider,
  Transaction signed,
) async {
  final TransactionWatcher watcher = TransactionWatcher(
    networkProvider: provider,
  );
  try {
    final String txHash = await provider.sendTransaction(signed);
    final TransactionOnNetwork tx = await watcher.awaitCompleted(
      txHash,
      options: const TransactionAwaitingOptions(
        timeout: Duration(seconds: 30),
        pollingInterval: Duration(milliseconds: 600),
      ),
    );

    /// `awaitCompleted` stops on `isFinal`, which also covers
    /// `not-executable-in-block` — a final status with no outcome to read.
    if (!tx.isCompleted) {
      return null;
    }
    return tx;
  } on TransactionWatcherTimeoutException catch (e) {
    print('still pending after ${e.timeout?.inSeconds}s: ${e.transactionHash}');
    return null;
  } on TransactionWatcherException catch (e) {
    print('polling gave up on ${e.transactionHash}: ${e.cause}');
    return null;
  } on NetworkException catch (e) {
    print('HTTP ${e.statusCode} at ${e.endpoint}: ${e.message}');
    return null;
  } on TimeoutException catch (e) {
    print('per-attempt timeout, retries exhausted: ${e.duration}');
    return null;
  } on AbidockException catch (e) {
    print('${e.runtimeType}: ${e.message} (cause: ${e.cause})');
    return null;
  } finally {
    watcher.close();
  }
}
```

Clause order matters. `TransactionWatcherTimeoutException` and
`TransactionWatcherException` are siblings (both extend `TransactionException`,
`sdk_exceptions.dart:354,397`), so their relative order is free — but both must
precede any `on TransactionException`, and every specific type must precede the
final `on AbidockException`, which is the catch-all for this package.

`watcher.close()` closes the underlying provider's HTTP client
(`transaction_watcher.dart:342-344`), so do not reuse `provider` afterwards.

## 7. Compiled sample: a specific type, then the catch-all

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Parser failures are `AbidockException`s like everything else the SDK
/// raises. Name the type when you want to react to a parse failure
/// specifically; the trailing clause still catches the rest.
List<IssueFungibleResult> parseIssue(TransactionOnNetwork tx) {
  const TokenManagementOutcomeParser parser = TokenManagementOutcomeParser();
  try {
    return parser.parseIssueFungible(tx);
  } on TokenManagementParseException catch (e) {
    print('parser refused the outcome: ${e.message} (cause: ${e.cause})');
    return const <IssueFungibleResult>[];
  } on AbidockException catch (e) {
    print('${e.runtimeType}: ${e.message}');
    return const <IssueFungibleResult>[];
  }
}

/// Malformed provider JSON surfaces as a plain `FormatException` from the
/// `require*` helpers, not as an SDK exception.
NetworkStatus parseStatus(Map<String, dynamic> body) {
  try {
    return NetworkStatus.fromApiResponse(body);
  } on FormatException catch (e) {
    throw NetworkException('unusable /network/status body', cause: e);
  }
}

/// Bad address input is an SDK exception, not a Dart error: `Address.fromBech32`
/// wraps the underlying `ArgumentError` into `AddressException`.
void addressInput() {
  try {
    Address.fromBech32('not-an-address');
  } on AddressException catch (e) {
    print('bad address: ${e.message}');
  }
}
```

## 8. Building your own throw sites

Two exported helpers apply the package's own convention
(`lib/src/utils/helpers.dart:94` and `:130`). Both rethrow
`NetworkException`, `SerializationException`, `SmartContractException` and
`ValidationException` untouched, and wrap everything else:

| Helper | Wraps unrecognised errors in |
|---|---|
| `executeTransaction<T>({required String endpointName, required Future<T> Function() action})` | `TransactionCreationException` (also rethrows `TransactionCreationException`) |
| `executeQuery<T>({required String endpointName, required Future<T> Function() action})` | `NetworkException` |

Because `SmartContractException` is on both lists, its whole branch — including
`SmartContractQueryException`, `EndpointNotFoundException` and the validation
types — passes through unchanged. The `TransactionException` branch is not on
the lists, so `TransactionWatcherException`, `EventParsingException` and the
outcome-parser exceptions are re-wrapped if they cross one of these helpers.
Catch them inside the action if you need them intact.

## Not verified

- Which HTTP status codes each public host actually returns for each failure
  mode. Only the SDK's mapping from status code to exception is verified here.
- Whether Dio's per-phase timeouts or the outer `Future.timeout` race wins in
  practice; both are configured with the same `requestTimeout` duration
  (`_applyConfigToDio`, `base_network_provider.dart:215-219`), so which one
  fires first is timing-dependent. Handle both `NetworkException` and
  `TimeoutException`.
- `EventParsingException` messages and the exact predicate for each of its 8
  throw sites were not enumerated individually.
