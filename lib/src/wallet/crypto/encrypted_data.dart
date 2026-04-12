/// Encrypted data structure for wallet keystore files in MultiversX format.
/// Contains ciphertext, encryption parameters, salt, and MAC for verification.
import 'derivation_params.dart';

/// Encrypted wallet data container for password-based encryption.
/// Stores ciphertext, KDF parameters, and authentication MAC in keystore format.
class EncryptedData {
  /// Creates encrypted data structure with all keystore components.
  ///
  /// #### Parameters
  /// - `id` - Unique identifier
  /// - `version` - Keystore format version
  /// - `cipher` - Cipher algorithm identifier
  /// - `ciphertext` - Encrypted data (hex-encoded)
  /// - `iv` - Initialization vector (hex-encoded)
  /// - `kdf` - Key derivation function identifier
  /// - `kdfparams` - KDF parameters
  /// - `salt` - KDF salt (hex-encoded)
  /// - `mac` - Authentication tag (hex-encoded)
  const EncryptedData({
    required this.id,
    required this.version,
    required this.cipher,
    required this.ciphertext,
    required this.iv,
    required this.kdf,
    required this.kdfparams,
    required this.salt,
    required this.mac,
  });

  /// Parses encrypted data from keystore JSON.
  ///
  /// #### Parameters
  /// - `json` - Keystore JSON object with version, id, and crypto fields
  ///
  /// #### Returns
  /// `EncryptedData` - Parsed encrypted data instance
  factory EncryptedData.fromJson(Map<String, dynamic> json) {
    if (json case {
      'version': final int version,
      'id': final String id,
      'crypto': {
        'ciphertext': final String ciphertext,
        'cipherparams': {'iv': final String iv},
        'cipher': final String cipher,
        'kdf': final String kdf,
        'kdfparams': {
          'n': final int n,
          'r': final int r,
          'p': final int p,
          'dklen': final int dklen,
          'salt': final String salt,
        },
        'mac': final String mac,
      },
    }) {
      final ScryptKeyDerivationParams params;
      try {
        params = ScryptKeyDerivationParams(n: n, r: r, p: p, dklen: dklen);
      } on ArgumentError catch (e) {
        throw FormatException('Invalid keystore KDF parameters: ${e.message}');
      }
      return EncryptedData(
        version: version,
        id: id,
        ciphertext: ciphertext,
        iv: iv,
        cipher: cipher,
        kdf: kdf,
        kdfparams: params,
        salt: salt,
        mac: mac,
      );
    }
    throw const FormatException('Invalid keystore JSON structure');
  }
  final String id;
  final int version;
  final String cipher;
  final String ciphertext;
  final String iv;
  final String kdf;
  final ScryptKeyDerivationParams kdfparams;
  final String salt;
  final String mac;

  /// Converts to keystore JSON format.
  ///
  /// #### Returns
  /// `Map<String, dynamic>` - JSON map compatible with MultiversX keystore format
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'id': id,
      'crypto': <String, Object>{
        'ciphertext': ciphertext,
        'cipherparams': <String, String>{'iv': iv},
        'cipher': cipher,
        'kdf': kdf,
        'kdfparams': <String, Object>{
          'dklen': kdfparams.dklen,
          'salt': salt,
          'n': kdfparams.n,
          'r': kdfparams.r,
          'p': kdfparams.p,
        },
        'mac': mac,
      },
    };
  }
}
