/// Regression tests for token-management outcomes reported on a
/// smart-contract result rather than on the transaction itself.
///
/// `freeze`, `unFreeze`, `wipe`, `setSpecialRole`, `unSetSpecialRole` and the
/// local mint/burn pair are executed by the system contract forwarding a
/// built-in call to the target address. That call runs on the target's shard,
/// so its event is attached to the resulting smart-contract result. A parser
/// that reads only the transaction's own logs returns an empty list for every
/// real cross-account operation, and — worse — misses a `signalError` that
/// appears only on a result, turning a failed transaction into a silent
/// success.
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

const String holderBech32 =
    'erd1r69gk66fmedhhcg24g2c5kn2f2a5k4kvpr6jfw67dn2lyydd8cfswy6ede';
const String esdtSystemContractBech32 =
    'erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u';

/// ASCII topic, the encoding used for identifiers and messages.
Uint8List text(String value) => Uint8List.fromList(utf8.encode(value));

/// Raw byte topic, used for unsigned big-endian numbers and pubkeys.
Uint8List bytes(List<int> value) => Uint8List.fromList(value);

void main() {
  const TokenManagementOutcomeParser parser = TokenManagementOutcomeParser();

  final Address holder = Address.fromBech32(holderBech32);
  final Address esdtContract = Address.fromBech32(esdtSystemContractBech32);

  final Transaction baseTransaction = Transaction(
    sender: holder,
    receiver: esdtContract,
    value: Balance.zero(),
    gasLimit: const GasLimit(60000000),
    gasPrice: const GasPrice(1000000000),
    chainId: const ChainId('D'),
    nonce: const Nonce(7),
    data: Uint8List(0),
    version: const TransactionVersion(1),
  );

  TransactionEvent event(
    String identifier,
    List<Uint8List> topics, {
    List<Uint8List> additionalData = const <Uint8List>[],
  }) {
    return TransactionEvent(
      address: holder,
      identifier: identifier,
      topics: topics,
      data: Uint8List(0),
      additionalData: additionalData,
    );
  }

  /// Builds a transaction whose only logs live on a smart-contract result.
  TransactionOnNetwork withResultLogs(TransactionEvent scrEvent) {
    return TransactionOnNetwork(
      transaction: baseTransaction,
      status: const TransactionStatus('success'),
      txHash: 'aa'.padLeft(64, '0'),
      smartContractResults: <SmartContractResult>[
        SmartContractResult(
          hash: 'bb'.padLeft(64, '0'),
          nonce: 0,
          value: '0',
          sender: esdtContract,
          receiver: holder,
          data: Uint8List(0),
          returnCode: ReturnCode.none,
          returnData: const <Uint8List>[],
          logs: TransactionLogs(
            address: holder,
            events: <TransactionEvent>[scrEvent],
          ),
        ),
      ],
    );
  }

  group('events reported on a smart-contract result', () {
    test('parseFreeze reads a freeze event from the result logs', () {
      final TransactionOnNetwork transaction = withResultLogs(
        event('ESDTFreeze', <Uint8List>[
          text('FRANK-11ce3e'),
          Uint8List(0),
          bytes(<int>[0x03, 0xe8]),
          bytes(holder.bytes),
        ]),
      );

      final List<FreezeResult> results = parser.parseFreeze(transaction);

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('FRANK-11ce3e'));
      expect(results.single.balance, equals(BigInt.from(1000)));
    });

    test('parseLocalMint reads a mint event from the result logs', () {
      final TransactionOnNetwork transaction = withResultLogs(
        event('ESDTLocalMint', <Uint8List>[
          text('FRANK-11ce3e'),
          Uint8List(0),
          bytes(<int>[0x07, 0xd0]),
        ]),
      );

      final List<LocalMintResult> results = parser.parseLocalMint(transaction);

      expect(results, hasLength(1));
      expect(results.single.tokenIdentifier, equals('FRANK-11ce3e'));
      expect(results.single.mintedSupply, equals(BigInt.from(2000)));
    });
  });

  group('signalError reported on a smart-contract result', () {
    test('is not mistaken for an empty success', () {
      final TransactionOnNetwork transaction = withResultLogs(
        event('signalError', <Uint8List>[
          bytes(holder.bytes),
          text('cannot freeze a non-freezable token'),
        ]),
      );

      expect(
        () => parser.parseFreeze(transaction),
        throwsA(isA<TokenManagementParseException>()),
      );
    });

    test('renders the decoded message, not the raw byte list', () {
      final TransactionOnNetwork transaction = withResultLogs(
        event(
          'signalError',
          <Uint8List>[bytes(holder.bytes), text('insufficient funds')],
          additionalData: <Uint8List>[text('user error')],
        ),
      );

      expect(
        () => parser.parseFreeze(transaction),
        throwsA(
          isA<TokenManagementParseException>().having(
            (TokenManagementParseException e) => e.message,
            'message',
            allOf(contains('insufficient funds'), contains('user error')),
          ),
        ),
      );
    });
  });

  group('transactions with no logs anywhere', () {
    test('still report that the outcome cannot be parsed', () {
      final TransactionOnNetwork transaction = TransactionOnNetwork(
        transaction: baseTransaction,
        status: const TransactionStatus('success'),
        txHash: 'aa'.padLeft(64, '0'),
      );

      expect(
        () => parser.parseFreeze(transaction),
        throwsA(isA<TokenManagementParseException>()),
      );
    });
  });
}
