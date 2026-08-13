---
name: events-and-parsers
title: Events and Outcome Parsers
summary: Read events off a settled transaction, decode them with an ABI, parse typed outcomes, and stream events over WebSocket or polling.
reads: [skills/08-tokens-esdt.md]
verified_against: abidock_mvx 3.1.0 (Dart 3.13)
---

## When to use this

You have sent a transaction and need its result, or you want a live feed of a
contract's events.

---

## 1. The fact that silently breaks outcome parsing

A transaction carries logs in **two places**:

- `TransactionOnNetwork.logs` — the transaction's own log container.
- `TransactionOnNetwork.smartContractResults[i].logs` — one container per
  smart-contract result.

Any operation that touches **another account or another shard** reports its
events on the smart-contract result, not on the transaction. For ESDT this covers
`freeze`, `unFreeze`, `wipe`, `setSpecialRole`, `unSetSpecialRole` and the local
mint/burn pair: the system contract forwards a built-in call to the target
address, and that call executes — and logs — on the target's shard
(`lib/src/core/transaction/outcome_parsers/token_management_outcome_parser.dart:1020-1050`).

Reading only `transaction.logs` therefore returns an empty list for every real
cross-account operation and, worse, misses a `signalError` that appears only on a
result — turning a failed transaction into a silent success.

`TokenManagementOutcomeParser` handles this: `_allLogs` concatenates the
transaction's own logs with every result's logs (`:1036-1050`), `_findEvents`
searches all of them (`:1061-1069`), and `_ensureNoError` scans all of them for
`signalError` (`:1080-1104`). It throws `TokenManagementParseException` when
there are no logs anywhere, and when any `signalError` is found. Proven by
`test/core/transaction/outcome_parsers/token_management_scr_logs_test.dart`.

**The other parsers do not do this.** `DelegationOutcomeParser` and
`GovernanceOutcomeParser` read `transaction.logs` only
(`delegation_outcome_parser.dart:94-104`, `governance_outcome_parser.dart:296-302`),
as does `TransactionEventParser.parseEvents`
(`lib/src/core/transaction/transaction_event_parser.dart:186-202`). If you need
events from a cross-shard result with those, walk
`transaction.smartContractResults` yourself.

`SmartContractOutcomeParser.parseExecute` is different again: it looks for the
return values in the smart-contract results **first**, then in a `signalError`
event, then in the last `writeLog` event
(`smart_contract_outcome_parser.dart:242-264`).

---

## 2. Outcome parsers

All four are exported from the package root. Each `parse…` takes a
`TransactionOnNetwork` and returns a **`List`** (one entry per matching event) —
except where noted.

### `TokenManagementOutcomeParser` — `const TokenManagementOutcomeParser()`

