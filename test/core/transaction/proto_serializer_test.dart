import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  const serializer = ProtoSerializer();
  final sender = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final receiver = Address.fromBech32(
    'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
  );

  Transaction tx({
    Nonce nonce = const Nonce(0),
    Balance? value,
    Address? relayer,
    Signature relayerSig = const Signature.empty(),
  }) {
    return Transaction(
      nonce: nonce,
      sender: sender,
      receiver: receiver,
      value: value,
      gasLimit: const GasLimit(50000),
      gasPrice: const GasPrice(1_000_000_000),
      chainId: const ChainId('D'),
      version: const TransactionVersion(2),
      data: Uint8List(0),
      relayer: relayer,
      relayerSignature: relayerSig,
    );
  }

  group('ProtoSerializer', () {
    test('serializes zero value as [0x00, 0x00]', () {
      final bytes = serializer.serializeTransaction(tx());

      const valueFieldKey = (2 << 3) | 2;
      final idx = bytes.indexOf(valueFieldKey);
      expect(idx, isNonNegative);
      expect(bytes[idx + 1], 2);
      expect(bytes[idx + 2], 0x00);
      expect(bytes[idx + 3], 0x00);
    });

    test('serializes non-zero value with sign byte', () {
      final bytes = serializer.serializeTransaction(
        tx(value: Balance(BigInt.from(255))),
      );

      const valueFieldKey = (2 << 3) | 2;
      final idx = bytes.indexOf(valueFieldKey);
      expect(bytes[idx + 1], 2);
      expect(bytes[idx + 2], 0x00);
      expect(bytes[idx + 3], 0xff);
    });

    test('emits no proto field beyond 17 for a relayed transaction', () {
      final Uint8List bytes = serializer.serializeTransaction(
        tx(relayer: sender, relayerSig: Signature('ab' * 64)),
      );

      final Map<int, List<Uint8List>> fields = _decodeProtoFields(bytes);

      expect(fields.containsKey(16), isTrue);
      expect(fields.containsKey(17), isTrue);
      expect(
        fields.keys.reduce((int a, int b) => a > b ? a : b),
        17,
        reason:
            'The transaction message on the wire declares fields 1-17 only; '
            'any higher tag changes the hash the chain derives.',
      );
    });

    test('elides guardian fields when no guardian signature', () {
      final out = serializer.serializeTransaction(tx());
      const field14Key = (14 << 3) | 2;
      const field15Key = (15 << 3) | 2;
      expect(out.contains(field14Key), isFalse);
      expect(out.contains(field15Key), isFalse);
    });

    test('produces deterministic output for the same tx', () {
      final a = serializer.serializeTransaction(tx(nonce: const Nonce(5)));
      final b = serializer.serializeTransaction(tx(nonce: const Nonce(5)));
      expect(a, orderedEquals(b));
    });

    test('encodes sender/receiver username as base64-string bytes', () {
      const String aliceUsername = 'alice';
      const String bobUsername = 'bob';

      final Transaction withUsernames = Transaction(
        nonce: const Nonce(0),
        sender: sender,
        receiver: receiver,
        senderUsername: aliceUsername,
        receiverUsername: bobUsername,
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1_000_000_000),
        chainId: const ChainId('D'),
        version: const TransactionVersion(2),
        data: Uint8List(0),
      );

      final Uint8List bytes = serializer.serializeTransaction(withUsernames);
      final Map<int, List<Uint8List>> fields = _decodeProtoFields(bytes);

      final List<int> expectedReceiverBytes = utf8.encode(
        base64.encode(utf8.encode(bobUsername)),
      );
      expect(fields[4], hasLength(1));
      expect(fields[4]!.single, orderedEquals(expectedReceiverBytes));

      final List<int> expectedSenderBytes = utf8.encode(
        base64.encode(utf8.encode(aliceUsername)),
      );
      expect(fields[6], hasLength(1));
      expect(fields[6]!.single, orderedEquals(expectedSenderBytes));

      final List<int> rawSenderBytes = utf8.encode(aliceUsername);
      expect(rawSenderBytes.length, isNot(expectedSenderBytes.length));
    });

    test('C-5: omits username fields entirely when empty', () {
      final Uint8List bytes = serializer.serializeTransaction(tx());
      final Map<int, List<Uint8List>> fields = _decodeProtoFields(bytes);
      expect(fields.containsKey(4), isFalse);
      expect(fields.containsKey(6), isFalse);
    });
  });
}

/// Minimal protobuf decoder that returns every length-delimited and varint
/// field present in `bytes`, keyed by field number.
///
/// Robust against the `indexOf(tag-byte)` pitfall where the tag byte (e.g.
/// `0x22` for field 4) collides with a content byte inside an earlier
/// length-delimited field (commonly the 32-byte address fields).
///
/// #### Parameters
/// - `bytes` - Protobuf-encoded transaction bytes
///
/// #### Returns
/// `Map<int, List<Uint8List>>` - Field number → list of payload occurrences
Map<int, List<Uint8List>> _decodeProtoFields(Uint8List bytes) {
  final Map<int, List<Uint8List>> result = <int, List<Uint8List>>{};
  int offset = 0;
  while (offset < bytes.length) {
    final _VarintReadResult tag = _readVarint(bytes, offset);
    offset = tag.offset;
    final int fieldNumber = tag.value >> 3;
    final int wireType = tag.value & 0x07;
    if (wireType == 0) {
      final _VarintReadResult value = _readVarint(bytes, offset);
      offset = value.offset;
      result
          .putIfAbsent(fieldNumber, () => <Uint8List>[])
          .add(Uint8List.fromList(<int>[value.value]));
    } else if (wireType == 2) {
      final _VarintReadResult length = _readVarint(bytes, offset);
      offset = length.offset;
      final Uint8List payload = Uint8List.sublistView(
        bytes,
        offset,
        offset + length.value,
      );
      offset += length.value;
      result.putIfAbsent(fieldNumber, () => <Uint8List>[]).add(payload);
    } else {
      throw StateError('Unsupported wire type $wireType at offset $offset');
    }
  }
  return result;
}

class _VarintReadResult {
  const _VarintReadResult(this.value, this.offset);
  final int value;
  final int offset;
}

_VarintReadResult _readVarint(Uint8List bytes, int start) {
  int value = 0;
  int shift = 0;
  int offset = start;
  while (offset < bytes.length) {
    final int byte = bytes[offset];
    offset += 1;
    value |= (byte & 0x7F) << shift;
    if ((byte & 0x80) == 0) {
      return _VarintReadResult(value, offset);
    }
    shift += 7;
  }
  throw StateError('Truncated varint starting at $start');
}
