import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:pointycastle/export.dart';

import 'base.dart';

/// Signable message with replay protection.
/// Enhanced message class for preventing replay attacks, cross-chain attacks, and relay attacks. The message is hashed with Keccak256 along with replay protection metadata before signing.
///
/// #### Example
/// ```dart
/// // Create signable message with automatic timestamp and nonce
/// final message = SignableMessage.fromMessage(
///   'Login to dApp',
///   chainId: 'D',
///   recipient: 'erd1webapp...',
/// );
///
/// // Sign with account
/// final signature = await account.signMessage(message);
///
/// // Send to backend for verification
/// final authData = {
///   'message': message.bytes,
///   'timestamp': message.timestamp,
///   'nonce': message.nonce,
///   'chainId': message.chainId,
///   'recipient': message.recipient,
///   'signature': hex.encode(signature),
/// };
///
/// // Manual timestamp and nonce
/// final customMessage = SignableMessage.fromMessage(
///   'Custom auth',
///   timestamp: DateTime.now().millisecondsSinceEpoch,
///   nonce: 'unique-nonce-123',
///   chainId: 'D',
/// );
/// ```
@immutable
final class SignableMessage extends Message {
  /// Creates signable message.
  /// Use fromMessage which automatically computes the Keccak256 hash with replay protection metadata.
  ///
  /// #### Parameters
  /// - `bytes` - Keccak256 hash of message with metadata
  /// - `timestamp` - Message creation time (milliseconds since epoch)
  /// - `nonce` - Cryptographic nonce for uniqueness (prevents replay)
  /// - `chainId` - Chain ID (e.g., 'D' for devnet) to prevent cross-chain replay (optional)
  /// - `recipient` - Target address to prevent relay attacks (optional)
  const SignableMessage(
    super.bytes, {
    required this.timestamp,
    required this.nonce,
    this.chainId,
    this.recipient,
  });

  /// Message creation timestamp (ms since epoch).
  /// Used for replay protection - server can reject old messages.
  final int timestamp;

  /// Cryptographic nonce for uniqueness.
  /// Prevents replay attacks. Automatically generated as base64-encoded random bytes if not provided.
  final String nonce;

  /// Chain ID to prevent cross-chain replay.
  /// Prevents signature from being replayed on different chains.
  final String? chainId;

  /// Recipient address to prevent relay attacks.
  /// Prevents attacker from using signature on different recipient.
  final String? recipient;

  /// Creates signable message from string.
  /// Generates timestamp and nonce if not provided, computes Keccak256 hash with replay protection metadata, and returns ready-to-sign message.
  ///
  /// #### Parameters
  /// - `message` - Plain text message to sign
  /// - `timestamp` - Creation timestamp in milliseconds (auto-generated if null)
  /// - `nonce` - Unique nonce (auto-generated as base64 random bytes if null)
  /// - `chainId` - Chain ID for cross-chain protection (optional)
  /// - `recipient` - Target address for relay protection (optional)
  ///
  /// #### Returns
  /// `SignableMessage` - SignableMessage with Keccak256 digest ready for signing
  ///
  /// #### Example
  /// ```dart
  /// // Simple usage (auto timestamp and nonce)
  /// final message = SignableMessage.fromMessage('Login request');
  ///
  /// // With chain ID
  /// final devnetMessage = SignableMessage.fromMessage(
  ///   'Authenticate',
  ///   chainId: 'D',
  /// );
  ///
  /// // With all replay protection
  /// final secureMessage = SignableMessage.fromMessage(
  ///   'Transfer authorization',
  ///   chainId: '1',
  ///   recipient: 'erd1qqqqqqqqqqqqqpgq...',
  /// );
  ///
  /// // Custom timestamp and nonce
  /// final customMessage = SignableMessage.fromMessage(
  ///   'Custom auth',
  ///   timestamp: 1699999999000,
  ///   nonce: 'session-nonce-123',
  ///   chainId: 'D',
  /// );
  ///
  /// // Sign the message
  /// final signature = await account.signMessage(secureMessage);
  /// ```
  factory SignableMessage.fromMessage(
    final String message, {
    int? timestamp,
    String? nonce,
    String? chainId,
    String? recipient,
  }) {
    timestamp ??= DateTime.now().millisecondsSinceEpoch;
    nonce ??= _generateNonce();

    final Uint8List bytes = utf8.encode(message);
    final Uint8List messageSize = utf8.encode(message.length.toString());
    final List<int> signableMessage = <int>[...messageSize, ...bytes];

    final List<int> metadata = <int>[
      ...utf8.encode(timestamp.toString()),
      ...utf8.encode(nonce),
      if (chainId != null) ...utf8.encode(chainId),
      if (recipient != null) ...utf8.encode(recipient),
    ];

    final List<int> bytesToHash = <int>[
      ...utf8.encode(messagePrefix),
      ...signableMessage,
      ...metadata,
    ];

    final Uint8List digest = KeccakDigest(
      256,
    ).process(Uint8List.fromList(bytesToHash));

    return SignableMessage(
      digest,
      timestamp: timestamp,
      nonce: nonce,
      chainId: chainId,
      recipient: recipient,
    );
  }

  /// Generates cryptographically secure nonce.
  static String _generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }
}