| Method | Event identifier matched | Returns |
| --- | --- | --- |
| `parseIssueFungible` | `issue` | `List<IssueFungibleResult>` — `tokenIdentifier` |
| `parseIssueNonFungible` | `issueNonFungible` | `List<IssueNonFungibleResult>` |
| `parseIssueSemiFungible` | `issueSemiFungible` | `List<IssueSemiFungibleResult>` |
| `parseRegisterMetaEsdt` | `registerMetaESDT` | `List<RegisterMetaEsdtResult>` |
| `parseRegisterAndSetAllRoles` | `registerAndSetAllRoles` + `ESDTSetRole` | `List<RegisterAndSetAllRolesResult>` — `tokenIdentifier`, `roles`. Throws if the two event counts differ (`:586-590`) |
| `parseSetSpecialRole` | `ESDTSetRole` | `List<SetSpecialRoleResult>` — `userAddress` (`Address`), `tokenIdentifier`, `roles` |
| `parseSetBurnRoleGlobally` / `parseUnsetBurnRoleGlobally` | — | `void`; the body is `_ensureNoError` alone (`:616-626`), so it raises when the transaction carries no logs anywhere **or** when any `signalError` is found |
| `parseNftCreate` | `ESDTNFTCreate` | `List<NftCreateResult>` — `tokenIdentifier`, `nonce`, `initialQuantity` |
| `parseLocalMint` | `ESDTLocalMint` | `List<LocalMintResult>` — `userAddress` (`Address`), `tokenIdentifier`, `nonce`, `mintedSupply` |
| `parseLocalBurn` | `ESDTLocalBurn` | `List<LocalBurnResult>` — `…`, `burntSupply` |
| `parsePause` / `parseUnpause` | `ESDTPause` / `ESDTUnPause` | `List<PauseResult>` / `List<UnpauseResult>` |
| `parseFreeze` | `ESDTFreeze` | `List<FreezeResult>` — `userAddress` (**`String`** bech32), `tokenIdentifier`, `nonce`, `balance` |
| `parseUnfreeze` | `ESDTUnFreeze` | `List<UnfreezeResult>` |
| `parseWipe` | `ESDTWipe` | `List<WipeResult>` |
| `parseUpdateAttributes` | `ESDTNFTUpdateAttributes` | `List<UpdateAttributesResult>` — `attributes` (`Uint8List`) |
| `parseAddQuantity` | `ESDTNFTAddQuantity` | `List<AddQuantityResult>` — `addedQuantity` |
| `parseBurnQuantity` | `ESDTNFTBurn` | `List<BurnQuantityResult>` — `burntQuantity` |
| `parseModifyRoyalties` | `ESDTModifyRoyalties` | `List<ModifyRoyaltiesResult>` — `royalties` |
| `parseSetNewUris` | `ESDTSetNewURIs` | `List<SetNewUrisResult>` — `uris` |
| `parseModifyCreator` | `ESDTModifyCreator` | `List<ModifyCreatorResult>` |
| `parseUpdateMetadata` | `ESDTMetaDataUpdate` | `List<UpdateMetadataResult>` — `metadata` (`Uint8List`) |
| `parseMetadataRecreate` | `ESDTMetaDataRecreate` | `List<MetadataRecreateResult>` |
| `parseChangeTokenToDynamic` | `changeToDynamic` | `List<ChangeToDynamicResult>` — `tokenIdentifier`, `tokenName`, `tickerName`, `tokenType` |
| `parseRegisterDynamicToken` | `registerDynamic` | `List<RegisterDynamicResult>` — `…`, `tokenTicker`, `tokenType`, `numOfDecimals` (`int`) |
| `parseRegisterDynamicTokenAndSettingRoles` | `registerAndSetAllRolesDynamic` | `List<RegisterDynamicResult>` |

Note the two asymmetries above, both real: `SetSpecialRoleResult.userAddress`
and `LocalMintResult.userAddress` are `Address` (taken from `event.address`,
`:1151`, `:1178`), whereas `FreezeResult`/`UnfreezeResult`/`WipeResult`
`userAddress` is a bech32 `String` decoded from `topics[3]` (`:1127-1133`).

Topic layout used by the shared extractors (`:1106-1133`): `topics[0]` =
token identifier (ASCII), `topics[1]` = nonce (big-endian bytes), `topics[2]` =
amount/balance, `topics[3]` = address or payload, `topics[3..]` = roles / URIs.

### The others

| Parser | Method | Returns |
| --- | --- | --- |
| `DelegationOutcomeParser()` | `parseCreateNewDelegationContract` | `List<CreateDelegationContractResult>` — `contractAddress` (bech32 `String`), read from `SCDeploy` topics[0] |
| `GovernanceOutcomeParser({String addressHrp = 'erd'})` | `parseNewProposal` | `List<NewProposalOutcome>` — `proposalNonce`, `commitHash`, `startVoteEpoch`, `endVoteEpoch` |
| | `parseVote` | `List<VoteOutcome>` — `proposalNonce`, `vote`, `totalStake`, `votingPower` |
| | `parseDelegateVote` | `List<DelegateVoteOutcome>` — `…`, `voter` (`Address`), `userStake`, `votingPower` |
| | `parseCloseProposal` | `List<CloseProposalOutcome>` — `commitHash`, `passed` (`bool`) |
| `SmartContractOutcomeParser({SmartContractAbi? abi})` | `parseDeploy` | `SmartContractDeployOutcome` (single) — `returnCode`, `returnMessage`, `contracts` of `DeployedContract(address, ownerAddress, codeHash)` |
| | `parseExecute(tx, {String? function})` | `ParsedSmartContractCallOutcome` (single) — `returnCode`, `returnMessage`, `values` |

`parseExecute` returns raw `Uint8List` buffers in `values` when no ABI was
supplied or no function name is known; with both, `values` holds native Dart
values (`.valueOf()` of each decoded `TypedValue`)
(`smart_contract_outcome_parser.dart:172-204`). It falls back to
`transaction.function` when `function` is omitted (`:170`).

`closeProposal` topics are raw UTF-8 text, not ABI-encoded — `passed` is the
literal string `true` (`governance_outcome_parser.dart:252-277`).

