/// User verifier for Ed25519 signature verification of transactions and messages.
/// Validates signatures using Ed25519 public keys or addresses.
import 'dart:typed_data';

import '../core/address.dart';
import 'user_keys.dart';

/// Ed25519 signature verification for transactions, messages, and arbitrary data.
/// Provides constant-time signature validation using Ed25519 public keys.
///
/// #### Example
/// ```dart
/// // From public key
/// final verifier = UserVerifier(publicKey);
///
/// // Verify signature
/// final isValid = await verifier.verify(data, signature);
/// if (!isValid) {
///   throw Exception('Invalid signature');
/// }
/// ```
class UserVerifier {
  /// Creates verifier with public key.
  ///
  /// #### Parameters
  /// - `publicKey` - Ed25519 public key for verification
  ///
  /// #### Example
  /// ```dart
  /// final publicKey = await secretKey.generatePublicKey();
  /// final verifier = UserVerifier(publicKey);
  ///
  /// final isValid = await verifier.verify(data, signature);
  /// ```
  const UserVerifier(this.publicKey);

  /// Creates verifier from address.
  ///
  /// #### Parameters
  /// - `address` - Address containing public key bytes
  ///
  /// #### Returns
  /// `UserVerifier` - Verifier instance for this address
  ///
  /// #### Example
  /// ```dart
  /// // From bech32 address
  /// final address = Address.fromBech32('erd1...');
  /// final verifier = UserVerifier.fromAddress(address);
  ///
  /// // Verify transaction signature
  /// final txBytes = tx.serializeForSigning();
  /// final isValid = await verifier.verify(txBytes, tx.signature.bytes);
  ///
  /// if (isValid) {
  ///   print('Transaction signed by ${address.bech32}');
  /// }
  /// ```
  factory UserVerifier.fromAddress(Address address) {
    final publicKey = UserPublicKey(Uint8List.fromList(address.bytes));
    return UserVerifier(publicKey);
  }
  final UserPublicKey publicKey;

  /// Verifies signature against data.
  ///
  /// #### Parameters
  /// - `data` - Original data that was signed
  /// - `signature` - 64-byte Ed25519 signature to verify
  ///
  /// #### Returns
  /// `Future<bool>` - True if signature is valid, false otherwise
  ///
  /// #### Example
  /// ```dart
  /// // Verify transaction
  /// final txBytes = tx.serializeForSigning();
  /// final isValid = await verifier.verify(
  ///   txBytes,
  ///   Uint8List.fromList(tx.signature.bytes),
  /// );
  ///
  /// // Verify message
  /// final message = Message(utf8.encode('Hello'));
  /// final msgBytes = const MessageComputer().computeBytesForVerifying(message);
  /// final valid = await verifier.verify(msgBytes, signature);
  ///
  /// // Authentication check
  /// if (!await verifier.verify(data, sig)) {
  ///   throw Exception('Authentication failed');
  /// }
  /// ```
  Future<bool> verify(Uint8List data, Uint8List signature) async {
    return publicKey.verify(data, signature);
  }
}
