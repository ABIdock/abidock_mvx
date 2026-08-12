import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../address.dart';

/// Prefix for signed messages.
///
/// Canonical MultiversX message-signing prefix, kept from the pre-rebrand
/// Elrond protocol spec so signatures interop with every existing wallet,
/// ledger app and node verifier. The leading `0x17` byte is the length (23)
/// of the ASCII string `Elrond Signed Message:\n` that follows.
///
/// DO NOT change the spelling — both spaces are part of the hashed bytes, so
/// any edit produces signatures the chain rejects. The pinning test in
/// `test/core/message/message_prefix_pinning_test.dart` exists to prevent
/// silent regressions.
const String messagePrefix = '\x17Elrond Signed Message:\n';

/// Message in the MultiversX ecosystem.
/// Used for authentication, proof of ownership, or other non-transaction signatures. Messages are signed with the standard messagePrefix.
///
/// #### Example
/// ```dart
/// // Create message from text
/// final message = Message(utf8.encode('Login to dApp'));
///
/// // Sign with account
/// final signature = await account.signMessage(message);
///
/// // Verify signature
/// final isValid = await account.verifyMessageSignature(message, signature);
///
/// // For binary data
/// final binaryMessage = Message([0x01, 0x02, 0x03, 0x04]);
/// final binarySig = await account.signMessage(binaryMessage);
/// ```
@immutable
class Message {
  /// Creates message.
  /// Content can be UTF-8 encoded text or binary data.
  ///
  /// #### Parameters
  /// - `bytes` - Raw message content (text as UTF-8 or binary)
  /// - `address` - Optional signer address
  /// - `signature` - Optional signature bytes (defaults to empty)
  /// - `version` - Optional message version (defaults to `1`)
  /// - `signer` - Optional signer identifier string
  Message(
    List<int> bytes, {
    this.address,
    Uint8List? signature,
    this.version = 1,
    this.signer,
  }) : _bytes = List<int>.unmodifiable(bytes),
       signature = signature ?? Uint8List(0);

  final List<int> _bytes;

  /// Raw message bytes (unmodifiable view).
  List<int> get bytes => _bytes;

  /// Optional address of the signer, carried through pack/unpack.
  final Address? address;

  /// Signature bytes attached to the message. Defaults to an empty list
  /// when the message has not yet been signed.
  final Uint8List signature;

  /// Message envelope version carried in the packed payload. Defaults to `1`.
  final int version;

  /// Optional free-form signer identifier (e.g. wallet name).
  final String? signer;
}