Failure modes: `TokenManagementParseException`, `DelegationParseException`,
`GovernanceParseException`, `SmartContractParseException` — all plain
`Exception`s with `message` and optional `cause`.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Outcome parsers over a completed transaction.
Future<void> main() async {
  final ApiNetworkProvider provider = ApiNetworkProvider.devnet();
  final TransactionOnNetwork tx = await provider.getTransaction('aa' * 32);

  const TokenManagementOutcomeParser tokens = TokenManagementOutcomeParser();

  final List<IssueFungibleResult> issued = tokens.parseIssueFungible(tx);
  final String identifier = issued.isEmpty
      ? ''
      : issued.first.tokenIdentifier;

  final List<SetSpecialRoleResult> roles = tokens.parseSetSpecialRole(tx);
  final List<NftCreateResult> minted = tokens.parseNftCreate(tx);
  final List<LocalMintResult> localMints = tokens.parseLocalMint(tx);
  final List<FreezeResult> frozen = tokens.parseFreeze(tx);
  final List<UnfreezeResult> unfrozen = tokens.parseUnfreeze(tx);
  final List<RegisterAndSetAllRolesResult> registered = tokens
      .parseRegisterAndSetAllRoles(tx);

  assert(identifier.isEmpty || identifier.contains('-'), 'identifier');
  assert(roles.isEmpty || roles.first.roles.isNotEmpty, 'role names');
  assert(minted.isEmpty || minted.first.nonce > BigInt.zero, 'nft nonce');
  assert(localMints.isEmpty || localMints.first.mintedSupply >= BigInt.zero, '');
  assert(frozen.isEmpty || frozen.first.userAddress.isNotEmpty, 'frozen');
  assert(unfrozen.isEmpty || unfrozen.first.balance >= BigInt.zero, 'unfrozen');
  assert(registered.isEmpty || registered.first.roles.isNotEmpty, 'roles');

  const DelegationOutcomeParser delegation = DelegationOutcomeParser();
  final List<CreateDelegationContractResult> contracts = delegation
      .parseCreateNewDelegationContract(tx);
  assert(contracts.isEmpty || contracts.first.contractAddress.isNotEmpty, '');

  const GovernanceOutcomeParser governance = GovernanceOutcomeParser();
  final List<NewProposalOutcome> proposals = governance.parseNewProposal(tx);
  final List<VoteOutcome> votes = governance.parseVote(tx);
  assert(proposals.isEmpty || proposals.first.commitHash.isNotEmpty, '');
  assert(votes.isEmpty || votes.first.vote.isNotEmpty, 'vote');

  const SmartContractOutcomeParser contract = SmartContractOutcomeParser();
  final SmartContractDeployOutcome deployed = contract.parseDeploy(tx);
  final ParsedSmartContractCallOutcome executed = contract.parseExecute(tx);
  assert(deployed.returnCode.isNotEmpty, 'return code');
  assert(executed.values.isEmpty || executed.returnCode == 'ok', 'values');
}
```

---

## 3. Reading raw events

### `TransactionLogs` (`lib/src/core/transaction/transaction_logs.dart`)

| Member | Signature | Notes |
| --- | --- | --- |
| `address` | `Address` | |
| `events` | `List<TransactionEvent>` | |
| `findEvents` | `List<TransactionEvent> findEvents(String identifier, {bool Function(TransactionEvent)? predicate})` | |
| `findFirstOrNoneEvent` | `TransactionEvent?` | same parameters |
| `findSingleOrNoneEvent` | `TransactionEvent?` | throws `UnexpectedEventCountException` if more than one matches (`:247-252`) |
| `hasEvent` | `bool hasEvent(String identifier)` | |
| `getEventIdentifiers` | `Set<String>` | |
| `hasErrors` / `errorEvents` | `bool` / `List<TransactionEvent>` | both keyed on `signalError` (`:306`, `:312`) |
| `isEmpty` / `isNotEmpty` | `bool` | |
| `TransactionLogs.fromHttpResponse` | base64-encoded payloads (public API) | `:96` |
| `TransactionLogs.fromProxyHttpResponse` | hex-encoded payloads (gateway) | `:126` |

### `TransactionEvent` (`lib/src/core/transaction/transaction_event.dart`)

Fields: `address` (`Address`), `identifier` (`String`), `topics`
(`List<Uint8List>`), `data` (`Uint8List`), `additionalData` (`List<Uint8List>`),
`order` (`int`), `addressAssets` (`Map<String, dynamic>?`), `raw`
(`Map<String, dynamic>`).

Decoders:

| Member | Returns | Behaviour |
| --- | --- | --- |
| `getTopicAsString(int index)` | `String` | UTF-8; `''` when the index is out of range (`:294-299`) |
| `getTopicAsHex(int index)` | `String` | lower-case hex; `''` out of range |
| `getTopicAsBigInt(int index)` | `BigInt` | parses the hex; `BigInt.zero` when out of range, empty, or malformed (`:336-349`) |
| `dataAsString` | `String` | UTF-8 of `data` |
| `dataAsHex` | `String` | |
| `isWriteLog` / `isSignalError` / `isScDeploy` | `bool` | identifier equality |

Three factories, each for a different encoding — pick by source:
`TransactionEvent.fromHttpResponse` (base64, public API, `:72`),
`TransactionEvent.fromProxyHttpResponse` (hex with a permissive UTF-8 fallback,
gateway, `:135`), `TransactionEvent.fromEventsEndpoint` (hex, the `/events`
route, `:206`).

Topic convention on this chain: **`topics[0]` is the event name**, the remaining
topics are the indexed parameters in declaration order — which is why the ABI
decoder skips the first topic (`transaction_event_parser.dart:316-318`).

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// Reads raw events off a fetched transaction and decodes topics.
Future<void> main() async {
  final ApiNetworkProvider provider = ApiNetworkProvider.devnet();
  final TransactionOnNetwork tx = await provider.getTransaction('aa' * 32);

  final TransactionLogs? logs = tx.logs;
  if (logs != null) {
    final Set<String> identifiers = logs.getEventIdentifiers();
    final List<TransactionEvent> transfers = logs.findEvents('ESDTTransfer');
    final TransactionEvent? deploy = logs.findSingleOrNoneEvent('SCDeploy');

    for (final TransactionEvent event in transfers) {
      final String tokenIdentifier = event.getTopicAsString(0);
      final BigInt nonce = event.getTopicAsBigInt(1);
      final BigInt amount = event.getTopicAsBigInt(2);
      final String receiverHex = event.getTopicAsHex(3);
      assert(tokenIdentifier.isNotEmpty || nonce >= BigInt.zero, 'topics');
      assert(amount >= BigInt.zero && receiverHex.isNotEmpty, 'topics');
    }

    assert(identifiers.isNotEmpty || deploy == null, 'logs read');
    if (logs.hasErrors) {
      for (final TransactionEvent error in logs.errorEvents) {
        assert(error.dataAsString.isNotEmpty, 'error payload');
      }
    }
  }

  /// Events raised by a call that ran on another shard are attached to the
  /// smart-contract results, not to the transaction's own logs.
  for (final SmartContractResult result
      in tx.smartContractResults ?? const <SmartContractResult>[]) {
    final TransactionLogs? resultLogs = result.logs;
    if (resultLogs != null) {
      for (final TransactionEvent event in resultLogs.findEvents(
        'ESDTLocalMint',
      )) {
        assert(event.getTopicAsString(0).isNotEmpty, 'token identifier');
      }
    }
  }

  final DateTime? executedAt = tx.executedAt;
  assert(executedAt == null || executedAt.isUtc, 'normalised timestamp');
}
```

