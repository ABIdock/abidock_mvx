---
name: public-api
title: Public API Map
summary: After reading this an agent knows every symbol reachable from the package barrel, grouped by subsystem, and never has to guess a class name again.
reads: [00-quickstart.md]
verified_against: abidock_mvx 3.1.0 (Dart 3.13)
---

**When to use this** — before naming any type from this package. Look the name
up here; if it is absent from this file it is not exported.

## How this list was produced

`lib/abidock_mvx.dart` re-exports six subsystem barrels
(`lib/abidock_mvx.dart:5-10`). Every `export` was resolved transitively —
**231 library files reached**, `show`/`hide` combinators applied — the public
top-level declarations extracted, and the result mechanically compiled: one
`void t_X(X? v) {}` per class/mixin/enum/typedef and one `final Object? c_X = X;`
per top-level constant, all in a single file importing only the barrel.
**502 of 503 type names and all 54 constants resolve.**
The single non-resolving name is `TokenType`, which the ABI barrel deliberately
hides (`lib/src/abi/abi.dart` re-exports `core/core.dart`, which applies
`hide Token, TokenType` to `type_formula_parser.dart`).

The 502 resolving type names break down as 484 classes, 10 enums, 7 typedefs and
1 mixin. Extensions cannot be named as types, so the 27 extension names below
were taken from their declarations rather than the compile probe; they live in
the same already-verified library files. **21 top-level functions** are also
exported — §13 lists them.

`test/public_surface_test.dart` is the repo's own reachability guard and covers
the same seven subsystem groups.

## Exported vs internal

**Exported** (reachable from `package:abidock_mvx/abidock_mvx.dart`): everything
in this file — `src/abi`, `src/core`, `src/entrypoints`, `src/infrastructure`,
`src/utils`, `src/wallet`.

**Not reachable at all** — verified by compile probe against the 3.1.0 barrel,
each one an `undefined_class` error: `Pem`, `ValidatorPem`, `CryptoUtils`
(`lib/src/wallet/crypto/crypto_utils.dart`), `RawArgumentValidator`
(`lib/src/abi/smart_contract/utils/argument_validation.dart`) and `TokenType`.
Two helper libraries are imported but never exported, so nothing in them is
reachable either: `lib/src/wallet/crypto/curve25519_conversion.dart`
(`ed25519PublicKeyToX25519`, `ed25519SeedToX25519SecretKey`) and
`lib/src/core/transaction/factories/_factory_helpers.dart` (`evenHexInt`).

**Reachable but low-level**: the 21 top-level functions in §13, including those
in `lib/src/wallet/pem.dart`, `lib/src/wallet/validator_pem.dart`,
`lib/src/wallet/assertions.dart` and `lib/src/utils/helpers.dart`. These *do*
resolve from the barrel — a compile probe naming all 21 analyzes clean — so
treat them as public even though the higher-level classes cover the same ground.

**Not a library at all**: `bin/` holds the `abidock` code generator CLI. It is
not importable; invoke it as `dart run abidock_mvx:abidock <command>`.

---

# 1. Core primitives

| Symbol | Purpose |
|---|---|
| `Address` | Bech32 / hex / bytes account address |
| `AddressException` | Address parse or validation failure |
| `AddressComputer` | Derives deployed contract addresses |
| `Balance` | EGLD amount in attoEGLD |
| `Nonce` | Account or token nonce wrapper |
| `Signature` | 64-byte signature wrapper |
| `ChainId` | Chain identifier for a transaction |
| `CodeMetadata` | Contract code-metadata flag bitmap |
| `TokenOnNetwork` | Token record as served by the network |
| `NetworkConfiguration` | Chain-wide gas and version defaults |
| `MainnetNetworkConfiguration` | Mainnet preset of the above |
| `TestnetNetworkConfiguration` | Testnet preset of the above |
| `DevnetNetworkConfiguration` | Devnet preset of the above |

**Constants**: `denomination` (18), `oneEGLD` (`BigInt` 10^18),
`defaultChainId` (`'1'`), `defaultGasPerDataByte` (1500), `defaultMinGasLimit`
(50000), `defaultMinGasPrice` (1000000000), `defaultGasPriceModifier` (0.01),
`defaultMinTransactionVersion` (1). Values at `lib/src/core/balance.dart:2,5`
and `lib/src/core/network_configuration.dart:8-23`.

## Tokens

| Symbol | Purpose |
|---|---|
| `TokenIdentifier` | Typed ESDT/NFT/SFT/META identifier string |
| `EgldOrEsdtTokenIdentifier` | Identifier that may be the EGLD sentinel |
| `Token` | Identifier plus optional instance nonce |
| `EsdtTokenPayment` | ESDT identifier, nonce and amount |
| `EgldOrEsdtTokenPayment` | Payment carrying EGLD or an ESDT |
| `TokenComputer` | Splits and composes extended identifiers |
| `TokenNonceBytes` | `typedef TokenNonceBytes = Uint8List` (`lib/src/core/tokens/token_computer.dart:216`) |

**Constant**: `egldIdentifier == 'EGLD-000000'`
(`lib/src/core/tokens/token.dart:10`).

## Messages

| Symbol | Purpose |
|---|---|
| `Message` | Arbitrary payload to sign or verify |
| `MessageComputer` | Builds the canonical signing/verifying bytes |

**Constants**: `messagePrefix`, `canonicalMessagePrefix` — both
`'\x17Elrond Signed Message:\n'` (`lib/src/core/message/base.dart:18`,
`lib/src/core/message/message_computer.dart:229`).

## Accounts

| Symbol | Purpose |
|---|---|
| `IAccount` | Signing abstraction consumed by controllers |
| `Account` | Local-key account implementing `IAccount` |
| `AccountOnNetwork` | Account state snapshot from the chain |
| `AccountGuardian` | Guardian entry attached to an account |

