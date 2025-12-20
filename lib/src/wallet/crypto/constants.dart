/// Cryptographic constants for wallet encryption, decryption, and key derivation.
/// Defines AES-128-CTR, SHA-256, Scrypt, and X25519-XSalsa20-Poly1305 identifiers.

/// AES-128-CTR cipher algorithm identifier.
const String cipherAlgorithm = 'aes-128-ctr';

/// SHA-256 hash algorithm identifier.
const String digestAlgorithm = 'sha256';

/// Scrypt key derivation function identifier.
const String keyDerivationFunction = 'scrypt';

/// X25519-XSalsa20-Poly1305 version number.
const int pubKeyEncVersion = 1;

/// X25519-XSalsa20-Poly1305 nonce length in bytes.
const int pubKeyEncNonceLength = 24;

/// X25519-XSalsa20-Poly1305 cipher identifier.
const String pubKeyEncCipher = 'x25519-xsalsa20-poly1305';