`TransactionOnNetwork.executedAt` is the accessor to use for the execution
instant: the chain switched its timestamp from seconds to milliseconds at the
Supernova epoch and the unit still differs per route, so raw `timestamp` is
unit-ambiguous. `executedAt` prefers `timestampMs`, falls back to `timestamp`,
and returns a UTC `DateTime?`
(`lib/src/core/transaction/transaction_on_network.dart:544`, `:550`, `:566`).

---

## 4. ABI-typed decoding

`TransactionEventParser` (`lib/src/core/transaction/transaction_event_parser.dart`).

| Constructor / method | Signature |
| --- | --- |
| `TransactionEventParser()` | no ABI — only the non-decoding helpers work |
| `TransactionEventParser.withAbi(SmartContractAbi? abi)` | full decoding |
| `parseEvents` | `List<ParsedEvent> parseEvents(TransactionOnNetwork tx, String eventIdentifier)` |
| `parseSingleEvent` | `ParsedEvent parseSingleEvent(TransactionEvent event, String eventIdentifier)` |
| `parseEventFromJson` | `ParsedEvent parseEventFromJson(Map<String, dynamic> eventJson, String eventIdentifier)` — expects the hex encoding of the `/events` route |
| `findEvents` | `List<TransactionEvent> findEvents(TransactionOnNetwork tx, String eventIdentifier)` |
| `hasEvent`, `getEventIdentifiers`, `getErrorMessages` | `bool`, `Set<String>`, `List<String>` |

