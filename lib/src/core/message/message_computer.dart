import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:pointycastle/export.dart';

import '../address.dart';
import 'base.dart';

/// Computes the canonical byte payload that MultiversX signs and verifies for
/// arbitrary off-chain messages.
///
/// The canonical envelope is
/// `keccak256(messagePrefix + decimalLengthOfData + data)`, where
/// `messagePrefix` is the literal string `\x17Elrond Signed Message:\n`
/// (the leading byte `0x17` is the length, 23, of the ASCII text that follows)
/// and `decimalLengthOfData` is the byte length of `data` rendered as ASCII
/// decimal digits. The Ed25519 signature is computed over the resulting
/// 32-byte keccak256 digest, never over the raw message.
///
/// Wallets (xPortal, Web Wallet, Ledger app) and the chain's own verifier all
/// hash their inputs this way; a signature produced over any other envelope
/// will not verify.
///
/// #### Example
/// ```dart
/// const computer = MessageComputer();
/// final message = Message(utf8.encode('hello'));
///
/// final toSign = computer.computeBytesForSigning(message);
/// final signature = await account.sign(toSign);
///
/// final toVerify = computer.computeBytesForVerifying(message);
/// final ok = await account.publicKey.verify(toVerify, signature);
/// ```
@immutable
class MessageComputer {
  /// Creates a canonical message computer.
  const MessageComputer();

  /// Returns the bytes that must be fed into Ed25519 to produce a
  /// canonical MultiversX message signature.
  ///
  /// The output is the keccak256 digest (32 bytes) of
  /// `messagePrefix + decimalLength(data) + data`.
  ///
  /// #### Parameters
  /// - `message` - Message whose `bytes` are the raw payload to sign.
  ///
  /// #### Returns
  /// `Uint8List` - 32-byte keccak256 digest, ready for Ed25519 signing.
  Uint8List computeBytesForSigning(Message message) {
    final Uint8List data = Uint8List.fromList(message.bytes);
    final Uint8List prefix = utf8.encode(canonicalMessagePrefix);
    final Uint8List lengthAsDecimal = utf8.encode(data.length.toString());

    final BytesBuilder builder = BytesBuilder(copy: false)
      ..add(prefix)
      ..add(lengthAsDecimal)
      ..add(data);

    final KeccakDigest digest = KeccakDigest(256);
    return digest.process(builder.toBytes());
  }

  /// Returns the bytes that must be supplied to Ed25519 verification for a
  /// canonical MultiversX message signature.
  ///
  /// Signing and verifying hash the same envelope, so this returns exactly
  /// what [computeBytesForSigning] produces; it exists so verification call
  /// sites read as such.
  ///
  /// #### Parameters
  /// - `message` - Message whose signature is being verified.
  ///
  /// #### Returns
  /// `Uint8List` - 32-byte keccak256 digest used as the verification input.
  Uint8List computeBytesForVerifying(Message message) {
    return computeBytesForSigning(message);
  }

  /// Serializes a [Message] into the JSON-friendly map wallets exchange when
  /// they hand a message around for signing.
  ///
  /// The bytes payload and the signature are hex-encoded, and the address
  /// (when set) is rendered as bech32. Null/empty fields are omitted to keep
  /// the payload minimal.
  ///
  /// #### Parameters
  /// - `message` - Message to serialize.
  ///
  /// #### Returns
  /// `Map<String, dynamic>` - Packed representation of the message.
  Map<String, dynamic> packMessage(Message message) {
    final Map<String, dynamic> packed = <String, dynamic>{
      'message': _toHex(message.bytes),
      'version': message.version,
    };

    if (message.signature.isNotEmpty) {
      packed['signature'] = _toHex(message.signature);
    }

    final Address? address = message.address;
    if (address != null) {
      packed['address'] = address.bech32;
    }

    final String? signer = message.signer;
    if (signer != null && signer.isNotEmpty) {
      packed['signer'] = signer;
    }

    return packed;
  }

  /// Reconstructs a [Message] from a packed map produced by [packMessage].
  ///
  /// By default the `message` payload is decoded strictly as hex, the form
  /// [packMessage] emits. Set [acceptBase64] to `true` to opt into a base64
  /// fallback for legacy producers — when enabled the decoder tries base64
  /// first and falls back to hex. The `signature` is always hex-decoded and
  /// the `address` is parsed as bech32. Missing keys fall back to safe
  /// defaults (empty bytes, empty signature, version `1`).
  ///
  /// #### Parameters
  /// - `payload` - Packed representation of the message.
  /// - `acceptBase64` - When `true`, permit base64 `message` payloads in
  ///   addition to hex. Defaults to `false` for strict hex-only parsing.
  ///
  /// #### Returns
  /// `Message` - Reconstructed message with all available fields populated.
  ///
  /// #### Throws
  /// - `FormatException` - When the `message` field is a non-empty string
  ///   that fails to decode under the active mode.
  Message unpackMessage(
    Map<String, dynamic> payload, {
    bool acceptBase64 = false,
  }) {
    final dynamic rawMessage = payload['message'];
    final List<int> bytes = rawMessage is String && rawMessage.isNotEmpty
        ? _decodeMessageBytes(rawMessage, acceptBase64: acceptBase64)
        : const <int>[];

    final dynamic rawSignature = payload['signature'];
    final Uint8List signature =
        rawSignature is String && rawSignature.isNotEmpty
        ? _fromHex(rawSignature)
        : Uint8List(0);

    final dynamic rawAddress = payload['address'];
    final Address? address = rawAddress is String && rawAddress.isNotEmpty
        ? Address.fromBech32(rawAddress)
        : null;

    final dynamic rawVersion = payload['version'];
    final int version = rawVersion is int
        ? rawVersion
        : (rawVersion is num ? rawVersion.toInt() : 1);

    final dynamic rawSigner = payload['signer'];
    final String? signer = rawSigner is String && rawSigner.isNotEmpty
        ? rawSigner
        : null;

    return Message(
      bytes,
      address: address,
      signature: signature,
      version: version,
      signer: signer,
    );
  }

  static List<int> _decodeMessageBytes(
    String raw, {
    required bool acceptBase64,
  }) {
    if (!acceptBase64) {
      try {
        return _fromHex(raw);
      } on FormatException catch (e) {
        throw FormatException(
          'Packed message field is not valid hex: ${e.message}. '
          'Pass `acceptBase64: true` to MessageComputer.unpackMessage if the '
          'producer emits base64 payloads.',
        );
      }
    }
    try {
      return base64Decode(raw);
    } on FormatException {
      return _fromHex(raw);
    }
  }

  static String _toHex(List<int> data) {
    final StringBuffer buffer = StringBuffer();
    for (final int byte in data) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static Uint8List _fromHex(String hex) {
    final String normalized = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (normalized.isEmpty) {
      return Uint8List(0);
    }
    if (normalized.length.isOdd) {
      throw const FormatException('Hex string must have even length');
    }
    final Uint8List out = Uint8List(normalized.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      out[i] = int.parse(normalized.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}

/// Canonical message-signing prefix as defined by the MultiversX protocol.
///
/// Literally `0x17` followed by the ASCII string `Elrond Signed Message:\n`.
/// The `0x17` byte is the length (23) of the prefix string that follows it.
/// The spelling is kept from the pre-rebrand Elrond protocol, so signatures
/// interop with every existing wallet, ledger app and chain verifier; both
/// spaces are part of the hashed bytes and must not be edited.
const String canonicalMessagePrefix = '\x17Elrond Signed Message:\n';
