/// Tests for [AccountOnNetwork.fromApiResponse] focusing on the
/// supernova-era `codeMetadata` base64 decoding path (audit H3-1).
///
/// Sibling of [account_on_network_proxy_test] — mirrors the same matrix
/// against the REST API factory to guarantee the API path also honors
/// the decoded bitmap when individual boolean flags are absent.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('AccountOnNetwork.fromApiResponse / codeMetadata', () {
    /// erd1 address with valid bech32 — taken from the SDK fixtures.
    const String contractBech32 =
        'erd1qqqqqqqqqqqqqpgqvc7gdl0p4s97guh498wgz75k8sav6sjfjlwqh679jy';

    test('decodes upgradeable+readable bitmap (0x05 0x00)', () {
      /// Byte 0 = 0x05 (Upgradeable 0x01 | Readable 0x04)
      /// Byte 1 = 0x00
      final String encoded = base64.encode(
        Uint8List.fromList(<int>[0x05, 0x00]),
      );

      final AccountOnNetwork account = AccountOnNetwork.fromApiResponse(
        <String, dynamic>{
          'address': contractBech32,
          'nonce': 0,
          'balance': '0',
          'codeMetadata': encoded,
        },
      );

      expect(account.isUpgradeable, isTrue);
      expect(account.isReadable, isTrue);
      expect(account.isPayable, isFalse);
      expect(account.isPayableBySmartContract, isFalse);
      expect(account.codeMetadata, encoded);
    });

    test('decodes upgradeable+readable+payable-by-sc bitmap', () {
      /// Byte 0 = 0x05 (Upgradeable | Readable)
      /// Byte 1 = 0x04 (PayableBySc)
      final String encoded = base64.encode(
        Uint8List.fromList(<int>[0x05, 0x04]),
      );

      final AccountOnNetwork account = AccountOnNetwork.fromApiResponse(
        <String, dynamic>{
          'address': contractBech32,
          'nonce': 0,
          'balance': '0',
          'codeMetadata': encoded,
        },
      );

      expect(account.isUpgradeable, isTrue);
      expect(account.isReadable, isTrue);
      expect(account.isPayable, isFalse);
      expect(account.isPayableBySmartContract, isTrue);
    });

    test('decodes payable-only bitmap', () {
      /// Byte 0 = 0x00, Byte 1 = 0x02 (Payable)
      final String encoded = base64.encode(
        Uint8List.fromList(<int>[0x00, 0x02]),
      );

      final AccountOnNetwork account = AccountOnNetwork.fromApiResponse(
        <String, dynamic>{
          'address': contractBech32,
          'nonce': 0,
          'balance': '0',
          'codeMetadata': encoded,
        },
      );

      expect(account.isUpgradeable, isFalse);
      expect(account.isReadable, isFalse);
      expect(account.isPayable, isTrue);
      expect(account.isPayableBySmartContract, isFalse);
    });

    test('leaves flags null when codeMetadata is absent', () {
      final AccountOnNetwork account = AccountOnNetwork.fromApiResponse(
        <String, dynamic>{
          'address': contractBech32,
          'nonce': 0,
          'balance': '0',
        },
      );

      expect(account.isUpgradeable, isNull);
      expect(account.isReadable, isNull);
      expect(account.isPayable, isNull);
      expect(account.isPayableBySmartContract, isNull);
      expect(account.codeMetadata, isNull);
    });

    test('explicit boolean flags win over decoded bitmap', () {
      /// Bitmap says upgradeable, but the API also surfaces an
      /// explicit `isUpgradeable: false`. Explicit value must win.
      final String encoded = base64.encode(
        Uint8List.fromList(<int>[0x01, 0x00]),
      );

      final AccountOnNetwork account =
          AccountOnNetwork.fromApiResponse(<String, dynamic>{
            'address': contractBech32,
            'nonce': 0,
            'balance': '0',
            'codeMetadata': encoded,
            'isUpgradeable': false,
          });

      expect(account.isUpgradeable, isFalse);
    });
  });
}