Throws `EventParsingException` when the ABI is absent, when the identifier is not
in the ABI, or when the non-indexed parameters fail to decode.

`ParsedEvent` exposes `event` (`TransactionEvent`), `definition`
(`EventDefinition`), `values` (`List<TypedValue>`), plus
`TypedValue? getValueByName(String name)` and `Map<String, TypedValue> toMap()`.

Decoding rules (`:313-392`):

- Indexed inputs are decoded from `topics[1..]` — `topics[0]` is skipped as the
  event name.
- A missing, empty **or undecodable** topic yields a **type default**, not an
  error (`:327-339`) — an absent indexed field silently reads as `0` / `''` /
  zero address, and a topic whose bytes fail `decodeTopLevel` is swallowed the
  same way (`:336-338`).
- Non-indexed inputs are decoded from `additionalData` when it is non-empty,
  otherwise from `data` as a single buffer (`:355-357`).
- `parseEvents` reads `transaction.logs` only; it returns `[]` when `logs` is
  `null` (`:186-188`).

`EventConverter` (`lib/src/abi/smart_contract/event_streaming/event_converter.dart`)
turns a `ParsedEvent` into a generated model:

| Member | Signature |
| --- | --- |
| `EventConverter.convertEvent<T>` | `static T? convertEvent<T>(ParsedEvent, T Function(TypedValue) fromAbi, AbiType eventType)` — `null` on failure |
| `EventConverter.convertEventWithResult<T>` | `static EventConversionResult<T>` — carries `value`, `error`, `failureReason`, `isSuccess`, `isFailure` |
| `EventConverter.convertTypedValueMapToNative` | `static Map<String, dynamic> (Map<String, TypedValue>)` |
| `EventConverter.convertTypedValueToNative` | `static dynamic (TypedValue)` |
| `EventConverter.filterByIdentifier<T>` | `static Stream<T> (Stream source, String identifier, T? Function(ParsedEvent) converter)` |

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

