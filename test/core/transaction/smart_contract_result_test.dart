import 'dart:convert';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// Encodes [text] the same way MultiversX API payloads arrive: base64.
String _b64(String text) => base64.encode(utf8.encode(text));

String _hex(List<int> bytes) =>
    bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('SmartContractResult.fromJson', () {
    test('parses a successful "@ok" payload (hex-encoded)', () {
      const String payload = '@6f6b@01@02';
      final json = <String, dynamic>{
        'hash': 'abcd',
        'nonce': 1,
        'value': '0',
        'sender':
            'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        'receiver':
            'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        'data': _b64(payload),
      };

      final scr = SmartContractResult.fromJson(json);
      expect(scr.hash, 'abcd');
      expect(scr.isSuccess, isTrue);
      expect(scr.returnData, hasLength(2));
      expect(scr.returnData[0], [0x01]);
      expect(scr.returnData[1], [0x02]);
    });

    test('parses a payload that arrives as raw UTF-8 (Gateway shape)', () {
      const String payload = '@6f6b@ab';
      final json = <String, dynamic>{
        'hash': 'deadbeef',
        'nonce': 0,
        'value': '0',
        'sender':
            'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        'receiver':
            'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        'data': payload,
      };
      final scr = SmartContractResult.fromJson(json);
      expect(scr.isSuccess, isTrue);
      expect(_hex(scr.returnData.single), 'ab');
    });

    test('parses a failure return code ("user error")', () {
      final String payload = '@${_hex(utf8.encode('user error'))}';
      final json = <String, dynamic>{
        'hash': 'failhash',
        'nonce': 2,
        'value': '0',
        'sender':
            'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        'receiver':
            'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        'data': _b64(payload),
        'returnMessage': 'boom',
      };
      final scr = SmartContractResult.fromJson(json);
      expect(scr.isSuccess, isFalse);
      expect(scr.isFailure, isTrue);
      expect(scr.errorMessage, 'boom');
    });

    test('tolerates numeric value field', () {
      final json = <String, dynamic>{
        'hash': 'h',
        'nonce': 0,
        'value': 0, // int, not string
        'sender':
            'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        'receiver':
            'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        'data': '',
      };
      final scr = SmartContractResult.fromJson(json);
      expect(scr.value, '0');
      expect(scr.returnCode, ReturnCode.none);
    });

    test('identifies async callback by callType', () {
      final json = <String, dynamic>{
        'hash': 'cb',
        'nonce': 0,
        'value': '0',
        'sender':
            'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        'receiver':
            'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu',
        'data': '',
        'callType': 2,
      };
      final scr = SmartContractResult.fromJson(json);
      expect(scr.isAsyncCallback, isTrue);
      expect(scr.isAsyncCall, isFalse);
    });
  });
}
