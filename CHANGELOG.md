# Changelog

All notable changes to `abidock_mvx` are documented here. We follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) and the structure recommended by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [2.0.0] -- 2026-08-12

This release lands the top-level `NetworkEntrypoint` façade, reshapes the generated DTO surface, and corrects a set of defects that produced transactions the chain rejects. It also removes public API that could not work. Migration is mostly mechanical: regenerate, replace `String` token-identifier/address fields with the new wrapper types, and switch one-off `ApiNetworkProvider` plumbing to the new entrypoint helpers if you want the shortcut. The removals are listed under **Removed**; each has a working replacement.

Minimum SDK is now Dart 3.11.

### Entrypoints

New `lib/src/entrypoints/network_entrypoint.dart`, exported from `abidock_mvx.

- `NetworkEntrypoint` / `DevnetEntrypoint` / `TestnetEntrypoint` / `MainnetEntrypoint` -- API-backed (indexer).
- `ProxyNetworkEntrypoint` / `DevnetProxyEntrypoint` / `TestnetProxyEntrypoint` / `MainnetProxyEntrypoint` -- Gateway-backed (chain-go Proxy).
- `EntrypointUrls` constants for the official public hosts.

Each entrypoint caches a single `NetworkProvider` and exposes `createSmartContractController`, `createTransfersFactory`, `createTokenManagementFactory`, `createDelegationFactory`, `createMultisigFactory`, `createValidatorsFactory`, `createGovernanceFactory`, `create*Controller`, and `createTransactionWatcher`. See the new docs page at `docs/docs/network/entrypoints.md`.

### Auto-gas signing bug fixed in generator

`CallsGenerator` previously emitted:

```dart
final tx = await controller.call(..., gasLimit: const GasLimit(600000000));
final gas = await simulateGas(tx, controller.networkProvider);
return tx.copyWith(newGasLimit: gas); // signature no longer matches
```

The signed transaction's signature was invalidated by `copyWith(newGasLimit:)`. Generated code now builds an unsigned probe via `SmartContractCallFactory`, simulates gas, then calls `controller.call` once with the final gas so signing happens against the correct value. Regenerate any existing generated code to pick up the fix.

### Type-mapper changes (generated DTO breaking change)

The codegen `TypeMapper` now emits the wrapper types instead of `String`:

| ABI type                          | Old Dart type | New Dart type                |
|-----------------------------------|---------------|------------------------------|
| `Address`                         | `String`      | `Address`                    |
| `TokenIdentifier`                 | `String`      | `TokenIdentifier`            |
| `EsdtTokenIdentifier`             | `String`      | `TokenIdentifier`            |
| `EgldOrEsdtTokenIdentifier`       | `String`      | `EgldOrEsdtTokenIdentifier`  |
| `BigFloat`                        | (unsupported) | `double`                     |
| `ManagedByteArray<N>`             | (unsupported) | `Uint8List`                  |
| `MultiValue<...>`                 | (unsupported) | record `(T1, T2, ...)`       |

Generated struct fields, query return types, and call arguments shift accordingly. Anywhere you previously did `pair.firstToken` and got a `String`, you now get a `TokenIdentifier` -- use `.value` for the raw string.

### Transactions the chain rejected

- **ESDT built-in functions are addressed to the sender.** `ESDTNFTCreate`, `ESDTLocalMint`, `ESDTLocalBurn`, `ESDTNFTUpdateAttributes`, `ESDTNFTAddQuantity`, `ESDTNFTBurn`, `ESDTModifyRoyalties`, `ESDTSetNewURIs`, `ESDTModifyCreator`, `ESDTMetaDataUpdate`, `ESDTMetaDataRecreate`, `ESDTNFTAddURI`, `ESDTNFTUpdate` and `ESDTNFTRecreate` were sent to the ESDT system contract. Built-in functions execute against the caller's own account and are now addressed to the sender. The remaining 23 endpoints still target the system contract.
- **Governance contract address corrected** from `…0006ffff` to `…0003ffff`. Every governance transaction was addressed to an account that is not a contract; `createTransactionForNewProposal` attaches 1000 EGLD by default, so the call also stranded that value.
- **Validator operations now target the validator contract** (`…0001ffff`) instead of the staking contract (`…0000ffff`). The staking contract requires the caller to be the validator contract, so wallet-signed staking transactions could never succeed.
- **`changeConfig` encodes `minQuorum`, `minVetoThreshold` and `minPassThreshold` as decimal strings.** The contract parses these arguments as ASCII decimal, not big-endian integers.
- **`clearEndedProposals` gas scales with the proposer count** (`gasLimit + n * gasLimit`); it previously sent a flat limit for any number of proposers.
- **`registerAndSetAllRoles` and `registerDynamic` emit the mandatory token type.** Both omitted it, so the contract rejected the argument list. `registerAndSetAllRolesDynamic` now appends `numDecimals` only for `META`.
- **Token properties are written in full.** Only enabled flags were emitted, and a missing pair does not mean "disabled" — the contract creates tokens with `canUpgrade` and `canAddSpecialRoles` already on and overrides only the properties present in the arguments. `TokenProperties(canUpgrade: false)` therefore produced an upgradable token, and `controlChanges` could not switch a property off. Every supported property is now emitted with its `true`/`false` value; the fungible `issue` endpoint omits `canTransferNFTCreateRole`, which is not part of its argument list.
- **Factories add the data-movement gas term** (`minGasLimit + gasLimitPerByte * data.length`) on top of the endpoint's execution gas. Token-management, delegation and the guardian builders previously shipped the bare execution limit, under-charging by an amount that grew with the payload.

### Signing and relayed transactions

- **`innerTransactions` no longer reaches the signing payload.** The field does not exist in the chain's transaction format; every relayed transaction was signed over a payload the node cannot reconstruct, so the signature could not verify. The field has been removed from `Transaction` entirely.
- **`RelayedTransactionsFactory` implements the flat relayed-v3 model:** a single transaction carrying `relayer` and `relayerSignature`. Attach the relayer with `applyRelayer` before signing, then sign with the sender and with the relayer, in either order.
- **`Transaction.serializeForSigning()` applies the Keccak digest when the hash-signing option bit is set.** `signWith`, `signAsRelayer` and `signAsGuardian` previously signed the raw payload, producing signatures the chain rejects for hash-signed transactions.
- **`UserPublicKey.verify` returns `false` for malformed signatures** instead of throwing. The result was returned without `await` inside the `try`, so the `catch` never ran for asynchronous errors.
- **`Account.fromMnemonic` disposes the mnemonic after key derivation completes**, not before.

### Outcome parsers

`TokenManagementOutcomeParser` reads the logs of the transaction's smart-contract results in addition to its own. Endpoints that act on another account — `freeze`, `unFreeze`, `wipe`, `setSpecialRole`, `unSetSpecialRole` and the local mint/burn pair — are executed by forwarding a built-in call to the target address, so their events are reported on the result rather than the transaction. Every such parse previously returned an empty list, and a `signalError` reported on a result was invisible, so a failed transaction parsed as a successful empty outcome.

### Network providers

- `TransactionOnNetwork.fromApiResponse` reads smart-contract results from `results`; they were previously always `null`.
- `relayedVersion` is a `String?` (`'v1'`, `'v2'`, `'v3'`). It was parsed as an integer and threw on every relayed transaction.
- Corrected routes: transaction simulation, guardian data, and the gateway's non-fungible token listing, which pointed at a path that does not exist on any node or proxy.
- Guardian fields are read from the flat account payload, and the provider sends the query flag required to return them.
- `GatewayNetworkProvider` accepts a `NetworkProviderConfig`, so user agent, timeout and retry policy apply to it as well.
- Request throttling and GET-response caching can be enabled through `NetworkProviderConfig`. Both are off by default.

### Supernova

The chain moves block timestamps from seconds to milliseconds at the Supernova activation epoch without renaming the field, and the unit also differs per route. Reading such a value as seconds yields a date in the year 57,000.

- `TransactionOnNetwork` exposes `timestampMs` alongside `timestamp`, plus `executedAt`, which normalises either unit by magnitude.
- `NetworkStatus` exposes `blockTimestamp` and `blockTimestampMs`; block, hyperblock, account and token models expose their millisecond counterparts.
- Block models carry `lastExecutionResultHash` and `lastExecutionResultNonce`, which asynchronous execution reports separately from the block itself.
- `miniblockType` is read with the spelling the node emits.
- `AccountAwaiter` polls every 600 ms, matching sub-second block times.
- Added the `reward-reverted` status.

### ABI

- The type names `TokenId`, `NonZeroBigUint`, `Payment` and `FungiblePayment` resolve. Contracts that reference them carry no definition in `types`, so an ABI using them failed to load.
- Enum variant payload fields are parsed, so fielded enums decode correctly rather than being truncated.
- `specificType` and the contract's internal method name are surfaced on the endpoint and parameter models. `specificType` distinguishes a `u64` holding milliseconds from one holding seconds.
- Corrected `ExplicitEnumValue.toBytes()` and the counted-variadic argument convention.
- `BigFloat` has no portable wire form; encoding, decoding and `toBytes` throw, and the type exists so that ABIs mentioning it still load.

### Removed

Each entry has a working replacement; none of the removed members could produce a valid result.

| Removed | Use instead |
|---|---|
| `SignableMessage` | `Message` + `MessageComputer.computeBytesForSigning` |
| `ValidatorSigner(secretKey)`, `ValidatorSigner.fromPem` | `ValidatorSigner.custom(signFn)` |
| `TransactionStatus.recalled`, `isRecalled` | — status does not exist on chain |
| `NetworkConfig.gasPriceModifierString` | `gasPriceModifier` |
| `functionCallHexParts` on the multisig builders | `functionCall: <TypedValue>[...]` |
| `RelayedTransactionsFactory.createRelayedTransaction` | `applyRelayer`, then sign |
| `createTransactionForDelegatingVote` | — callable only by a contract |
| `createTransactionForUnsettingBurnRoleForAll` | `createTransactionForUnsettingBurnRoleGlobally` |
| `Transaction.innerTransactions` | — not part of the transaction format |

### Public API

`NetworkProviderConfig`, `RetryPolicy`, `UserAgent`, `GuardianData`, `Guardian`, `CodeMetadata`, `EsdtTokenPaymentType` and `EgldOrEsdtTokenPaymentType` are exported. They were declared public but unreachable from the package barrel, which made the configuration surface unusable from outside the package.

### Tooling

- **Generated code is formatted.** The generator wrote unformatted Dart, so any project with a `dart format --set-exit-if-changed` check failed on its own generated sources. Output is now formatted for the language version of the SDK running the generator.
- The ABI validator no longer warns on keys that are not part of the ABI schema, which broke `--fail-on-warnings` for valid ABIs.
- Integration tests that perform live network calls are tagged and skipped by default; run them with `dart test -P integration`.
- Added `dart_style` and `pub_semver` dependencies.

### Generator internals

- `bin/codegen/utils/imports_formatter.dart` deleted. Import ordering now lives inside each generator via the existing `import_manager` / per-file `_writeSortedImports` helpers.
- `BarrelGenerator` no longer dual-tracks event-model file names; the helper computes the suffix once.
- Reserved-keyword sanitisation consolidated through `NameSanitizer`; the duplicate list in `event_models_generator.dart` has been removed (the keyword set is now sourced from `name_sanitizer.dart`).

### Docs

- New page: `network/entrypoints.md` covering all eight entrypoint classes plus the `gasLimitEstimator` injection point.
- Sidebar moved entrypoints under the existing **Network** category.
- Codegen and smart-contract pages updated to show the new generator output (`Address`/`TokenIdentifier` wrappers, autogas probe pattern).

### Migration

1. Move to Dart 3.11 or newer, then `dart pub upgrade abidock_mvx` (or bump to `^2.0.0` in `pubspec.yaml`).
2. Regenerate any committed codegen output. Diffs to expect:
   - Struct fields that previously held `String` for `Address` / `TokenIdentifier` now hold the wrapper type.
   - Generated `*Unsigned` call helpers are unchanged on the wire; the signed helpers now do the probe-then-sign dance internally.
   - Generated files are formatted.
3. Walk the call sites; the compiler will flag every `String`/`Address` mismatch, every removed member listed under **Removed**, and `relayedVersion` moving from `int?` to `String?`.
4. Re-check any hard-coded gas limits. Factory-produced limits now include the data-movement term and are higher than before.
5. Re-check anything that reads `TransactionOnNetwork.timestamp` directly; prefer `executedAt`.
6. (Optional) Swap `ApiNetworkProvider(...)` + factory plumbing for `DevnetEntrypoint()` / `MainnetEntrypoint()` etc.

## [1.2.0] -- 2026-04-17

### Public-key encryption now actually uses X25519

`PubkeyEncryptor` and `PubkeyDecryptor` were feeding raw Ed25519 key bytes into X25519 APIs. The code round-tripped with itself (both sides made the same mistake), but the ciphertext couldn't be decrypted by anything else — mx-sdk-js-core, NaCl, libsodium, or any tool that does real X25519.

This release adds the two standard Curve25519 key conversions, both exposed under `lib/src/wallet/crypto/curve25519_conversion.dart`:

- `ed25519PublicKeyToX25519(edPub)` — the Bernstein/RFC-7748 birational map `u = (1 + y) / (1 - y) mod (2^255 - 19)`.
- `ed25519SeedToX25519SecretKey(seed)` — `SHA-512(seed)[0:32]` followed by RFC 7748 clamping, matching libsodium's `crypto_sign_ed25519_sk_to_curve25519`.

The encryptor and decryptor now call through these on both sides, so the wire format is real X25519-XSalsa20-Poly1305 and will interoperate with any standard implementation.

### Breaking change

Anything encrypted with 1.1.0 or earlier `PubkeyEncryptor` cannot be decrypted by 1.2.0, and vice versa. The serialized schema (`X25519EncryptedData`) is unchanged — only the math behind it is now correct.

## [1.1.0] -- 2026-04-16

This release closes a pile of wire-format mismatches against the chain, fills in the protocol coverage that was missing (staking, governance, relayed-v3, SC lifecycle), and tightens the concurrency primitives that sit between the SDK and the network. There are a handful of breaking changes, all listed at the bottom — most projects won't notice them.

### Wire format

Transaction hashing now matches the chain byte-for-byte. The culprits were subtle: protobuf zero-values were emitted as a single zero byte instead of the sign+magnitude pair, `Option<T>` top-level encoding dropped its marker, signed `BigInt` nested encoding lost its sign extension on `-129` and friends, and hash-signed transactions were being fed the raw JSON bytes instead of the Keccak digest. The message-signing prefix went back to the canonical `\x17Elrond Signed Message:\n` — signatures need to interop with existing wallets and hardware devices, so renaming to "MultiversX" wasn't an option.

### Network provider

Endpoints that were quietly wrong got fixed: bulk-send, VM query, transaction status, NFT nonce padding (even-length hex), process-status vs transaction endpoint on Gateway, the fungible-vs-NFT filter split on `_parseEsdts`, account storage key routing, and block-by-nonce shard prefixing. The circuit breaker now wraps smart-contract queries too. `ApiNetworkProvider.estimateTransactionCost` throws `UnsupportedError` instead of pretending to work.

`SendTransactionsResult` now returns per-transaction outcomes (`SendTxSuccess` / `SendTxFailure` with the node's rejection reason) alongside the aggregate counts, so bulk submission can drive a resubmission loop properly.

### New protocol coverage

- `SmartContractTransactionsFactory` for deploy / upgrade / change-owner / claim-developer-rewards.
- `StakingTransactionsFactory` for the direct-staking system SC (stake, unStake, unBond, claim, changeRewardAddress, changeValidatorKeys, unJail, reStakeUnStakedNodes).
- `GovernanceTransactionsFactory` for proposing, voting, delegate-voting, closing, and claiming accumulated fees.
- `RelayedTransactionsFactory` for relayed-v3. `Transaction` gained an `innerTransactions` field and the protobuf serializer emits them on field 18.
- `TransactionDecoder` learned the matching sealed subclasses: `ContractDeploy`, `ContractUpgrade`, `ContractChangeOwner`, `ClaimDeveloperRewards`, `RelayedV3Transaction`.
- `TokenManagementTransactionsFactory` gained the nine built-ins it was missing: `transferOwnership`, `controlChanges`, `ESDTNFTAddURI`, `stopNFTCreate`, `transferNFTCreateRole`, `unsetBurnRoleGlobally`, `registerAndSetAllRolesDynamic`, `changeSFTToMetaESDT`, `updateTokenID`.

### Concurrency & resilience

`CircuitBreaker` now enforces a single in-flight probe in the half-open state — the old behaviour let a burst of callers all punch through, which defeated the point. `NonceManager` uses a proper FIFO Completer-queue mutex and refuses to release nonces that were already committed on-chain. `AccountAwaiter` and `Paginator` dedup is keyed correctly now; backoffs cap at the remaining timeout instead of sleeping past it. There's a new `RequestThrottle` token-bucket utility for smoothing bursts against rate-limited endpoints (API is ~30 rps per IP).

`TransactionWatcher` accepts optional `numShards` + `roundDuration` + `awaitCrossShardCompletion` flags. When set, it waits for the chain's `completedTxEvent` / `SCDeploy` / `signalError` log before returning — no more premature "success" snapshots for cross-shard SC calls.

### Wallet & accounts

Keystore parsing rejects non-v4 / wrong-cipher / wrong-kdf at load time instead of throwing downstream with a confusing message. `ScryptKeyDerivationParams.permissive()` accepts weaker parameters from external wallets but still requires `n >= 1024`. Mnemonic derivation and the BIP-39 passphrase are NFKD-normalised now (new dep: `unorm_dart`) — this matters for non-ASCII passphrases. `Account.fromMnemonic` disposes the mnemonic in `finally`. `Signature.fromBytes` rejects non-64-byte inputs. `Bech32Encoder` rejects mixed-case strings per BIP-0173.

`IAccount` picks up `prefersHashSigning`, `signAsGuardian`, and `signAsRelayer` — the minimal surface a controller needs to support hardware and remote signers without hard-coding the key material.

### Codegen

Queries that return a struct, an enum, or a list of them used to crash at runtime because the generated `fromAbi` path only handled primitives. They work now, including `List<Struct>` via `(result.typedValues[i] as ListValue).elements.map(...).toList()`. Reserved-word parameter names (`new`, `function`, `class`, etc.) get sanitised. Unused imports are gone. `example/cookbook/generated/pair` regenerates analyzer-clean.

### Core types

`Address` equality now includes the HRP (two addresses with identical bytes but different `hrp` are not equal — they represent different networks), and `AddressComputer.computeContractAddress` propagates the deployer's HRP instead of hard-coding `"erd"`. `Transaction.data` and `Message.bytes` return defensive / unmodifiable views so callers can't mutate the source. `Balance` gained `*`, `~/`, `%`, and `ratioTo`. Numerical `toBytes()` methods now return fresh allocations instead of shared mutable singletons. `AccountStorage` picked up ESDT key-prefix helpers: `esdtEntry`, `esdtRolesEntry`, `esdtLastNonceEntry`, `entriesWithPrefix`.

### Mnemonic-from-keystore

Three new public entry points for integrators that need to recover the mnemonic directly from a `kind == "mnemonic"` keystore:
- `UserWallet.loadMnemonic(path, password)` — reads a keystore file and returns the decrypted `Mnemonic`.
- `UserWallet.decryptMnemonic(json, password)` — same thing, but from an already-parsed JSON map.
- `UserWallet.decryptMnemonicBytes(json, password)` — returns the raw UTF-8 bytes of the mnemonic phrase, so external libraries can build their own wrapper without going through the `Mnemonic` class.

### Breaking changes

- `Address ==` / `hashCode` include the HRP.
- `Signature.fromBytes` / `.fromUint8List` reject non-64-byte inputs.
- `IAccount` has three new required members: `prefersHashSigning`, `signAsGuardian`, `signAsRelayer`.
- `SendTransactionsResult` adds an `outcomes` field.
- `Transaction` adds `innerTransactions`.
- `Transaction.data` and `Message.bytes` are no longer mutable.
- `TransactionComputer.applyGuardian` throws `StateError` when replacing a different guardian (instead of silently overwriting).

## [1.0.1] – 2026-04-16

### Security
- Transaction fee calculation now uses pure integer arithmetic instead of lossy `double` multiplication, matching `mx-chain-go` behaviour for gas prices exceeding 2^53.
- `ProtoSerializer._serializeValue` rejects negative `BigInt` values at runtime instead of silently producing malformed hex.
- `Address.hashCode` uses FNV-1a with `& 0x7FFFFFFF` mask, preventing unbounded integer growth on web targets.
- `Balance.fromEgld` and `ManagedDecimalValue.fromDouble` use `toStringAsFixed` to eliminate IEEE 754 floating-point noise before parsing.
- `Ed25519Crypto.generatePublicKey` now zeros extracted seed bytes in a `finally` block, matching the pattern already used in `sign`.
- `ListBinaryCodec.decodeTopLevel` guards against zero-progress decoding loops that could cause infinite loops / OOM.
- `Address.fromHex` validates decoded byte length at runtime (not just via debug `assert`).
- `BooleanBinaryCodec` and `OptionBinaryCodec` marker buffers now return fresh allocations instead of shared mutable singletons.
- `UserSecretKey.generate` rejects all-zeros and all-0xFF seeds from `Random.secure()`.

### Fixed
- `SmartContractResult.fromJson` no longer throws `FormatException` when a network response returns a numeric `value` field (Gateway and some API shapes emit `value: 0` as `int`).
- Generator `models_generator.dart` now emits the enum-discriminant guard as a braced block so regenerated code stays analyzer-clean under `curly_braces_in_flow_control_structures`.
- Applied the same block-style fix to the committed generated output under `example/cookbook/generated/`.

### Changed
- Removed the arbitrary max-scale-77 restriction from `ManagedDecimalBinaryCodec.encodeNested` to match `encodeTopLevel` and the Rust SDK.
- Added `@visibleForTesting BinaryCodec.resetCache()` to allow test isolation of the codec singleton.
- `NativeSerializer._toBigInt` uses `BigInt.from(value)` directly for doubles instead of the truncating `BigInt.from(value.toInt())`.
- `Transaction.copyWith` accepts an optional `newData` parameter.
- `Nonce.operator -` throws `ArgumentError` at runtime if the result would be negative, instead of relying on a debug-only `assert`.
- Added `ScryptKeyDerivationParams.permissive()` constructor for keystore import/decryption, accepting weaker KDF parameters from external wallets. `EncryptedData.fromJson` now uses it.
- `Address.getShardOfAddress` uses integer bit-scan instead of floating-point `log` for the shard mask computation.
- Codebase-wide `dart format` sweep to satisfy the `dart format --set-exit-if-changed` CI gate.

## [1.0.0] – 2026-04-12

### Fixed
- Hardened `Address._extractHrp` against malformed Bech32 strings where `'1'` appears at index 0.
- `TransactionVersion` values parsed from network responses (`Transaction.fromPlainObject`, `TransactionOnNetwork.fromApiResponse`) now go through a runtime-validated factory that rejects `value <= 0` even in release builds.
- `CircuitBreaker` now resets `_halfOpenSuccessCount` when transitioning half-open → open on failure, preventing state leakage across rapid open/half-open cycles.
- Fixed two's complement encoding for negative values in `NumericalValue.toTopBytes()` -- was missing +1 carry propagation.
- Fixed `BigIntValue.toBytes()` sign extension -- positive values with high bit set now get 0x00 prefix.
- Fixed `ProtoSerializer` zero-value encoding from `[0x00, 0x00]` to `[0x00]`, correcting transaction hash computation.
- Fixed `ManagedDecimalBinaryCodec` nested decode/encode for fixed-scale types -- payload offset was off by 4 bytes and length prefix was missing.
- Fixed `ManagedDecimalSignedValue.fromDouble` / `.fromString` -- was always throwing CastError due to parent-to-subclass cast.
- Fixed `ManagedDecimalValue.toDecimalString()` sign loss for values between -1 and 0.
- Corrected Option top-level encoding to omit marker byte (None = empty, Some = raw inner value).
- Fixed `NativeSerializer` variadic argument handling -- cardinality check and index-based access both failed for variadic endpoints.
- Fixed `TransactionStatus.isFinal` from `!isPending` to `isExecuted || isFailed || isInvalid || isRecalled` -- previously incorrectly classified `not-executable-in-block` as final (causing watchers to stop early), and classified `recalled` as non-final (causing infinite polling).
- Fixed `TransactionWatcher` to use injected `NetworkProvider` instead of raw Dio with hardcoded URL.
- Fixed `UserPublicKey.toAddress(hrp:)` -- was silently ignoring the `hrp` parameter.
- Fixed `ArgSerializer.stringToBuffers` returning `[Uint8List(0)]` for empty input instead of `[]`.
- Fixed `SmartContractCallFactory` hardcoded `TransactionVersion(1)` -- now version 2 when guardian is set.
- Fixed `SmartContractQueryRunner` sharing a single `EndpointResolver` between query building and response parsing.
- Fixed `Address.fromBech32` HRP extraction to use `lastIndexOf` for Bech32/BIP-0173 compliance.
- Fixed `Address.fromBech32` static encoder with hardcoded 'erd' -- now creates encoder with extracted HRP.
- Fixed `SmartContractOutcomeParser` to pick last `writeLog` event instead of throwing on multiples.
- Fixed `NativeSerializer` to respect endpoint mutability and skip return-type decoding for write endpoints.
- Fixed `NativeSerializer._toBytes` from UTF-16 `codeUnits` to proper `utf8.encode()`.
- Fixed `NativeSerializer._convertNativeToAddress` to accept any HRP, not just 'erd'.
- Fixed `GatewayNetworkProvider` response parsing to use correct field names and safe null handling.
- Fixed `ResponseParser._stringToBytes` to try base64 before hex, matching API response format.
- Fixed `ResponseParser._isOptionalType` from string comparison to proper type check.
- Fixed `TransactionOnNetwork.fromApiResponse` to handle non-base64 data fields gracefully.
- Fixed `EndpointResolver._isVariadicParameter` from fragile string matching to `param.type is VariadicType`.
- Fixed `TypeFormulaLexer` to accept hyphens in type identifiers (e.g. `counted-variadic`).
- Fixed token identifier validation to enforce 6-character hex ticker suffix.
- Fixed `AccountAwaiter` default timeout from 30s to 60s and added retry with exponential backoff.
- Fixed `AddressValue.getShardId()` from simple modulo to proper bit-masking algorithm.
- Fixed `BigInt` type name casing to match SDK convention.
- Fixed `EndpointResolver` to throw on duplicate endpoint names.
- Fixed `ManagedDecimal` scale validation (must be non-negative).
- Fixed `SmartContractEventRunner` to use bounded `EventDeduplicator` instead of unbounded `Set`.
- Fixed `Paginator._fetch()` race condition with proper request deduplication.
- Input validation across infrastructure layer (circuit breaker, cache, batch, pagination).

### Changed
- `TransactionStatus` now includes `executed`, `notExecutable`, and `recalled` statuses.
- `SmartContractEventRunner` subscriptions now return `StreamSubscription` for proper lifecycle management.
- `WebSocketEventStream` reconnection uses exponential backoff with jitter.
- `AccountOnNetwork` fields (`nonce`, `balance`, `address`) are now required.
- `TransactionOnNetwork` adds null-safe access for optional API fields.
- `EnumValue`/`ExplicitEnumValue` discriminant encoding standardized to u8.
- `VariadicValues` validates matching lengths between values and types.
- `ArgumentEncoder.encodeTypedValues` now expands variadic and composite types into separate arguments.
- Codegen: `CallsGenerator` no longer imports unused output types; fixes unused import warnings.
- Codegen: generated files now include `GENERATED CODE - DO NOT MODIFY` header.
- Codegen: enum `fromAbi` uses discriminant lookup instead of array index.
- Codegen: `toJson()` properly serializes nested structs, enums, BigInt, and Address fields.

### Added
- `not-executable-in-block` and `recalled` transaction status support.
- `CompositeValue.isEmpty` / `isNotEmpty` convenience getters.
- `TokenTransferType` support in code generator type mapper.
- `Address.isZero` getter for zero-address checks without allocating a new `Address.zero()`.
- `TransactionAwaitingOptions.maxConsecutiveErrors` -- aborts polling after repeated fetch failures with exponential backoff.
- `TransactionAwaitingOptions.patience` -- waits for block finalization after status reaches final state.
- `AbiEndpoint.mutability` / `isPure` / `isReadonly` -- preserves raw mutability ('pure' vs 'readonly' vs 'mutable').
- `NetworkProvider.getDefinitionOfFungibleToken`, `getDefinitionOfTokenCollection`, and `getNonFungibleToken` -- rich token metadata queries on the API provider (Gateway surfaces these via `UnsupportedError`, matching the other metadata endpoints).
- `NetworkProvider.getBlock`, `getLatestBlock(shard:)`, and `getHyperblock(nonce)` -- block and cross-shard hyperblock queries. Gateway `getLatestBlock` two-hops through `network/status/<shard>` to resolve the current nonce.
- `BlockOnNetwork` and `HyperblockOnNetwork` types with schema-tolerant `fromJson` factories that accept both API and Gateway field aliases.
- Typed `SmartContractResult` parsed eagerly from the `@<returnCode>@<returnData>...` payload. `TransactionOnNetwork.smartContractResults` is now `List<SmartContractResult>?` (was `List<Map<String, dynamic>>?`).
- `NonceManager` -- stateful forward-only nonce allocator with mutex-serialized `next()`, release/reuse queue, `applyNonce(Nonce)` floor, and `resync()` that never goes backwards. Use it for bulk sends without round-tripping `getAccount` between each transaction.
- `TransactionDecoder` -- pure, never-throwing parser that turns a `Transaction` into a sealed `DecodedTransaction` hierarchy: `NativeEgldTransfer`, `EsdtTransfer`, `NftTransfer`, `MultiTransfer`, `ContractCall`, `UnknownTransaction`. Supports inner contract calls nested after ESDT/NFT/MultiESDT transfer prefixes.

### Changed
- `TransactionAwaitingOptions` defaults: polling 400ms, patience 800ms, timeout 60s -- tuned for Supernova block times.
- `SmartContractEventRunner.streamEvents` / `streamAllEvents` default polling lowered from 2s to 500ms for Supernova 600ms blocks.
- `CacheManager` caps the number of cache instances to prevent unbounded growth from high-cardinality endpoints.
- `_encodeSignedTopLevel` allocates directly into `Uint8List` instead of spreading through a temporary list.
- `base_controller` guardian/relayer checks use `isZero` getter instead of allocating `Address.zero()` per call.
- Codegen `CallsGenerator._collectCustomTypes` now includes output types to avoid missing imports for custom return types.
- Codegen `NameSanitizer` keyword lookup is now case-insensitive and includes `function` consistently with `KeywordSanitizer`.

### Security
- `PubkeyDecryptor` zeros secret key bytes in a `finally` block after decryption.
- `ScryptKeyDerivationParams` now validates KDF parameters per RFC 7914: `n` must be power of 2 and ≥ 16384, `r` ≥ 8, `p` ≥ 1, `dklen` = 32. Prevents weak-parameter keystores from decrypting silently.
- `EncryptedData.fromJson` surfaces invalid KDF parameters from untrusted keystore input as `FormatException` rather than passing through silently.

## [1.0.0-beta.2] – 2025-12-20

### Fixed
- Fixed dangling library doc comments in codegen files.
- Updated package description to meet pub.dev length requirements.
- Replaced `flutter_lints` with `lints` for pure Dart compatibility.

## [1.0.0-beta.1] – 2025-12-08

### Added
- First public release of the MultiversX Dart/Flutter SDK and CLI.
- Wallet tooling covering mnemonic, PEM, and keystore workflows.
- Transaction builders for EGLD, ESDT, NFT, SFT, and MetaESDT transfers.
- High-level smart-contract controller with ABI-driven calls, queries and events.
- Gateway and REST network providers plus WebSocket event streams.
- ABI codecs for primitives, collections, composites, and protocol-specific special types.
- Code generator capable of scaffolding controllers, DTOs, and tests from ABI files.
- Cookbook examples and wallet walkthroughs demonstrating real integrations.
- 900+ automated tests spanning core types, infrastructure, serializers, and integration scenarios.

[2.0.0]: https://github.com/ABIdock/abidock_mvx/releases/tag/v2.0.0
[1.2.0]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.2.0
[1.1.0]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.1.0
[1.0.1]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.0.1
[1.0.0]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.0.0
[1.0.0-beta.2]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.0.0-beta.2
[1.0.0-beta.1]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.0.0-beta.1