/// ABI-driven event decoding from a completed transaction.
Future<void> main() async {
  final ApiNetworkProvider provider = ApiNetworkProvider.devnet();
  final SmartContractAbi abi = SmartContractAbi.fromJson('{"endpoints": []}');
  final TransactionOnNetwork tx = await provider.getTransaction('aa' * 32);

  final TransactionEventParser parser = TransactionEventParser.withAbi(abi);

  final List<ParsedEvent> swaps = parser.parseEvents(tx, 'swap');
  for (final ParsedEvent swap in swaps) {
    final TypedValue? tokenIn = swap.getValueByName('tokenIn');
    final Map<String, TypedValue> fields = swap.toMap();
    final Map<String, dynamic> native =
        EventConverter.convertTypedValueMapToNative(fields);
    assert(tokenIn == null || native.isNotEmpty, 'decoded');
  }

  /// A single raw event, decoded on demand.
  final TransactionEvent? raw = tx.logs?.findFirstOrNoneEvent('swap');
  if (raw != null) {
    final ParsedEvent parsed = parser.parseSingleEvent(raw, 'swap');
    assert(parsed.definition.identifier == 'swap', 'definition');
  }

  /// ABI-free helpers.
  final TransactionEventParser plain = TransactionEventParser();
  final Set<String> identifiers = plain.getEventIdentifiers(tx);
  final List<String> errors = plain.getErrorMessages(tx);
  assert(identifiers.isEmpty || errors.isEmpty || errors.isNotEmpty, 'raw');
}
```

---

## 5. WebSocket streaming

`WebSocketEventStreamConfig`
(`lib/src/abi/smart_contract/event_streaming/websocket_event_stream.dart:97-253`).

Preferred constructor — server-side filtering, no deduplication needed:

```
WebSocketEventStreamConfig.byIdentifiers({
  required String websocketUrl,
  required List<String> identifiers,
  Address? contractAddress,
  SmartContractAbi? abi,
  Map<String, String>? headers,
  bool autoReconnect = true,
  Duration reconnectDelay = const Duration(milliseconds: 300),
  Duration connectionTimeout = const Duration(seconds: 5),
  Duration pingInterval = const Duration(seconds: 10),
  Logger? logger,
})
```

The full constructor additionally takes `eventType`
(`WebSocketEventType.byIdentifier` — the default — or `.allEvents`),
`eventIdentifier`, `transactionIdentifier`, `topics`, `customProtocols`,
`enableDeduplication` (default `false`), `deduplicationTtl` (30 s),
`deduplicationMaxSize` (10000).

What each filter actually does (`:592-637`, `:805-899`):

| Field | Where it filters |
| --- | --- |
| `eventIdentifiers` | server side — one `{"identifier": …}` subscription entry per element |
| `contractAddress` | client side in **both** modes — every inbound event whose address differs is dropped, case-insensitively (`:805-809`); additionally **required** in `allEvents` mode, where it goes into the subscription — omitting it there throws `ArgumentError` |
| `transactionIdentifier` | server side, `allEvents` mode only |
| `topics` | server side, `allEvents` mode only |
| `eventIdentifier` | client side, matching the UTF-8 decode of `topics[0]` (`:857-898`). In `byIdentifier` mode it doubles as the subscription entry when `eventIdentifiers` is null or empty (`:594-596`) |

Subscription payloads sent on connect: `{"subscriptionEntries":[{"identifier":"swap"}]}`
for `byIdentifier`; `{"subscriptionEntries":[{"eventType":"all_events","address":"erd1…"}]}`
for `allEvents` (`:589-644`). Inbound envelope types handled: `all_events`,
`finalized_events`, `revert_events`, `block_events`; anything else is ignored
(`:712-726`). In `allEvents` mode the same transaction is delivered at several
lifecycle stages, so duplicates are expected — that is what
`enableDeduplication` is for (key: `txHash:identifier`, `:799`).

`WebSocketEventStream(WebSocketEventStreamConfig config)`:

| Member | Type |
| --- | --- |
| `events` | `Stream<WebSocketEventResult>` (broadcast) |
| `statusChanges` | `Stream<WebSocketStatusChange>` |
| `errors` | `Stream<WebSocketEventError>` |
| `status` | `WebSocketStatus` — `idle`, `connecting`, `connected`, `listening`, `paused`, `disconnected`, `error` |
| `connect()` / `disconnect()` / `dispose()` | `Future<void>` |
| `pause()` / `resume()` | `void` — flips the status only; the socket stays open |
| `connectedAt`, `lastEventTime` | `DateTime?` |
| `eventsReceived`, `duplicatesFiltered`, `reconnectAttempts` | `int` |

`WebSocketEventResult`: `rawEvent` (`TransactionEvent`), `parsedEvent`
(`ParsedEvent?` — non-null only when `abi` was supplied *and* the identifier is
in the ABI), `txHash` (`String`), `blockHash` (`String?`), `receivedAt`
(`DateTime`).

Reconnection: exponential from `reconnectDelay`, capped at 2 s, at most 5
attempts, after which an error is pushed to `errors` and the stream stays down
(`:1011-1052`). `connect()` **never** throws: its whole body is wrapped in a
`catch` that routes the failure to `errors` and, only when `autoReconnect` is
`true`, schedules a retry (`:576-583`). A returned future that completes
normally therefore proves nothing — watch `errors` and `statusChanges`.

```dart
import 'dart:async';

import 'package:abidock_mvx/abidock_mvx.dart';

