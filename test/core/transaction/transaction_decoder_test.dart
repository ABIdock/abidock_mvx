import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// Helper: builds a transaction with the given data payload.
Transaction _tx({
  Uint8List? data,
  Balance? value,
  Address? sender,
  Address? receiver,
}) {
  return Transaction(
    nonce: const Nonce(0),
    sender:
        sender ??
        Address.fromBech32(
          'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        ),
    receiver:
        receiver ??
        Address.fromBech32(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
    value: value ?? Balance.zero(),
    gasLimit: const GasLimit(50000),
    gasPrice: const GasPrice(1000000000),
    chainId: const ChainId('1'),
    version: const TransactionVersion(1),
    data: data ?? Uint8List(0),
  );
}

String _hex(List<int> bytes) =>
    bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  const TransactionDecoder decoder = TransactionDecoder();

  group('TransactionDecoder', () {
    test('decodes empty data as a native EGLD transfer', () {
      final tx = _tx(value: Balance.fromEgld(2.5));
      final result = decoder.decode(tx);
      expect(result, isA<NativeEgldTransfer>());
      final nat = result as NativeEgldTransfer;
      expect(nat.memo, isNull);
      expect(nat.value.value, Balance.fromEgld(2.5).value);
    });

    test('decodes free-form memo as a native EGLD transfer', () {
      final tx = _tx(data: Uint8List.fromList(utf8.encode('hello world')));
      final result = decoder.decode(tx);
      expect(result, isA<NativeEgldTransfer>());
      expect((result as NativeEgldTransfer).memo, 'hello world');
    });

    test('decodes a plain ESDTTransfer', () {
      // ESDTTransfer@<tokenHex>@<amountHex>
      final String tokenHex = _hex(utf8.encode('WEGLD-bd4d79'));
      final String amountHex = BigInt.from(12345).toRadixString(16);
      final String payload = 'ESDTTransfer@$tokenHex@$amountHex';
      final tx = _tx(data: Uint8List.fromList(utf8.encode(payload)));

      final result = decoder.decode(tx);
      expect(result, isA<EsdtTransfer>());
      final esdt = result as EsdtTransfer;
      expect(esdt.tokenIdentifier, 'WEGLD-bd4d79');
      expect(esdt.amount, BigInt.from(12345));
      expect(esdt.functionCall, isNull);
    });

    test('decodes ESDTTransfer with inner function call', () {
      final String tokenHex = _hex(utf8.encode('USDC-c76f1f'));
      final String amountHex = BigInt.from(1000).toRadixString(16);
      const String argHex = '01'; // one byte argument
      final String payload = 'ESDTTransfer@$tokenHex@$amountHex@swap@$argHex';
      final tx = _tx(data: Uint8List.fromList(utf8.encode(payload)));

      final result = decoder.decode(tx);
      expect(result, isA<EsdtTransfer>());
      final esdt = result as EsdtTransfer;
      expect(esdt.functionCall, isNotNull);
      expect(esdt.functionCall!.function, 'swap');
      expect(esdt.functionCall!.arguments, hasLength(1));
      expect(esdt.functionCall!.arguments.first, Uint8List.fromList([0x01]));
    });

    test('decodes ESDTNFTTransfer', () {
      final String collectionHex = _hex(utf8.encode('MYNFT-abcdef'));
      const String nonceHex = '0a'; // 10
      const String amountHex = '01';
      final Address dest = Address.fromBech32(
        'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
      );
      final String destHex = _hex(dest.bytes);
      final String payload =
          'ESDTNFTTransfer@$collectionHex@$nonceHex@$amountHex@$destHex';
      final tx = _tx(data: Uint8List.fromList(utf8.encode(payload)));

      final result = decoder.decode(tx);
      expect(result, isA<NftTransfer>());
      final nft = result as NftTransfer;
      expect(nft.collection, 'MYNFT-abcdef');
      expect(nft.nonce, 10);
      expect(nft.amount, BigInt.one);
      expect(nft.destination.bech32, dest.bech32);
      expect(nft.functionCall, isNull);
    });

    test('decodes MultiESDTNFTTransfer with two legs', () {
      final Address dest = Address.fromBech32(
        'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
      );
      final String destHex = _hex(dest.bytes);
      const String countHex = '02';

      final String tok1 = _hex(utf8.encode('ALPHA-111111'));
      const String non1 = '00';
      final String amt1 = BigInt.from(100).toRadixString(16);

      final String tok2 = _hex(utf8.encode('BETA-222222'));
      const String non2 = '05';
      const String amt2 = '01';

      final String payload =
          'MultiESDTNFTTransfer@$destHex@$countHex'
          '@$tok1@$non1@$amt1'
          '@$tok2@$non2@$amt2';
      final tx = _tx(data: Uint8List.fromList(utf8.encode(payload)));

      final result = decoder.decode(tx);
      expect(result, isA<MultiTransfer>());
      final multi = result as MultiTransfer;
      expect(multi.destination.bech32, dest.bech32);
      expect(multi.transfers, hasLength(2));
      expect(multi.transfers[0].tokenIdentifier, 'ALPHA-111111');
      expect(multi.transfers[0].isFungible, isTrue);
      expect(multi.transfers[0].amount, BigInt.from(100));
      expect(multi.transfers[1].tokenIdentifier, 'BETA-222222');
      expect(multi.transfers[1].isFungible, isFalse);
      expect(multi.transfers[1].nonce, 5);
      expect(multi.functionCall, isNull);
    });

    test('decodes a plain contract call (no transfer prefix)', () {
      const String payload = 'claimRewards@01@02';
      final tx = _tx(data: Uint8List.fromList(utf8.encode(payload)));

      final result = decoder.decode(tx);
      expect(result, isA<ContractCall>());
      final call = result as ContractCall;
      expect(call.call.function, 'claimRewards');
      expect(call.call.arguments, hasLength(2));
    });

    test('returns UnknownTransaction for truncated MultiESDTNFTTransfer', () {
      final Address dest = Address.fromBech32(
        'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
      );
      final String destHex = _hex(dest.bytes);
      // Claims 3 legs but only provides 1.
      final String payload =
          'MultiESDTNFTTransfer@$destHex@03@${_hex(utf8.encode('X-000001'))}@00@01';
      final tx = _tx(data: Uint8List.fromList(utf8.encode(payload)));

      final result = decoder.decode(tx);
      expect(result, isA<UnknownTransaction>());
      expect((result as UnknownTransaction).reason, contains('truncated'));
    });

    test('returns UnknownTransaction on malformed argument', () {
      // Odd-length hex argument.
      const String payload = 'myCall@abc';
      final tx = _tx(data: Uint8List.fromList(utf8.encode(payload)));

      final result = decoder.decode(tx);
      expect(result, isA<UnknownTransaction>());
    });
  });
}
