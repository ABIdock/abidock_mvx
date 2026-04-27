# Changelog

All notable changes to `abidock_mvx` are documented here. We follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) and the structure recommended by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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

[1.2.0]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.2.0
[1.1.0]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.1.0
[1.0.1]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.0.1
[1.0.0]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.0.0
[1.0.0-beta.2]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.0.0-beta.2
[1.0.0-beta.1]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.0.0-beta.1