---

# 2. Wallet and crypto

| Symbol | Purpose |
|---|---|
| `UserSecretKey` | Ed25519 secret key, zeroed on dispose |
| `UserPublicKey` | Ed25519 public key, derives the address |
| `UserSigner` | Signs transactions and messages |
| `UserVerifier` | Verifies Ed25519 signatures |
| `UserWallet` | Encrypted keystore container |
| `UserWalletKind` | Keystore kind discriminator |
| `Mnemonic` | BIP39 phrase and key derivation |
| `PemEntry` | Label plus key bytes for PEM I/O |
| `ValidatorPublicKey` | BLS validator public key |
| `ValidatorSecretKey` | BLS validator secret key |
| `ValidatorSigner` | BLS signer; **only** `ValidatorSigner.custom(signFn)` |
| `ValidatorSignFunction` | Typedef for a caller-supplied BLS sign closure |
| `AccountSignerExtensions` | Extension turning an `Account` into a `UserSigner` |
| `Bech32Encoder` | Bech32 encode/decode for addresses |
| `Ed25519Crypto` | Ed25519 primitives with memory zeroing |
| `Encryptor` / `Decryptor` | Scrypt + AES-128-CTR keystore crypto |
| `EncryptorVersion` | Keystore encryption version enum |
| `EncryptedData` | Password-encrypted wallet payload |
| `ScryptKeyDerivationParams` | Scrypt KDF parameters |
| `Randomness` | Cryptographically secure random bytes |
| `PubkeyEncryptor` / `PubkeyDecryptor` | X25519-XSalsa20-Poly1305 encryption |
| `X25519EncryptedData` | Container for X25519 ciphertext |
| `X25519Identities` | Recipient/originator/ephemeral key triple |

**Constants**: `mnemonicStrength` (256), `bip44DerivationPrefix`
(`"m/44'/508'/0'/0'"`), `userSeedLength` (32), `userPubkeyLength` (32),
`validatorSecretKeyLength` (32), `validatorPublicKeyLength` (96),
`cipherAlgorithm` (`'aes-128-ctr'`), `digestAlgorithm` (`'sha256'`),
`keyDerivationFunction` (`'scrypt'`), `pubKeyEncVersion` (1),
`pubKeyEncNonceLength` (24), `pubKeyEncCipher`
(`'x25519-xsalsa20-poly1305'`). Sources: `lib/src/wallet/mnemonic.dart:14-15`,
`lib/src/wallet/user_keys.dart:15-16`, `lib/src/wallet/validator_keys.dart:10-11`,
`lib/src/wallet/crypto/constants.dart:5-20`.

`ValidatorSigner` has exactly one constructor:
`const ValidatorSigner.custom(ValidatorSignFunction signFn)`
(`lib/src/wallet/validator_signer.dart:37`). There is no key-taking constructor
and no `fromPem`.

---

# 3. Transaction model

| Symbol | Purpose |
|---|---|
| `Transaction` | The transaction the chain accepts |
| `TransactionComputer` | Serialization, hashing, signing helpers |
| `TransactionVersion` | Version field wrapper |
| `TransactionStatus` | Chain-reported execution status |
| `TransactionOnNetwork` | Executed transaction as served by a provider |
| `TransactionLogs` | Log block attached to a transaction |
| `TransactionEvent` | One event inside a log block |
| `TransactionEventParser` | Decodes events with ABI codecs |
| `ParsedEvent` | Raw event plus decoded typed values |
| `UnexpectedEventCountException` | Raised when 0-or-1 event expectation fails |
| `SmartContractResult` | Cross-shard / async execution output |
| `ProtoSerializer` | Protocol-buffer form of a transaction |
| `TransactionWatcher` | Polls until a transaction is final |
| `TransactionAwaitingOptions` | Polling timeout / interval configuration |
| `TransactionsFactoryConfig` | Shared config every factory derives from |
| `GasLimit`, `GasPrice`, `GasPriceModifier` | Validated fee scalars |
| `GasEstimator` | Node-simulation gas estimator |
| `GasEstimationResult` | Estimate plus confidence metadata |
| `NonceManager` | Stateful nonce allocator for one address |

`Transaction` constructor (`lib/src/core/transaction/transaction.dart:93-111`):

```
Transaction({
  required Nonce nonce,
  required Address sender,
  required Address receiver,
  required Uint8List data,
  required GasLimit gasLimit,
  required GasPrice gasPrice,
  required ChainId chainId,
  required TransactionVersion version,
  Balance? value,
  String senderUsername = '',
  String receiverUsername = '',
  int options = 0,
  Signature signature = const Signature.empty(),
  Address? guardian,
  Signature guardianSignature = const Signature.empty(),
  Address? relayer,
  Signature relayerSignature = const Signature.empty(),
})
```

There is **no `innerTransactions` field**. Relayed v3 is one flat transaction
carrying `relayer` + `relayerSignature`
(`lib/src/core/transaction/factories/relayed_transactions_factory.dart:4-6`).

**Transaction constants**: `transactionOptionsDefault` (0),
`transactionOptionsTxHashSign` (1), `transactionOptionsTxGuarded` (2),
`minTransactionVersionThatSupportsOptions` (2)
(`lib/src/core/transaction/transaction_constants.dart:4-9`);
`extraGasLimitForGuardedTransactions` (50000),
`extraGasLimitForRelayedTransactions` (50000)
(`lib/src/core/transaction/controllers/base_controller.dart:18,21`).

## Timestamps

`TransactionOnNetwork` carries both `int? timestamp` and `int? timestampMs`.
`timestamp` is reported in **seconds or milliseconds depending on the route** —
the chain switches units at the Supernova epoch without renaming the field.
Read `DateTime? get executedAt`, which normalises by magnitude via
`ChainTimestamp.toDateTime`
(`lib/src/core/transaction/transaction_on_network.dart:536-567`).
`String? relayedVersion` also lives here, not on `Transaction`
(`transaction_on_network.dart:659`).

