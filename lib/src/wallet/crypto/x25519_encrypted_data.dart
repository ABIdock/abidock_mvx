/// X25519 encrypted data structure for public key encryption.
/// Stores X25519-XSalsa20-Poly1305 encrypted data with ciphertext, MAC, nonce, and identities.
import 'dart:convert';

import '../../utils/helpers.dart';

/// Encrypted data container for X25519-XSalsa20-Poly1305 encryption.
/// Stores ciphertext, MAC, nonce, and identity information for serialization.
class X25519EncryptedData {
  /// Creates X25519 encrypted data with encryption parameters and ciphertext.
  ///
  /// #### Parameters
  /// - `version` - Protocol version number
  /// - `nonce` - 24-byte XSalsa20 nonce (hex-encoded)
  /// - `cipher` - Cipher algorithm identifier
  /// - `ciphertext` - Encrypted message bytes (hex-encoded)
  /// - `mac` - Ed25519 signature for authentication (hex-encoded)
  /// - `identities` - Public keys of sender, recipient, and ephemeral key
  X25519EncryptedData({
    required this.version,
    required this.nonce,
    required this.cipher,
    required this.ciphertext,
    required this.mac,
    required this.identities,
  });

  /// Protocol version.
  final int version;

  /// 24-byte nonce for XSalsa20 (hex-encoded).
  final String nonce;

  /// Cipher algorithm identifier.
  final String cipher;

  /// Encrypted message (hex-encoded).
  final String ciphertext;

  /// Ed25519 signature for authentication (hex-encoded).
  final String mac;

  /// Public keys of all parties involved.
  final X25519Identities identities;

  /// Converts encrypted data to JSON map for serialization.
  ///
  /// #### Returns
  /// `Map<String, dynamic>` - JSON map with version, nonce, identities, and crypto fields
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'nonce': nonce,
      'identities': identities.toJson(),
      'crypto': {'ciphertext': ciphertext, 'cipher': cipher, 'mac': mac},
    };
  }

  /// Creates X25519 encrypted data from JSON map.
  ///
  /// #### Parameters
  /// - `json` - Map containing version, nonce, identities, and crypto fields
  ///
  /// #### Returns
  /// `X25519EncryptedData` - Instance with all fields populated from JSON
  ///
  /// #### Throws
  /// - `TypeError` - If JSON structure is invalid or fields have wrong types
  /// - `FormatException` - If hex-encoded strings are malformed
  factory X25519EncryptedData.fromJson(Map<String, dynamic> json) {
    final crypto = requireAs<Map<String, dynamic>>(json['crypto'], 'crypto');
    return X25519EncryptedData(
      version: requireAs<int>(json['version'], 'version'),
      nonce: requireAs<String>(json['nonce'], 'nonce'),
      cipher: requireAs<String>(crypto['cipher'], 'cipher'),
      ciphertext: requireAs<String>(crypto['ciphertext'], 'ciphertext'),
      mac: requireAs<String>(crypto['mac'], 'mac'),
      identities: X25519Identities.fromJson(
        requireAs<Map<String, dynamic>>(json['identities'], 'identities'),
      ),
    );
  }

  /// Creates X25519 encrypted data from JSON string.
  ///
  /// #### Parameters
  /// - `jsonString` - JSON string containing serialized encrypted data
  ///
  /// #### Returns
  /// `X25519EncryptedData` - Instance parsed from JSON string
  ///
  /// #### Throws
  /// - `FormatException` - If JSON string is malformed
  /// - `TypeError` - If JSON structure is invalid
  factory X25519EncryptedData.fromJsonString(String jsonString) {
    final json = requireAs<Map<String, dynamic>>(
      jsonDecode(jsonString),
      'jsonString',
    );
    return X25519EncryptedData.fromJson(json);
  }

  /// Converts encrypted data to JSON string for serialization.
  ///
  /// #### Returns
  /// `String` - JSON string representation of encrypted data
  String toJsonString() {
    return jsonEncode(toJson());
  }
}

/// Identity information for X25519 encryption with recipient, originator, and ephemeral keys.
/// Stores hex-encoded Ed25519 public keys for all parties involved in encryption.
class X25519Identities {
  /// Creates identity information with recipient, ephemeral, and originator keys.
  ///
  /// #### Parameters
  /// - `recipient` - Recipient's Ed25519 public key (hex-encoded)
  /// - `ephemeralPubKey` - Ephemeral Ed25519 public key for ECDH (hex-encoded)
  /// - `originatorPubKey` - Sender's Ed25519 public key (hex-encoded)
  X25519Identities({
    required this.recipient,
    required this.ephemeralPubKey,
    required this.originatorPubKey,
  });

  /// Recipient's Ed25519 public key (hex-encoded).
  final String recipient;

  /// Ephemeral Ed25519 public key for ECDH (hex-encoded).
  final String ephemeralPubKey;

  /// Originator's Ed25519 public key for signature (hex-encoded).
  final String originatorPubKey;

  /// Converts identities to JSON map for serialization.
  ///
  /// #### Returns
  /// `Map<String, dynamic>` - JSON map with recipient, ephemeralPubKey, and originatorPubKey fields
  Map<String, dynamic> toJson() {
    return {
      'recipient': recipient,
      'ephemeralPubKey': ephemeralPubKey,
      'originatorPubKey': originatorPubKey,
    };
  }

  /// Creates identities from JSON map.
  ///
  /// #### Parameters
  /// - `json` - Map containing recipient, ephemeralPubKey, and originatorPubKey fields
  ///
  /// #### Returns
  /// `X25519Identities` - Instance with all public keys populated from JSON
  ///
  /// #### Throws
  /// - `TypeError` - If JSON structure is invalid or fields have wrong types
  factory X25519Identities.fromJson(Map<String, dynamic> json) {
    return X25519Identities(
      recipient: requireAs<String>(json['recipient'], 'recipient'),
      ephemeralPubKey: requireAs<String>(
        json['ephemeralPubKey'],
        'ephemeralPubKey',
      ),
      originatorPubKey: requireAs<String>(
        json['originatorPubKey'],
        'originatorPubKey',
      ),
    );
  }
}
