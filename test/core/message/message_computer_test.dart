import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

/// Independent keccak256 of the canonical envelope, rebuilt in-process from
/// the protocol recipe so the test pins byte-exact behaviour and any drift
/// surfaces immediately.
Uint8List _expectedDigest(List<int> data) {
  const String prefix = '\x17Elrond Signed Message:\n';
  final List<int> buffer = <int>[
    ...utf8.encode(prefix),
    ...utf8.encode(data.length.toString()),
    ...data,
  ];
  return KeccakDigest(256).process(Uint8List.fromList(buffer));
}

void main() {
  const MessageComputer computer = MessageComputer();

  group('MessageComputer.computeBytesForSigning', () {
    test('produces 32-byte keccak256 digest for plain ASCII payload', () {
      final Message message = Message(utf8.encode('hello'));
      final Uint8List digest = computer.computeBytesForSigning(message);

      expect(digest.length, 32);
      expect(digest, equals(_expectedDigest(message.bytes)));
    });

    test('matches the canonical "test message" vector from the cookbook', () {
      final Message message = Message(utf8.encode('test message'));
      final Uint8List digest = computer.computeBytesForSigning(message);

      expect(digest, equals(_expectedDigest(utf8.encode('test message'))));
    });

    test('decimal length, not hex length, is folded into the digest', () {
      final List<int> tenBytes = List<int>.filled(10, 0x61);
      final Message message = Message(tenBytes);

      final Uint8List digest = computer.computeBytesForSigning(message);
      expect(digest, equals(_expectedDigest(tenBytes)));

      final Uint8List wrongIfHex = KeccakDigest(256).process(
        Uint8List.fromList(<int>[
          ...utf8.encode('\x17Elrond Signed Message:\n'),
          ...utf8.encode(tenBytes.length.toRadixString(16)),
          ...tenBytes,
        ]),
      );
      expect(digest, isNot(equals(wrongIfHex)));
    });

    test('handles empty payload', () {
      final Message empty = Message(const <int>[]);
      final Uint8List digest = computer.computeBytesForSigning(empty);

      expect(digest.length, 32);
      expect(digest, equals(_expectedDigest(const <int>[])));
    });

    test('handles binary payload with high bytes', () {
      final Uint8List binary = Uint8List.fromList(<int>[
        0x00,
        0xff,
        0x10,
        0x80,
        0xab,
      ]);
      final Message message = Message(binary);

      expect(
        computer.computeBytesForSigning(message),
        equals(_expectedDigest(binary)),
      );
    });

    test('handles large payload (UTF-8 1KB)', () {
      final String payload = 'a' * 1024;
      final Message message = Message(utf8.encode(payload));

      expect(
        computer.computeBytesForSigning(message),
        equals(_expectedDigest(utf8.encode(payload))),
      );
    });
  });

  group('MessageComputer.computeBytesForVerifying', () {
    test('matches computeBytesForSigning byte-for-byte', () {
      final Message message = Message(utf8.encode('verify-roundtrip'));

      final Uint8List signing = computer.computeBytesForSigning(message);
      final Uint8List verifying = computer.computeBytesForVerifying(message);

      expect(verifying, equals(signing));
    });
  });

  group('MessageComputer.pack/unpackMessage', () {
    test('round-trips a fully-populated message', () {
      final Address address = Address.fromBech32(
        'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
      );
      final Uint8List signature = Uint8List.fromList(
        List<int>.generate(64, (int i) => (i * 7) & 0xff),
      );
      final Message original = Message(
        utf8.encode('hello world'),
        address: address,
        signature: signature,
        version: 2,
        signer: 'xPortal',
      );

      final Map<String, dynamic> packed = computer.packMessage(original);
      expect(
        packed['message'],
        original.bytes
            .map((int b) => b.toRadixString(16).padLeft(2, '0'))
            .join(),
      );
      expect(packed['address'], address.bech32);
      expect(packed['version'], 2);
      expect(packed['signer'], 'xPortal');
      expect(packed['signature'], isA<String>());

      final Message back = computer.unpackMessage(packed);
      expect(back.bytes, equals(original.bytes));
      expect(back.address?.bech32, address.bech32);
      expect(back.signature, equals(signature));
      expect(back.version, 2);
      expect(back.signer, 'xPortal');
    });

    test('round-trips a bare bytes-only message and omits null fields', () {
      final Message original = Message(utf8.encode('plain'));

      final Map<String, dynamic> packed = computer.packMessage(original);
      expect(packed.containsKey('address'), isFalse);
      expect(packed.containsKey('signer'), isFalse);
      expect(packed.containsKey('signature'), isFalse);
      expect(packed['version'], 1);

      final Message back = computer.unpackMessage(packed);
      expect(back.bytes, equals(original.bytes));
      expect(back.address, isNull);
      expect(back.signature, isEmpty);
      expect(back.version, 1);
      expect(back.signer, isNull);
    });

    test('rejects base64 payloads by default (hex-only)', () {
      final Map<String, dynamic> packed = <String, dynamic>{
        'message': base64Encode(utf8.encode('hello world')),
        'version': 1,
      };
      expect(
        () => computer.unpackMessage(packed),
        throwsA(isA<FormatException>()),
      );
    });

    test('decodes base64 payloads when acceptBase64 is true', () {
      final List<int> raw = utf8.encode('hello world');
      final Map<String, dynamic> packed = <String, dynamic>{
        'message': base64Encode(raw),
        'version': 1,
      };
      final Message back = computer.unpackMessage(packed, acceptBase64: true);
      expect(back.bytes, equals(raw));
    });

    test('decodes hex payloads correctly in default (strict) mode', () {
      final List<int> raw = utf8.encode('hello');
      final String hex = raw
          .map((int b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final Map<String, dynamic> packed = <String, dynamic>{
        'message': hex,
        'version': 1,
      };
      final Message back = computer.unpackMessage(packed);
      expect(back.bytes, equals(raw));
    });
  });

  group('Account.signMessage', () {
    /// Deterministic 32-byte ed25519 secret used so the test does not depend
    /// on BIP-39 derivation logic.
    final Uint8List secretSeed = Uint8List.fromList(
      List<int>.generate(32, (int i) => i + 1),
    );

    test('signs the canonical envelope so signatures round-trip via '
        'verifyMessageSignature', () async {
      final UserSecretKey secretKey = UserSecretKey(secretSeed);
      final Account account = await Account.fromSecretKey(secretKey);
      final Message message = Message(utf8.encode('hello'));

      final Uint8List signature = await account.signMessage(message);
      expect(signature.length, 64);

      expect(
        await account.verifyMessageSignature(message, signature),
        isTrue,
        reason: 'Signature must verify against the canonical envelope',
      );
    });

    test(
      'raw-bytes signature (legacy non-canonical path) does NOT verify',
      () async {
        final UserSecretKey secretKey = UserSecretKey(secretSeed);
        final Account account = await Account.fromSecretKey(secretKey);
        final Message message = Message(utf8.encode('hello'));

        final Uint8List rawBytesSig = await account.sign(
          Uint8List.fromList(message.bytes),
        );
        expect(
          await account.verifyMessageSignature(message, rawBytesSig),
          isFalse,
          reason:
              'Signing raw bytes (pre-fix behaviour) must not match the '
              'canonical envelope verification.',
        );
      },
    );
  });
}