## Transaction decoder

`TransactionDecoder` turns a `Transaction` into a sealed `DecodedTransaction`.
Variants: `NativeEgldTransfer`, `EsdtTransfer`, `NftTransfer`, `MultiTransfer`
(with `MultiTransferItem`), `ContractCall`, `ContractDeploy`, `ContractUpgrade`,
`ContractChangeOwner`, `ClaimDeveloperRewards`, `UnknownTransaction`; plus
`DecodedContractCall` for the `<function>@<argHex>…` view.

---

# 4. Transaction factories (unsigned drafts)

Each factory takes its matching `*Config`. Two shapes exist — check before
calling:

- `SmartContractTransactionsFactory(config)` — **positional**
  (`lib/src/core/transaction/factories/smart_contract_transactions_factory.dart:44`).
- Every other factory takes a named `config:`.

Every `*Config` except `SmartContractTransactionsConfig` has a static
`fromShared(TransactionsFactoryConfig)` (verified by grepping `fromShared`
across `lib/src/core/transaction/factories/`).

| Factory | Config | Purpose |
|---|---|---|
| `TransferTransactionsFactory` | `TransferTransactionsConfig` | EGLD and ESDT/NFT transfers |
| `TokenManagementTransactionsFactory` | `TokenManagementConfig` | Issue, roles, mint, freeze, metadata |
| `DelegationTransactionsFactory` | `DelegationTransactionsConfig` | Delegation contract lifecycle |
| `AccountTransactionsFactory` | `AccountTransactionsConfig` | Guardian and key-value storage |
| `SmartContractTransactionsFactory` | `SmartContractTransactionsConfig` | Deploy, upgrade, change owner, claim rewards |
| `MultisigTransactionsFactory` | `MultisigTransactionsConfig` | Multisig propose / sign / perform |
| `GovernanceTransactionsFactory` | `GovernanceTransactionsConfig` | Proposals and votes |
| `StakingTransactionsFactory` | `StakingTransactionsConfig` | Direct-staking system contract |
| `ValidatorsTransactionsFactory` | `ValidatorsTransactionsConfig` | Validator system contract |
| `RelayedTransactionsFactory` | `RelayedTransactionsConfig` | Attaches a relayer to an existing transaction |
| `BaseFactory` | — | Shared gas-limit resolution helper |

Supporting types: `TokenTransfer` (a single transfer leg), `TokenProperties`
(issuance flags), `SignedValidatorPublicKey` (BLS key + proof-of-key signature),
`VoteType` (governance vote enum).

**Factory gas** is always data-movement gas plus execution gas:
`minGasLimit + gasLimitPerByte * data.length + executionGasLimit`
(`lib/src/core/transaction/factories/token_management_transactions_factory.dart:1254-1262`).

**Relayed v3**: `RelayedTransactionsFactory.applyRelayer(transaction, relayer)`
returns a copy with `relayer` set; it must be called **before** anyone signs,
because the relayer address is part of the signed payload
(`relayed_transactions_factory.dart:88-96`). Then sender and relayer each sign
the same bytes, in any order. `createRelayedTransaction` no longer exists.

## System contract addresses

| Constant | Value |
|---|---|
| `esdtContractAddressHex` | `…0000000002ffff` |
| `governanceContractAddressHex` | `…0000000003ffff` |
| `governanceContractBech32` | `erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqrlllsrujgla` |
| `stakingContractAddressHex` | `…0000000001ffff` (validator / auction contract) |
| `stakingContractBech32` | `erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqplllst77y4l` |
| `delegationManagerContractBech32` | `erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqylllslmq6y6` |

Sources: `token_management_transactions_factory.dart:10`,
`governance_transactions_factory.dart:21,25`,
`staking_transactions_factory.dart:35,39`,
`validators_transactions_factory.dart:33`.

## Other factory constants

| Constant | Value | Declared at |
|---|---|---|
| `tokenTypeFungible` | `'FNG'` | `token_management_transactions_factory.dart:14` |
| `tokenTypeMeta` | `'META'` | `token_management_transactions_factory.dart:17` |
| `tokenTypes` | `{'NFT','SFT','META','FNG'}` — accepted by `registerAndSetAllRoles` | `…:20` |
| `dynamicTokenTypes` | `{'NFT','SFT','META'}` — accepted by the dynamic registration endpoints | `…:28` |
| `additionalGasForEsdtTransfer` | `100000` | `transfer_transactions_factory.dart:10` |
| `additionalGasForEsdtNftTransfer` | `800000` | `transfer_transactions_factory.dart:11` |
| `egldIdentifierForMultiTransfer` | `'EGLD-000000'` | `transfer_transactions_factory.dart:20` |

## The ESDT receiver split — get this right

`TokenManagementTransactionsFactory._buildTransaction` chooses the receiver:

```
receiver: receiverIsSender ? sender : _esdtContractAddress
```

(`token_management_transactions_factory.dart:1259`)

