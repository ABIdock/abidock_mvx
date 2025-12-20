import 'package:meta/meta.dart';

/// Prefix for signed messages.
/// Standard prefix for the MultiversX message signing protocol. The `\x17` byte (23 decimal) indicates the length of "MultiversX Signed Message:".

const String messagePrefix = '\x17MultiversX Signed Message:\n';

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
  const Message(this.bytes);

  /// Raw message bytes.
  /// Message content as list of bytes.
  final List<int> bytes;
}