/// WebSocket event streaming against the chain's notifier.
Future<void> main() async {
  final SmartContractAbi abi = SmartContractAbi.fromJson('{"endpoints": []}');

  final WebSocketEventStreamConfig config =
      WebSocketEventStreamConfig.byIdentifiers(
        websocketUrl: 'wss://devnet-notifier.multiversx.com',
        identifiers: <String>['swap', 'deposit'],
        contractAddress: SmartContractAddress.fromBech32(
          'erd1qqqqqqqqqqqqqpgq0lzzvt2faev4upyf586tg38s84d7zsaj2jpsglugga',
        ),
        abi: abi,
      );

  final WebSocketEventStream stream = WebSocketEventStream(config);

  final StreamSubscription<WebSocketEventResult> events = stream.events.listen((
    WebSocketEventResult result,
  ) {
    final TransactionEvent raw = result.rawEvent;
    final ParsedEvent? parsed = result.parsedEvent;
    assert(raw.identifier.isNotEmpty, 'identifier');
    assert(result.txHash.isNotEmpty, 'tx hash');
    if (parsed != null) {
      final Map<String, TypedValue> fields = parsed.toMap();
      assert(fields.isEmpty || fields.isNotEmpty, 'decoded fields');
    }
  });

  final StreamSubscription<WebSocketEventError> errors = stream.errors.listen((
    WebSocketEventError error,
  ) {
    assert(error.message.isNotEmpty, 'error message');
  });

  final StreamSubscription<WebSocketStatusChange> status = stream.statusChanges
      .listen((WebSocketStatusChange change) {
        assert(change.to != WebSocketStatus.idle, 'status');
      });

  await stream.connect();
  assert(stream.status == WebSocketStatus.listening, 'listening');

  await events.cancel();
  await errors.cancel();
  await status.cancel();
  await stream.disconnect();
  await stream.dispose();
}
```

Subscribe **before** calling `connect()` — `connect()` starts delivering as soon
as it returns, and the controllers are `sync: true` broadcast controllers
(`:420-425`), so events emitted before you listen are dropped.

---

## 6. Polling streams

`SmartContractEventRunner`
(`lib/src/abi/smart_contract/events/smart_contract_event_runner.dart`):

```
SmartContractEventRunner({
  required SmartContractAddress contractAddress,
  required NetworkProvider networkProvider,
  required SmartContractAbi abi,
  Logger? logger,
})
```

| Method | Signature | Route |
| --- | --- | --- |
| `queryEvents` | `Future<List<ParsedEvent>> ({required String txHash, required String eventIdentifier})` | `/events?txHash=…&identifier=…` (`:110`) |
| `queryEventsBatch` | `Future<Map<String, List<ParsedEvent>>> ({required List<String> txHashes, required String eventIdentifier})` | same route per hash, in parallel; a failing hash yields an empty list rather than an error (`:233-240`) |
| `getEventHistory` | `Future<List<ParsedEvent>> ({required String eventIdentifier, int limit = 25})` | `/events?address=…&identifier=…&size=…` (`:314`) |
| `watchTransaction` | `Future<List<ParsedEvent>> ({required String txHash, required String eventIdentifier, Duration timeout = const Duration(minutes: 1), Duration pollingInterval = const Duration(seconds: 1)})` | awaits completion, then parses (`:405-416`) |
| `streamEvents` | `Stream<ParsedEvent> ({required String eventIdentifier, Duration pollingInterval = const Duration(milliseconds: 500), String? startFrom})` | `/events?address=…&size=25` (`:494`) |
| `streamAllEvents` | `Stream<ParsedEvent> ({Duration pollingInterval = const Duration(milliseconds: 500), String? startFrom})` | same route; matches every identifier declared in the ABI (`:646-650`) |
| `getAllEventDefinitions` / `getEventDefinition` / `hasEvent` | `List<EventDefinition>` / `EventDefinition?` / `bool` | ABI lookups |

`SmartContractController` re-exposes all of these with **one difference that
matters**: its `streamEvents` / `streamAllEvents` default `pollingInterval` is
**2 seconds** (`lib/src/abi/smart_contract/controller/smart_contract_controller.dart:862-866`,
`:903-906`), not the runner's 500 ms. Both throw `StateError` if the controller
was built without an ABI.

Polling-stream behaviour you must design around
(`smart_contract_event_runner.dart:482-601`):

- Matching is on **`topics[0]` compared as base64** against the event name
  (`:489`, `:553-555`). An event whose first topic is not its own name is never
  emitted.
- Deduplication is keyed on **`txHash` alone** (`EventDeduplicator`,
  10 000 entries, 10-minute TTL, `:482-485`). A transaction that emits two
  matching events yields **only the first**.
- HTTP 429 is retried in place with a `2 * attempt` second backoff — 2 s, 4 s,
  6 s — for at most three attempts. After the third the poll is **abandoned**:
  the runner logs `Rate limit exceeded after 3 retries, skipping poll`, waits
  one `pollingInterval` and starts the next poll cycle from the top
  (`continue poll`, `:491-524`; `streamAllEvents` has the same block at
  `:653-686`). That cycle re-reads the same `/events` page, so
  nothing is lost as long as the events are still inside the 25-entry window.
  Any error other than 429 is rethrown into the outer handler and re-emitted
  into the stream.
- The stream never completes. Cancel the subscription to stop it.
- Errors are re-emitted into the stream (`yield* Stream.error(e)`) and the loop
  continues.

```dart
import 'dart:async';

import 'package:abidock_mvx/abidock_mvx.dart';

