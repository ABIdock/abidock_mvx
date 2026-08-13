/// Regression tests for [TransferTransactionsFactory.createTransactionForTransfer].
///
/// The unified builder used to guard the "data plus tokens" conflict with
/// `data != null && data.isNotEmpty` but branch on `data != null`. A caller
/// passing `data: Uint8List(0)` alongside token transfers slipped through the
/// guard, took the plain-value branch, and got back a transaction with an
/// empty data field and value 0 — the token transfers were discarded with no
/// exception raised.
///
/// A zero-length data field is indistinguishable from an absent one once the
/// transaction is on the wire, so `Uint8List(0)` must behave exactly like
/// `null`: same protocol selection, same bytes, same gas. Every expectation
/// below is a literal worked out from the protocol's data-movement economics
/// (`50000` floor, `1500` gas per data byte) plus the transfer execution
/// allowance, never read back from a config object.
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  const ChainId chainD = ChainId('D');

  final Address sender = Address.fromBech32(
    'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
  );
  final Address receiver = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );

  final TransferTransactionsFactory factory = TransferTransactionsFactory(
    config: const TransferTransactionsConfig(chainId: chainD),
  );

  List<TokenTransfer> oneFungible() => <TokenTransfer>[
    TokenTransfer.fungible(
      tokenIdentifier: 'FRANK-11ce3e',
      amount: BigInt.from(100),
    ),
  ];

  List<TokenTransfer> oneNonFungible() => <TokenTransfer>[
    TokenTransfer.nonFungible(
      tokenIdentifier: 'TEST-38f249',
      nonce: 1,
      amount: BigInt.one,
    ),
  ];

  String dataOf(Transaction tx) => utf8.decode(tx.data);

  group('empty data never discards token transfers', () {
    test('one fungible transfer still builds ESDTTransfer', () {
      final Transaction tx = factory.createTransactionForTransfer(
        sender: sender,
        receiver: receiver,
        tokenTransfers: oneFungible(),
        data: Uint8List(0),
      );

      expect(dataOf(tx), equals('ESDTTransfer@4652414e4b2d313163653365@64'));
      expect(tx.data.length, equals(40));
      expect(tx.value.value, equals(BigInt.zero));
      expect(
        tx.receiver.bech32,
        equals(
          'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
        ),
      );
      expect(tx.gasLimit.value, equals(410000));
    });

    test('one fungible transfer is byte-identical to the no-data call', () {
      final Transaction withoutData = factory.createTransactionForTransfer(
        sender: sender,
        receiver: receiver,
        tokenTransfers: oneFungible(),
      );
      final Transaction withEmptyData = factory.createTransactionForTransfer(
        sender: sender,
        receiver: receiver,
        tokenTransfers: oneFungible(),
        data: Uint8List(0),
      );

      expect(withEmptyData.data, equals(withoutData.data));
      expect(withEmptyData.value.value, equals(withoutData.value.value));
      expect(
        withEmptyData.receiver.bech32,
        equals(withoutData.receiver.bech32),
      );
      expect(withEmptyData.gasLimit.value, equals(withoutData.gasLimit.value));
    });

    test('one NFT transfer still builds ESDTNFTTransfer', () {
      final Transaction tx = factory.createTransactionForTransfer(
        sender: sender,
        receiver: receiver,
        tokenTransfers: oneNonFungible(),
        data: Uint8List(0),
      );

      expect(
        dataOf(tx),
        equals(
          'ESDTNFTTransfer@544553542d333866323439@01@01@'
          '0139472eff6886771a982f3083da5d421f24c29181e63888228dc81ca60d69e1',
        ),
      );
      expect(tx.data.length, equals(109));
      expect(tx.value.value, equals(BigInt.zero));
      expect(
        tx.receiver.bech32,
        equals(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
      );
      expect(tx.gasLimit.value, equals(1213500));
    });

    test('two transfers still build MultiESDTNFTTransfer', () {
      final Transaction tx = factory.createTransactionForTransfer(
        sender: sender,
        receiver: receiver,
        tokenTransfers: <TokenTransfer>[...oneFungible(), ...oneNonFungible()],
        data: Uint8List(0),
      );

      expect(
        dataOf(tx),
        equals(
          'MultiESDTNFTTransfer@'
          '0139472eff6886771a982f3083da5d421f24c29181e63888228dc81ca60d69e1'
          '@02@4652414e4b2d313163653365@@64@544553542d333866323439@01@01',
        ),
      );
      expect(tx.data.length, equals(146));
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(1469000));
    });

    test('EGLD bundled with a token is unaffected by empty data', () {
      final Transaction withoutData = factory.createTransactionForTransfer(
        sender: sender,
        receiver: receiver,
        nativeAmount: Balance(BigInt.parse('1000000000000000000')),
        tokenTransfers: oneFungible(),
      );
      final Transaction withEmptyData = factory.createTransactionForTransfer(
        sender: sender,
        receiver: receiver,
        nativeAmount: Balance(BigInt.parse('1000000000000000000')),
        tokenTransfers: oneFungible(),
        data: Uint8List(0),
      );

      expect(withEmptyData.data, equals(withoutData.data));
      expect(dataOf(withEmptyData), startsWith('MultiESDTNFTTransfer@'));
      expect(withEmptyData.data.length, equals(136));
      expect(withEmptyData.value.value, equals(BigInt.zero));
      expect(withEmptyData.gasLimit.value, equals(1454000));
    });
  });

  group('non-empty data alongside token transfers is still rejected', () {
    test('throws ArgumentError instead of dropping the transfers', () {
      expect(
        () => factory.createTransactionForTransfer(
          sender: sender,
          receiver: receiver,
          tokenTransfers: oneFungible(),
          data: utf8.encode('hello'),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message,
            'message',
            equals('Cannot set data field when sending ESDT tokens'),
          ),
        ),
      );
    });
  });

  group('EGLD-only transfers keep working', () {
    test('empty data yields a bare value transfer at the minimum gas', () {
      final Transaction tx = factory.createTransactionForTransfer(
        sender: sender,
        receiver: receiver,
        nativeAmount: Balance(BigInt.parse('1000000000000000000')),
        data: Uint8List(0),
      );

      expect(tx.data.length, equals(0));
      expect(tx.value.value, equals(BigInt.parse('1000000000000000000')));
      expect(
        tx.receiver.bech32,
        equals(
          'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
        ),
      );
      expect(tx.gasLimit.value, equals(50000));
    });

    test('a real payload is preserved and charged per byte', () {
      final Transaction tx = factory.createTransactionForTransfer(
        sender: sender,
        receiver: receiver,
        nativeAmount: Balance(BigInt.parse('1000000000000000000')),
        data: utf8.encode('hello'),
      );

      expect(dataOf(tx), equals('hello'));
      expect(tx.value.value, equals(BigInt.parse('1000000000000000000')));
      expect(tx.gasLimit.value, equals(57500));
    });

    test('a payload without any value is still a data-only transaction', () {
      final Transaction tx = factory.createTransactionForTransfer(
        sender: sender,
        receiver: receiver,
        data: utf8.encode('hello'),
      );

      expect(dataOf(tx), equals('hello'));
      expect(tx.value.value, equals(BigInt.zero));
      expect(tx.gasLimit.value, equals(57500));
    });
  });

  group(
    'nothing to transfer is rejected the same way with or without data',
    () {
      test('no amount, no transfers, no data', () {
        expect(
          () => factory.createTransactionForTransfer(
            sender: sender,
            receiver: receiver,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (ArgumentError e) => e.message,
              'message',
              equals('No token transfers provided'),
            ),
          ),
        );
      });

      test('no amount, no transfers, empty data', () {
        expect(
          () => factory.createTransactionForTransfer(
            sender: sender,
            receiver: receiver,
            data: Uint8List(0),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (ArgumentError e) => e.message,
              'message',
              equals('No token transfers provided'),
            ),
          ),
        );
      });
    },
  );
}
