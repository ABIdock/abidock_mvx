import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  const TransactionComputer computer = TransactionComputer();

  final Address alice = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final Address bob = Address.fromBech32(
    'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
  );
  final Address grace = Address.fromBech32(
    'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g',
  );

  /// Ordinary (non-relayed, non-guarded) transaction fixture.
  Transaction ordinaryTx() => Transaction(
    nonce: const Nonce(7),
    sender: alice,
    receiver: bob,
    value: Balance(BigInt.parse('1000000000000000000')),
    gasLimit: const GasLimit(57500),
    gasPrice: const GasPrice(1000000000),
    chainId: const ChainId('D'),
    version: const TransactionVersion(2),
    data: Uint8List.fromList(utf8.encode('hello')),
  );

  /// Transaction populated with every optional field the node knows about.
  Transaction fullyPopulatedTx() => Transaction(
    nonce: const Nonce(7),
    sender: alice,
    receiver: bob,
    value: Balance(BigInt.parse('1000000000000000000')),
    senderUsername: 'alice',
    receiverUsername: 'bob',
    gasLimit: const GasLimit(57500),
    gasPrice: const GasPrice(1000000000),
    chainId: const ChainId('D'),
    version: const TransactionVersion(2),
    options: 2,
    data: Uint8List.fromList(utf8.encode('hello')),
    guardian: grace,
    relayer: bob,
    signature: Signature('ab' * 64),
    guardianSignature: Signature('cd' * 64),
    relayerSignature: Signature('ef' * 64),
  );

  const String ordinaryPayload =
      '{"nonce":7,"value":"1000000000000000000",'
      '"receiver":"erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8",'
      '"sender":"erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th",'
      '"gasPrice":1000000000,"gasLimit":57500,"data":"aGVsbG8=",'
      '"chainID":"D","version":2}';

  group('signing payload golden', () {
    test('ordinary transaction serializes to the exact node payload', () {
      final Uint8List bytes = computer.computeBytesForSigning(ordinaryTx());

      expect(utf8.decode(bytes), ordinaryPayload);
      expect(bytes.length, 274);
    });

    test('fully populated transaction pins the 14-key order', () {
      final Uint8List bytes = computer.computeBytesForSigning(
        fullyPopulatedTx(),
      );

      expect(
        utf8.decode(bytes),
        '{"nonce":7,"value":"1000000000000000000",'
        '"receiver":"erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8",'
        '"sender":"erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th",'
        '"senderUsername":"YWxpY2U=","receiverUsername":"Ym9i",'
        '"gasPrice":1000000000,"gasLimit":57500,"data":"aGVsbG8=",'
        '"chainID":"D","version":2,"options":2,'
        '"guardian":"erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g",'
        '"relayer":"erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8"}',
      );
      expect(bytes.length, 491);
      expect(computer.toPlainObject(fullyPopulatedTx()).keys.toList(), <String>[
        'nonce',
        'value',
        'receiver',
        'sender',
        'senderUsername',
        'receiverUsername',
        'gasPrice',
        'gasLimit',
        'data',
        'chainID',
        'version',
        'options',
        'guardian',
        'relayer',
      ]);
    });

    test('no signature ever reaches the signing payload', () {
      final Map<String, dynamic> payload = computer.toPlainObject(
        fullyPopulatedTx(),
      );

      expect(payload.containsKey('signature'), isFalse);
      expect(payload.containsKey('guardianSignature'), isFalse);
      expect(payload.containsKey('relayerSignature'), isFalse);
    });
  });

  group('relayed v3 flat shape', () {
    /// The relayed-v3 transaction from the protocol documentation.
    Transaction docsTx() => Transaction(
      nonce: const Nonce(0),
      sender: Address.fromBech32(
        'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx',
      ),
      receiver: Address.fromBech32(
        'erd1qqqqqqqqqqqqqpgqeunf87ar9nqeey5ssvpqwe74ehmztx74qtxqs63nmx',
      ),
      gasLimit: const GasLimit(5000000),
      gasPrice: const GasPrice(1000000000),
      chainId: const ChainId('T'),
      version: const TransactionVersion(2),
      data: Uint8List.fromList(utf8.encode('add@01')),
      relayer: Address.fromBech32(
        'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
      ),
    );

    test('signing payload matches the documented example byte for byte', () {
      final Uint8List bytes = computer.computeBytesForSigning(docsTx());

      expect(
        utf8.decode(bytes),
        '{"nonce":0,"value":"0",'
        '"receiver":"erd1qqqqqqqqqqqqqpgqeunf87ar9nqeey5ssvpqwe74ehmztx74qtxqs63nmx",'
        '"sender":"erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx",'
        '"gasPrice":1000000000,"gasLimit":5000000,"data":"YWRkQDAx",'
        '"chainID":"T","version":2,'
        '"relayer":"erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th"}',
      );
      expect(bytes.length, 333);
    });

    test('broadcast payload carries relayer and relayerSignature only', () {
      final Transaction signed = docsTx().copyWith(
        newSignature: Signature('ab' * 64),
        newRelayerSignature: Signature('ef' * 64),
      );

      final Map<String, dynamic> broadcast = signed.toJson();

      expect(
        broadcast['relayer'],
        'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
      );
      expect(
        broadcast['relayerSignature'],
        'efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef'
        'efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef',
      );
      expect(
        broadcast['signature'],
        'abababababababababababababababababababababababababababababababab'
        'abababababababababababababababababababababababababababababababab',
      );
      expect(broadcast.containsKey('guardian'), isFalse);
    });
  });

  group('broadcast payload key set', () {
    test('an ordinary signed transaction carries exactly ten keys', () {
      final Transaction signed = ordinaryTx().copyWith(
        newSignature: Signature('ab' * 64),
      );

      final Map<String, dynamic> broadcast = signed.toJson();

      expect(broadcast.keys.toList(), <String>[
        'nonce',
        'value',
        'receiver',
        'sender',
        'gasPrice',
        'gasLimit',
        'data',
        'chainID',
        'version',
        'signature',
      ]);
    });
  });

  group('Transaction.serializeForSigning', () {
    test('returns the raw JSON payload when hash signing is off', () {
      expect(utf8.decode(ordinaryTx().serializeForSigning()), ordinaryPayload);
    });

    test('returns the Keccak-256 digest when the hash-sign bit is set', () {
      final Transaction hashSigned = computer.applyOptionsForHashSigning(
        ordinaryTx(),
      );

      final Uint8List bytes = hashSigned.serializeForSigning();

      expect(bytes.length, 32);
      expect(
        HexUtils.bytesToHex(bytes),
        'a871821a167a72372f0ffea757f5b266975933f06a271d7a1a5a31346f21f744',
      );
      expect(
        utf8.decode(computer.computeBytesForSigning(hashSigned)),
        '{"nonce":7,"value":"1000000000000000000",'
        '"receiver":"erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8",'
        '"sender":"erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th",'
        '"gasPrice":1000000000,"gasLimit":57500,"data":"aGVsbG8=",'
        '"chainID":"D","version":2,"options":1}',
      );
    });
  });
}