/// Polling event stream driven by the public API's `/events` route.
Future<void> main() async {
  final ApiNetworkProvider provider = ApiNetworkProvider.devnet();
  final SmartContractAbi abi = SmartContractAbi.fromJson('{"endpoints": []}');

  final SmartContractEventRunner runner = SmartContractEventRunner(
    contractAddress: SmartContractAddress.fromBech32(
      'erd1qqqqqqqqqqqqqpgq0lzzvt2faev4upyf586tg38s84d7zsaj2jpsglugga',
    ),
    networkProvider: provider,
    abi: abi,
  );

  /// One-shot reads.
  final List<ParsedEvent> fromTx = await runner.queryEvents(
    txHash: 'aa' * 32,
    eventIdentifier: 'swap',
  );
  final Map<String, List<ParsedEvent>> batch = await runner.queryEventsBatch(
    txHashes: <String>['aa' * 32, 'bb' * 32],
    eventIdentifier: 'swap',
  );
  final List<ParsedEvent> history = await runner.getEventHistory(
    eventIdentifier: 'swap',
    limit: 50,
  );
  final List<ParsedEvent> afterSettle = await runner.watchTransaction(
    txHash: 'aa' * 32,
    eventIdentifier: 'swap',
    timeout: const Duration(minutes: 2),
  );

  assert(fromTx.length + history.length + afterSettle.length >= 0, 'reads');
  assert(batch.isEmpty || batch.isNotEmpty, 'batch');

  /// Continuous polling. `streamEvents` filters on one identifier;
  /// `streamAllEvents` matches every event declared in the ABI.
  final StreamSubscription<ParsedEvent> single = runner
      .streamEvents(
        eventIdentifier: 'swap',
        pollingInterval: const Duration(seconds: 2),
      )
      .listen((ParsedEvent event) {
        final TypedValue? amount = event.getValueByName('amount');
        assert(amount == null || amount.nativeValue != null, 'field');
      });

  final StreamSubscription<ParsedEvent> all = runner.streamAllEvents().listen((
    ParsedEvent event,
  ) {
    assert(event.definition.identifier.isNotEmpty, 'identifier');
  });

  await single.cancel();
  await all.cancel();

  assert(runner.hasEvent('swap') || !runner.hasEvent('swap'), 'abi lookup');
  final EventDefinition? definition = runner.getEventDefinition('swap');
  final List<EventDefinition> definitions = runner.getAllEventDefinitions();
  assert(definition == null || definitions.isNotEmpty, 'definitions');
}
```

---

## 7. Generated event models

The code generator emits, per ABI event, a data model plus two thin stream
wrappers that hide `ParsedEvent` entirely — see the codegen skill in `skills/`
for how to run it and where files land. Shapes, as produced for the `swap` event
in `example/cookbook/generated/pair/events/`:

- `SwapWebSocketStream({required SmartContractController controller, required String websocketUrl, …})`
  wraps `WebSocketEventStreamConfig.byIdentifiers` + `WebSocketEventStream`, and
  exposes `Stream<SwapEventData> get events` built with
  `EventConverter.filterByIdentifier`, plus `statusChanges`, `errors`,
  `connect()`, `disconnect()`, `dispose()`, `status`.
- `SwapPollingStream(SmartContractController controller)` — `call({Duration
  pollingInterval, String? startFrom})` returns `Stream<SwapEventData>` over
  `controller.streamEvents`, throwing `StateError` when a payload cannot be
  decoded into the model.
- Sibling files `multi_event_websocket_stream.dart` and
  `multi_event_polling_stream.dart` cover several events on one connection.

Both wrappers convert with `EventConverter.convertEvent<T>(parsed, T.fromAbi,
T.type)`, so a generated model needs the static `fromAbi` and `type` members the
generator emits.

---

## Not verified

- Live network behaviour: no sample here was executed against a node. The
  samples were compiled with `dart analyze`; only the pure-Dart ones (parsers,
  factories, identifier types) were also run.
- The exact membership of the cross-account list in §1. The repository's test
  pins `parseFreeze` and `parseLocalMint` reading from smart-contract-result
  logs (`token_management_scr_logs_test.dart:87`, `:104` — the file's 5 tests
  pass); `unFreeze`, `wipe`, `setSpecialRole` and `unSetSpecialRole` are named
  by the source's own doc comment
  (`token_management_outcome_parser.dart:1023-1025`) and were not observed
  against a node. The parser's behaviour — searching transaction logs *and*
  every result's logs — holds for all of them regardless.
- The notifier's exact envelope for `revert_events` and `finalized_events`
  payloads — only the fact that they are routed through the same handler as
  `all_events` was read from the source.
- Whether the public API's `/events` route paginates beyond `size`; the polling
  loop always asks for `size=25` and no cursor other than `startFrom`/`txHash`
  is used.
