import 'package:meta/meta.dart';

/// Prefix for signed messages.
///
/// Canonical MultiversX message-signing prefix. Retained from the pre-rebrand
/// Elrond protocol spec so signatures interop with every existing wallet,
/// ledger app, node verifier, and other SDK.
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
  Message(List<int> bytes) : _bytes = List<int>.unmodifiable(bytes);

  final List<int> _bytes;

  /// Raw message bytes (unmodifiable view).
  List<int> get bytes => _bytes;
}
