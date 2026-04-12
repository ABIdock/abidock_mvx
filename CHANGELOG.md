# Changelog

All notable changes to `abidock_mvx` are documented here. We follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) and the structure recommended by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.0.0] – 2026-04-12

### Fixed
- Hardened `Address._extractHrp` against malformed Bech32 strings where `'1'` appears at index 0.
- `TransactionVersion` values parsed from network responses (`Transaction.fromPlainObject`, `TransactionOnNetwork.fromApiResponse`) now go through a runtime-validated factory that rejects `value <= 0` even in release builds.
- `CircuitBreaker` now resets `_halfOpenSuccessCount` when transitioning half-open → open on failure, preventing state leakage across rapid open/half-open cycles.
- Fixed two's complement encoding for negative values in `NumericalValue.toTopBytes()` — was missing +1 carry propagation.
- Fixed `BigIntValue.toBytes()` sign extension — positive values with high bit set now get 0x00 prefix.
- Fixed `ProtoSerializer` zero-value encoding from `[0x00, 0x00]` to `[0x00]`, correcting transaction hash computation.
- Fixed `ManagedDecimalBinaryCodec` nested decode/encode for fixed-scale types — payload offset was off by 4 bytes and length prefix was missing.
- Fixed `ManagedDecimalSignedValue.fromDouble` / `.fromString` — was always throwing CastError due to parent-to-subclass cast.
- Fixed `ManagedDecimalValue.toDecimalString()` sign loss for values between -1 and 0.
- Corrected Option top-level encoding to omit marker byte (None = empty, Some = raw inner value).
- Fixed `NativeSerializer` variadic argument handling — cardinality check and index-based access both failed for variadic endpoints.
- Fixed `TransactionStatus.isFinal` from `!isPending` to `isExecuted || isFailed || isInvalid || isRecalled` — previously incorrectly classified `not-executable-in-block` as final (causing watchers to stop early), and classified `recalled` as non-final (causing infinite polling).
- Fixed `TransactionWatcher` to use injected `NetworkProvider` instead of raw Dio with hardcoded URL.
- Fixed `UserPublicKey.toAddress(hrp:)` — was silently ignoring the `hrp` parameter.
- Fixed `ArgSerializer.stringToBuffers` returning `[Uint8List(0)]` for empty input instead of `[]`.
- Fixed `SmartContractCallFactory` hardcoded `TransactionVersion(1)` — now version 2 when guardian is set.
- Fixed `SmartContractQueryRunner` sharing a single `EndpointResolver` between query building and response parsing.
- Fixed `Address.fromBech32` HRP extraction to use `lastIndexOf` for Bech32/BIP-0173 compliance.
- Fixed `Address.fromBech32` static encoder with hardcoded 'erd' — now creates encoder with extracted HRP.
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
- `TransactionAwaitingOptions.maxConsecutiveErrors` — aborts polling after repeated fetch failures with exponential backoff.
- `TransactionAwaitingOptions.patience` — waits for block finalization after status reaches final state.
- `AbiEndpoint.mutability` / `isPure` / `isReadonly` — preserves raw mutability ('pure' vs 'readonly' vs 'mutable').
- `NetworkProvider.getDefinitionOfFungibleToken`, `getDefinitionOfTokenCollection`, and `getNonFungibleToken` — rich token metadata queries on the API provider (Gateway surfaces these via `UnsupportedError`, matching the other metadata endpoints).
- `NetworkProvider.getBlock`, `getLatestBlock(shard:)`, and `getHyperblock(nonce)` — block and cross-shard hyperblock queries. Gateway `getLatestBlock` two-hops through `network/status/<shard>` to resolve the current nonce.
- `BlockOnNetwork` and `HyperblockOnNetwork` types with schema-tolerant `fromJson` factories that accept both API and Gateway field aliases.
- Typed `SmartContractResult` parsed eagerly from the `@<returnCode>@<returnData>...` payload. `TransactionOnNetwork.smartContractResults` is now `List<SmartContractResult>?` (was `List<Map<String, dynamic>>?`).
- `NonceManager` — stateful forward-only nonce allocator with mutex-serialized `next()`, release/reuse queue, `applyNonce(Nonce)` floor, and `resync()` that never goes backwards. Use it for bulk sends without round-tripping `getAccount` between each transaction.
- `TransactionDecoder` — pure, never-throwing parser that turns a `Transaction` into a sealed `DecodedTransaction` hierarchy: `NativeEgldTransfer`, `EsdtTransfer`, `NftTransfer`, `MultiTransfer`, `ContractCall`, `UnknownTransaction`. Supports inner contract calls nested after ESDT/NFT/MultiESDT transfer prefixes.

### Changed
- `TransactionAwaitingOptions` defaults: polling 400ms, patience 800ms, timeout 60s — tuned for Supernova block times.
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

[1.0.0]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.0.0
[1.0.0-beta.2]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.0.0-beta.2
[1.0.0-beta.1]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.0.0-beta.1