**Addressed to the SENDER** (built-in functions, they execute against the
caller's own account): `ESDTNFTCreate`, `ESDTLocalMint`, `ESDTLocalBurn`,
`ESDTNFTUpdateAttributes`, `ESDTNFTAddQuantity`, `ESDTNFTBurn`,
`ESDTModifyRoyalties`, `ESDTSetNewURIs`, `ESDTModifyCreator`, `ESDTNFTUpdate`,
`ESDTNFTRecreate`, `ESDTMetaDataUpdate`, `ESDTMetaDataRecreate`,
`ESDTNFTAddURI`.

**Addressed to the ESDT system contract**: everything else — `issue`,
`setSpecialRole`, `unSetSpecialRole`, `pause`, `unPause`, `freeze`, `unFreeze`,
`wipe`, and the remaining system endpoints.

The chain's endpoint name is **`unFreeze`** — lower-case `f`
(`token_management_transactions_factory.dart:648`). Not `UnFreeze`.

## Token properties

`TokenProperties({bool canFreeze = false, bool canWipe = false, bool canPause = false, bool canTransferNFTCreateRole = false, bool canChangeOwner = false, bool canUpgrade = true, bool canAddSpecialRoles = false})`
(`token_management_transactions_factory.dart:131-139`).

Every supported property is emitted as a `name`, `'true'|'false'` pair — never
just the enabled ones. Omitting a pair does **not** mean disabled; the contract
creates tokens with `canUpgrade` and `canAddSpecialRoles` already on and
overrides only what is present. The fungible `issue` argument list omits
`canTransferNFTCreateRole`; the collection endpoints include it
(`token_management_transactions_factory.dart:1205-1226`).

---

# 5. Controllers (build, configure and sign)

| Controller | Purpose |
|---|---|
| `BaseController` | Nonce/version/gas setup plus signing |
| `TransfersController` | EGLD and ESDT transfers |
| `TokenManagementController` | Token issuance and administration |
| `DelegationController` | Delegation and staking operations |
| `AccountController` | Guardian and account-storage operations |
| `SmartContractController` | Contract query, call, deploy |
| `MultisigController` | Multisig system-contract operations |
| `GovernanceController` | Governance system-contract operations |
| `ValidatorsController` | Validator system-contract operations |

`BaseControllerInput({Address? guardian, Address? relayer, GasPrice? gasPrice, GasLimit? gasLimit})`
is the optional `baseOptions:` on every controller method
(`lib/src/core/transaction/controllers/base_controller.dart:35-61`).
`IGasLimitEstimator` is the single-method interface
`Future<int> estimateGasLimit({required Transaction transaction})`
(`base_controller.dart:64-73`); `GasEstimator` implements it.

## Controller input DTOs

**Transfers**: `NativeTransferInput`, `TokenTransferInput`.

**Account**: `SaveKeyValueInput`, `SetGuardianInput`.

**Delegation**: `NewDelegationContractInput`, `AddNodesInput`,
`ManageNodesInput`, `UnjailingNodesInput`, `ChangeServiceFeeInput`,
`ModifyDelegationCapInput`, `ManageDelegationContractInput`, `SetMetadataInput`,
`DelegateInput`, `UndelegateInput`, `WithdrawInput`.

**Token management** (`token_management_resources.dart`): `IssueInput`,
`IssueFungibleInput`, `IssueNonFungibleInput`, `IssueSemiFungibleInput`,
`RegisterMetaESDTInput`, `RegisterRolesInput`, `BurnRoleGloballyInput`,
`FungibleSpecialRoleInput`, `UnsetFungibleSpecialRoleInput`,
`SemiFungibleSpecialRoleInput`, `UnsetSemiFungibleSpecialRoleInput`,
`SpecialRoleInput`, `UnsetSpecialRoleInput`, `MintInput`, `LocalMintInput`,
`LocalBurnInput`, `ManagementInput`, `PausingInput`, `UpdateInput`,
`UpdateAttributesInput`, `UpdateQuantityInput`, `BaseInput`,
`ModifyRoyaltiesInput`, `ModifyCreatorInput`, `SetNewUriInput`,
`ManageMetadataInput`, `UpdateTokenIDInput`, `ChangeTokenToDynamicInput`,
`RegisteringDynamicTokenInput`.

**Multisig**: `ProposeAddBoardMemberInput`, `ProposeAddProposerInput`,
`ProposeRemoveUserInput`, `ProposeChangeQuorumInput`,
`ProposeTransferExecuteInput`, `ProposeAsyncCallInput`, `SignActionInput`.

**Governance**: `NewProposalInput`, `VoteInput`, `CloseProposalInput`,
`ClearEndedProposalsInput`, `ChangeConfigInput`.

**Validators**: `ToppingUpInput`, `UnjailingInput`, `ChangingRewardsAddressInput`,
`ChangingValidatorKeysInput`, `StakeValidatorsInput`,
`UnstakeOrUnbondTokensInput`, `RestakeUnstakedNodesInput`.

## Controller outcome types

**Multisig**: `MultisigProposalOutcome`, `MultisigActionOutcome`,
`MultisigPerformActionOutcome`, `MultisigParseException`.

**Validators**: `StakeOutcome`, `UnstakeTokensOutcome`, `UnBondTokensOutcome`,
`CleanRegisteredDataOutcome`, `RestakeUnstakedOutcome`,
`ValidatorsParseException`.

---

# 6. Outcome parsers

| Parser | Result types |
|---|---|
| `SmartContractOutcomeParser` | `SmartContractDeployOutcome`, `DeployedContract`, `ParsedSmartContractCallOutcome`, `SmartContractParseException` |
| `TokenManagementOutcomeParser` | `IssueFungibleResult`, `IssueNonFungibleResult`, `IssueSemiFungibleResult`, `RegisterMetaEsdtResult`, `RegisterAndSetAllRolesResult`, `SetSpecialRoleResult`, `NftCreateResult`, `LocalMintResult`, `LocalBurnResult`, `PauseResult`, `UnpauseResult`, `FreezeResult`, `UnfreezeResult`, `WipeResult`, `UpdateAttributesResult`, `AddQuantityResult`, `BurnQuantityResult`, `ModifyRoyaltiesResult`, `SetNewUrisResult`, `ModifyCreatorResult`, `UpdateMetadataResult`, `MetadataRecreateResult`, `ChangeToDynamicResult`, `RegisterDynamicResult`, `TokenManagementParseException` |
| `DelegationOutcomeParser` | `CreateDelegationContractResult`, `DelegationParseException` |
| `GovernanceOutcomeParser` | `NewProposalOutcome`, `VoteOutcome`, `DelegateVoteOutcome`, `CloseProposalOutcome`, `GovernanceParseException` |

---

# 7. ABI subsystem

## Entry points

| Symbol | Purpose |
|---|---|
| `SmartContractAbi` | Whole contract ABI: endpoints, events, types |
| `AbiRegistry` | Registry of several contract ABIs |
| `AbiEndpoint` / `AbiEndpoints` | One endpoint / the endpoint collection |
| `EndpointResolver` / `EndpointType` | Endpoint lookup; kind enum `view`, `readonly`, `pure`, `mutable`, `payable` |
| `EventDefinition` / `EventTopicDefinition` / `EventDefinitions` | ABI event shapes |
| `AbiParameter` / `InputParameters` / `OutputParameters` | Endpoint parameter models |
| `TypeFormula` / `TypeFormulaLexer` / `TypeFormulaParser` | Parses type strings such as `List<u64>` |
| `AbiTypeFactory` | Builds an `AbiType` from a type string |
| `SmartContractAddress` | `typedef SmartContractAddress = Address` (`lib/src/abi/core/core_types.dart:9`) — it *is* `Address`, not a distinct type |
| `SmartContractFunction` | Function name plus typed arguments |
| `BatchQuerySpec` | One entry of a batched query |

`Token` and `TokenType` from the type-formula lexer are **hidden** by the
barrel. The `Token` you get from the barrel is the token DTO
(`lib/src/core/tokens/token.dart`).

## Type system base classes

`AbiType`, `PrimitiveType`, `CustomType`, `TypedValue`, `TypeCardinality`,
`TypeCallback`, `TypeMatchCallbacks`, `ValueMatchCallbacks`, `ValidationMixin`.

## Types and values (always in `XType` / `XValue` pairs)

**Numeric**: `NumericalType`/`NumericalValue`, `IntNumericalValue`,
`BigIntNumericalValue`, `U8Type`/`U8Value`, `U16Type`/`U16Value`,
`U32Type`/`U32Value`, `U64Type`/`U64Value`, `I8Type`/`I8Value`,
`I16Type`/`I16Value`, `I32Type`/`I32Value`, `I64Type`/`I64Value`,
`BigUIntType`/`BigUIntValue`, `BigIntType`/`BigIntValue`,
`BigFloatType`/`BigFloatValue`, `ManagedDecimalType`/`ManagedDecimalValue`,
`ManagedDecimalSignedType`/`ManagedDecimalSignedValue`.

`U8`–`U32` and `I8`–`I32` values store a Dart `int` (`IntNumericalValue`);
`U64`/`I64` store a `BigInt` (`BigIntNumericalValue`)
(`lib/src/abi/types/primitives/numerical.dart`).

**Simple**: `BooleanType`/`BooleanValue`, `StringType`/`StringValue`,
`BytesType`/`BytesValue`, `AddressType`/`AddressValue`, `H256Type`/`H256Value`,
`NothingType`/`NothingValue`, `CodeMetadataType`/`CodeMetadataValue`,
`ManagedByteArrayType`/`ManagedByteArrayValue`.

**Token**: `TokenIdentifierType`/`TokenIdentifierValue`,
`EsdtTokenIdentifierType`/`EsdtTokenIdentifierValue`,
`EgldOrEsdtTokenIdentifierType`/`EgldOrEsdtTokenIdentifierValue`,
`EsdtTokenPaymentType`, `EgldOrEsdtTokenPaymentType`, `TokenTransferType`,
`TokenTransferValue`, `TransferType`.

**Collections**: `ListType`/`ListValue`, `ArrayType`/`ArrayValue`,
`OptionType`/`OptionValue`.

**Composite**: `StructType`/`StructValue`, `TupleType`/`TupleValue`,
`EnumType`/`EnumValue`, `EnumVariantDefinition`,
`ExplicitEnumType`/`ExplicitEnumValue`, `ExplicitEnumVariantDefinition`,
`ExplicitEnumTypeRegistry`, `FieldDefinition`, `Field`, `Fields`.

**Special / multi-value**: `OptionalType`/`OptionalValue`,
`VariadicType`/`VariadicValue`, `MultiValueType`/`MultiValueValue`,
`CompositeType`/`CompositeValue`.

**Builders**: `StructBuilder`, `EnumBuilder`, `VariadicBuilder` (plus the
`*BuilderExtensions` extensions).

### BigFloat has no wire codec

`BigFloatValue.toBytes()` **always throws `UnimplementedError`**
(`lib/src/abi/types/primitives/big_float.dart:85-90`). The chain encodes
`BigFloat` as an opaque arbitrary-precision-float blob, not a decimal string.
The type exists only so that ABIs mentioning it still load; code generation maps
it to Dart `double`. Do not attempt to encode or decode one.

## Codecs

`BinaryCodec` (orchestrator), `ICodec`, `IBinaryCodec`, `TypeBinaryCodec`,
`BinaryCodecUtils`, `BinaryCodecConstraints`, `PrimitiveBinaryCodec`,
`NumericalBinaryCodec`, `BooleanBinaryCodec`, `AddressBinaryCodec`,
`StringBinaryCodec`, `BytesBinaryCodec`, `NothingBinaryCodec`,
`TokenIdentifierBinaryCodec`, `H256BinaryCodec`, `CodeMetadataBinaryCodec`,
`OptionBinaryCodec`, `ListBinaryCodec`, `ArrayBinaryCodec`, `StructBinaryCodec`,
`TupleBinaryCodec`, `EnumBinaryCodec`, `ExplicitEnumBinaryCodec`,
`OptionalBinaryCodec`, `VariadicBinaryCodec`, `MultiValueBinaryCodec`,
`ManagedDecimalBinaryCodec`, `ManagedByteArrayBinaryCodec`. Plus `BinaryBuilder`
for growable byte buffers.

## Serializers

`ArgSerializer`, `ArgSerializerOptions`, `ValuesToStringResult`,
`ParameterDefinition`, `ArgumentEncoder`, `AbiDeserializer`, `NativeSerializer`,
`EndpointDefinition`, `EndpointParameterDefinition`, `ArgumentsCardinality`.

## Smart-contract runtime

| Symbol | Purpose |
|---|---|
| `SmartContractController` | One contract: `query`, `call`, deploy/upgrade, outcome parsing, event streams |
| `SmartContractCallFactory` | Unsigned contract-call drafts |
| `SmartContractQuery` | Executable read-only query |
| `SmartContractQueryInput` | Query address, function and arguments |
| `SmartContractQueryResponse` | Raw query return data and code |
| `SmartContractQueryRunner` | Runs queries with one unified API |
| `QueryResult` / `RawQueryResult` | Typed / untyped query output |
| `SmartContractQueryException` | Query failure |
| `ResponseParser` | ABI-typed decoding of return data |
| `ReturnCode` | Categorised VM return code |
| `TokenTransfersDataBuilder` | Builds the ESDT transfer data field |
| `EventConverter` / `EventConversionResult` | Typed event model conversion |
| `SmartContractEventRunner` | Drives contract event retrieval |
| `WebSocketEventStream` | Streaming event client with reconnection |
| `WebSocketEventStreamConfig` | Stream connection options |
| `WebSocketStatus` / `WebSocketEventType` | Connection state / event kind enums |
| `WebSocketEventResult` / `WebSocketEventError` / `WebSocketStatusChange` | Stream payloads |

## ABI extensions

`AddressAbiExtensions`, `AddressValueExtensions`, `BalanceAbiExtensions`,
`BalanceFromAbiExtensions`, `BalanceAbiUtilityExtensions`,
`GasLimitAbiExtensions`, `GasLimitFromAbiExtensions`, `GasPriceAbiExtensions`,
`GasPriceFromAbiExtensions`, `NonceAbiExtensions`, `NonceFromAbiExtensions`,
`NumericalConversions`, `TransactionSigningExtensions`,
`AbiTypeFactoryExtensions`, `AbiTypeOrThrowExtensions`, `TypedValueExtensions`,
`AbiTypeValidationExtensions`, `TypedValueValidationExtensions`,
`AbiTypeExtensions`, `AbiDeserializerExtensions`, `TypeCardinalityExtension`,
`ReturnCodeStringExtension`, `ReturnCodeNullableStringExtension`,
`EnumBuilderExtensions`, `StructBuilderExtensions`, `VariadicBuilderExtensions`.

`TransactionSigningExtensions on Transaction` supplies
`Future<Transaction> signWith(UserSigner)`, `signAsRelayer(...)` and
`Future<Transaction> signAsGuardian(UserSigner)`
(`lib/src/abi/extensions/transaction_signing_extensions.dart:11,19,37,82`).

**Numeric bounds constants**: `u8Max`, `u16Max`, `u32Max`, `u64Max`, `i8Min`,
`i8Max`, `i16Min`, `i16Max`, `i32Min`, `i32Max`, `i64Min`, `i64Max`
(`lib/src/abi/types/primitives/numerical.dart:22-55`). `u64Max`, `i64Min` and
`i64Max` are `BigInt`; the rest are `int`.

---

# 8. Network providers

| Symbol | Purpose |
|---|---|
| `NetworkProvider` | Abstract read/broadcast interface |
| `BaseNetworkProvider` | Shared HTTP plumbing for providers |
| `ApiNetworkProvider` | Talks to the public REST API (indexer) |
| `GatewayNetworkProvider` | Talks to a Gateway / Proxy node |
| `NetworkProviderConfig` | User agent, timeout, retry, throttle, cache |
| `RetryPolicy` / `ThrottlePolicy` / `ResponseCachePolicy` | The three sub-policies |
| `UserAgent` | Builds the `User-Agent` header |
| `NetworkConfig` | Chain configuration served by the node |
| `NetworkStatus` | Current round, epoch, nonce, timestamps |
| `NetworkEconomics` | Supply and staking economics |
| `GatewayEconomics` | Gateway-specific economics payload |
| `ChainTimestamp` | Unit-agnostic chain timestamp reader |
| `AccountStorage` / `AccountStorageEntry` | Contract key-value storage |
| `AccountAwaiter` / `AccountAwaitingOptions` | Waits for account state changes |
| `BlockOnNetwork` / `HyperblockOnNetwork` | Block and cross-shard hyperblock |
| `Guardian` / `GuardianData` | `getGuardianData` payloads |
| `SendTransactionsResult` | Bulk-broadcast result set |
| `SendTxOutcome` / `SendTxSuccess` / `SendTxFailure` | Per-transaction bulk outcome |

Core read/write methods on `NetworkProvider`
(`lib/src/infrastructure/network/network_provider.dart`): `getNetworkConfig`,
`getNetworkStatus`, `getNetworkEconomics`, `getAccount`, `getAccountStorage`,
`getAccountStorageEntry`, `sendTransaction`, `sendTransactions`,
`getTransaction`, `getTransactionStatus`, `simulateTransaction`,
`estimateTransactionCost`, `queryContract`, `getTokenOfAccount`,
`getFungibleTokensOfAccount`, `getNonFungibleTokensOfAccount`,
`getGuardianData`, `getDefinitionOfFungibleToken`,
`getDefinitionOfTokenCollection`, `getNonFungibleToken`, `getBlock`,
`getLatestBlock`, `getHyperblock`, `doGetGeneric`, `doPostGeneric`.

`sendTransaction` returns `Future<String>` (the hash), not a receipt
(`network_provider.dart:170`).

---

# 9. Entrypoints

| Symbol | Provider it builds |
|---|---|
| `NetworkEntrypoint` | `ApiNetworkProvider` (custom URL) |
| `DevnetEntrypoint` / `TestnetEntrypoint` / `MainnetEntrypoint` | `ApiNetworkProvider` (public API hosts) |
| `ProxyNetworkEntrypoint` | `GatewayNetworkProvider` (custom URL) |
| `DevnetProxyEntrypoint` / `TestnetProxyEntrypoint` / `MainnetProxyEntrypoint` | `GatewayNetworkProvider` (public Gateway hosts) |
| `EntrypointUrls` | The six public host constants |

Both entrypoint families expose exactly these factory methods
(`lib/src/entrypoints/network_entrypoint.dart:110-182` for the API family and
`:318-390` for the Proxy family):

`createNetworkProvider`, `createSmartContractController({required SmartContractAbi abi, required Address address})`,
`createTransfersFactory`, `createTokenManagementFactory`,
`createDelegationFactory`, `createMultisigFactory`, `createValidatorsFactory`,
`createGovernanceFactory`, `createMultisigController`,
`createValidatorsController`, `createGovernanceController`,
`createTransactionWatcher`.

There is **no** `createTransfersController`, `createAccountController`,
`createTokenManagementController` or `createDelegationController` — construct
those controllers directly with a `chainId:`.

### Configuring an entrypoint

Every entrypoint in both families takes the same three optional arguments:

```
({NetworkProviderConfig? networkProviderConfig,
  String? clientName,
  IGasLimitEstimator? gasLimitEstimator})
```

- **`networkProviderConfig` reaches the provider on both families.** The API
  family builds
  `ApiNetworkProvider(baseUrl: url, chainId: chainId, config: networkProviderConfig)`
  (`lib/src/entrypoints/network_entrypoint.dart:102-106`) and the Proxy family
  builds `GatewayNetworkProvider(baseUrl: url, chainId: chainId, config: networkProviderConfig)`
  (`:310-314`). `clientName`, `headers`, `requestTimeout`, `baseUrl`,
  `retryPolicy`, `throttlePolicy` and `cachePolicy` therefore all take effect on
  a `DevnetProxyEntrypoint` exactly as they do on a `DevnetEntrypoint`.
- **`clientName` is a shortcut, not a replacement.** Passing it alone builds a
  minimal config carrying just that name; passing it alongside a
  `networkProviderConfig` overrides that config's `clientName` and carries every
  other field — headers, timeout, base URL, retry, throttle and cache — through
  unchanged (`_mergeClientName`, `network_entrypoint.dart:199-218`). Setting
  `clientName` inside the config works too; the two spellings agree.
- **`gasLimitEstimator` is handed to every controller the entrypoint creates**,
  including the `SmartContractController` from `createSmartContractController`
  (`:113-121`, `:321-329`).

The provider is built once and cached: `createNetworkProvider()` returns the
same instance for the lifetime of the entrypoint (`:102`, `:310`), and the
controllers and watcher it creates share it.

---

# 10. Infrastructure

**Logging**: `Logger` (abstract), `ConsoleLogger`, `NullLogger`, `LogLevel`.

**Caching**: `CacheManager`, `CacheConfig`, `LRUCache`, `CacheEntry`.

**Batching**: `BatchHelper`, `BatchConfig`, `BatchResult`, `BatchItemResult`.

**Pagination**: `Paginator`, `PaginatorConfig`, `PagedResult`,
`PaginationParams`, `SortOrder`.

**Resilience**: `CircuitBreaker`, `CircuitState`, `CircuitBreakerOpenException`,
`RequestThrottle`, `RetryHelper`, `RetryConfig`.

---

# 11. Errors

`abstract class AbidockException implements Exception`
(`lib/src/utils/sdk_exceptions.dart:47`) is the root of the hierarchy, and every
exception type this package exports descends from it. One
`on AbidockException catch (e)` is a complete net for SDK-raised failures.

Six branches sit directly under it (line numbers in
`lib/src/utils/sdk_exceptions.dart` unless another file is named):

| Branch | Members |
|---|---|
| `WalletException` (87) | `PemException`, `MnemonicException`, `SignerException`, `DecryptorException`, `WalletLengthException` |
| `NetworkException` (186) | `AccountAwaiterTimeoutException`, `AccountAwaiterException` |
| `TransactionException` (291) | `TransactionCreationException`, `TransactionWatcherTimeoutException`, `TransactionWatcherException`, `EventParsingException`, `UnexpectedEventCountException` (`core/transaction/transaction_logs.dart:13`), and the four outcome-parser failures `SmartContractParseException`, `DelegationParseException`, `GovernanceParseException`, `TokenManagementParseException` (`core/transaction/outcome_parsers/`) |
| `SmartContractException` (472) | the `core_types.dart` failures below, plus `SmartContractQueryException` (`abi/smart_contract/query/query.dart:23`), `MultisigParseException` (`abi/smart_contract/controller/multisig_controller.dart:694`) and `ValidatorsParseException` (`…/validators_controller.dart:551`) |
| `SerializationException` (492) | `AbiBinaryCodecException`, `AbiNativeSerializationException`, `AbiArgumentSerializationException`, `DeserializationException`, `AbiTypeFormulaParseException` |
| `ValidationException` (714) | — |

Two leaves attach straight to the root rather than to a branch:
`AddressException` (`lib/src/core/address.dart:24`) and
`CircuitBreakerOpenException`
(`lib/src/infrastructure/resilience/circuit_breaker_exception.dart:7`).

Under `SmartContractException` in `lib/src/abi/core/core_types.dart`:
`ArgumentEncodingException` (123), `ResponseParsingException` (183),
`EndpointNotFoundException` (243), `ArgumentValidationException` (354),
`ResponseValidationException` (460), `GasEstimationException` (521).

Catching a branch catches its whole subtree, so `on TransactionException` covers
the watcher timeouts and the outcome parsers alike, and `on SmartContractException`
covers query, ABI-argument and endpoint-resolution failures alike. Dart's own
`ArgumentError`, `StateError`, `FormatException` and `AssertionError` are outside
this hierarchy — the factories and value types raise those directly for
programming errors, e.g. `RelayedTransactionsFactory.applyRelayer`
(`relayed_transactions_factory.dart:95,102,112,120,136`) and
`createTransactionForEsdtTransfer` on an empty transfer list
(`transfer_transactions_factory.dart:201`).

---

# 12. Utilities

`CollectionUtils`, `StringUtils`, `HexUtils`, `JsonUtils`, `EventDeduplicator`.

---

# 13. Top-level functions

The barrel exports 21 public top-level functions in addition to the types and
constants above. All 21 resolve from `package:abidock_mvx/abidock_mvx.dart`
(compile probe). They are not wrapped in a class — call them directly.

| Function | Declared at |
|---|---|
| `UserSecretKey parseUserKey(String text, {int index = 0})` | `lib/src/wallet/pem.dart:30` |
| `List<UserSecretKey> parseUserKeys(String text)` | `lib/src/wallet/pem.dart:54` |
| `List<ValidatorSecretKey> parseValidatorPem(String text)` | `lib/src/wallet/validator_pem.dart:24` |
| `ValidatorSecretKey parseValidatorKey(String text, {int index = 0})` | `lib/src/wallet/validator_pem.dart:37` |
| `List<ValidatorSecretKey> parseValidatorKeys(String pemText)` | `lib/src/wallet/validator_keys.dart:273` |
| `void guardLength(dynamic withLength, int expectedLength)` | `lib/src/wallet/assertions.dart:15` |
| `T requireAs<T>(dynamic value, String field)` | `lib/src/utils/helpers.dart:29` |
| `T? optionalAs<T>(dynamic value, String field)` | `lib/src/utils/helpers.dart:52` |
| `T infer<T>(T value)` | `lib/src/utils/helpers.dart:72` |
| `Future<T> executeTransaction<T>({...})` | `lib/src/utils/helpers.dart:94` |
| `Future<T> executeQuery<T>({...})` | `lib/src/utils/helpers.dart:130` |
| `int requireInt(dynamic value, String field)` | `lib/src/utils/helpers.dart:165` |
| `int? optionalInt(dynamic value, String field)` | `lib/src/utils/helpers.dart:197` |
| `Future<GasLimit> simulateGas(...)` | `lib/src/utils/helpers.dart:241` |
| `TransferType determineTransferType(List<TokenTransferValue>? transfers)` | `lib/src/abi/types/special/token_transfer_value.dart:360` |
| `T onTypeSelect<T>(AbiType type, TypeMatchCallbacks<T> callbacks)` | `lib/src/abi/core/type_matchers.dart:41` |
| `T onTypedValueSelect<T>(TypedValue value, ValueMatchCallbacks<T> callbacks)` | `lib/src/abi/core/type_matchers.dart:145` |
| `AbiTypeFormulaParseException unexpectedCharacterException(...)` | `lib/src/abi/core/type_formula_parser.dart:12` |
| `AbiTypeFormulaParseException unexpectedEndException()` | `lib/src/abi/core/type_formula_parser.dart:23` |
| `AbiTypeFormulaParseException mismatchedBracketsException()` | `lib/src/abi/core/type_formula_parser.dart:28` |
| `AbiTypeFormulaParseException emptyTypeNameException()` | `lib/src/abi/core/type_formula_parser.dart:33` |

The last four are exception *constructors* — they build an
`AbiTypeFormulaParseException`, they do not throw it.

---

# 14. Removed in 3.0.0 — never emit these

Verified absent by compile probe against the 3.1.0 barrel:

| Removed symbol | Replacement |
|---|---|
| `SignableMessage` | `Message` + `MessageComputer.computeBytesForSigning` |
| `ValidatorSigner(secretKey)`, `ValidatorSigner.fromPem` | `ValidatorSigner.custom(signFn)` |
| `TransactionStatus.recalled`, `TransactionStatus.isRecalled` | no such chain status |
| `NetworkConfig.gasPriceModifierString` | `gasPriceModifier` |
| `functionCallHexParts` (multisig builders) | `functionCall: <TypedValue>[...]` |
| `RelayedTransactionsFactory.createRelayedTransaction` | `applyRelayer`, then sign |
| `createTransactionForDelegatingVote` | callable only by a contract |
| `createTransactionForUnsettingBurnRoleForAll` | `createTransactionForUnsettingBurnRoleGlobally` |
| `Transaction.innerTransactions` | not part of the transaction format |

`relayedVersion` survives only as `String?` on `TransactionOnNetwork`.

## Not verified

- **Member-level surface.** This file enumerates top-level declarations. Method
  and field lists are given only where cited with a line number; for anything
  else, open the declaration.
- **Extension member names.** The 27 extension *names* come from their
  declarations, but the members they add were not exhaustively compiled — only
  `TransactionSigningExtensions.signWith` / `signAsRelayer` / `signAsGuardian`
  were checked.
- **Deprecations.** `grep -rn "@Deprecated" lib/` returns nothing, so nothing
  exported is formally marked deprecated. Whether any symbol is *informally*
  discouraged was not determined.
- **Subsystem grouping** is functional, not directory-based. `MultisigController`,
  `GovernanceController`, `ValidatorsController` and `SmartContractController`
  and their input/outcome DTOs are grouped under §5 Controllers but declared in
  `lib/src/abi/smart_contract/controller/`; `ChainTimestamp` appears in both §3
  and §8 and is declared in `lib/src/infrastructure/network/network_status.dart`.
  Do not infer a file path from a section heading.
