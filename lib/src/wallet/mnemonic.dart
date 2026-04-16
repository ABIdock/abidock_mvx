/// Mnemonic phrase handling with BIP39 and BIP44 hierarchical key derivation.
/// Generates multiple accounts from single seed phrase with automatic memory zeroing.
import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39_plus/bip39_plus.dart' as bip39;
import 'package:convert/convert.dart';
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../utils/sdk_exceptions.dart';
import 'user_keys.dart';

const int mnemonicStrength = 256;
const String bip44DerivationPrefix = "m/44'/508'/0'/0'";

/// Securely zeros mnemonic bytes from memory when garbage collected.
/// CVE-WALLET-007 fix: Prevents master mnemonic recovery.
final _mnemonicFinalizer = Finalizer<Uint8List>((buffer) {
  buffer.fillRange(0, buffer.length, 0);
});

/// BIP39 mnemonic phrase for hierarchical deterministic key derivation.
/// Uses BIP44 path m/44'/508'/0'/0'/index' for MultiversX addresses with secure memory handling.
///
/// #### Example
/// ```dart
/// // Generate new mnemonic
/// final mnemonic = Mnemonic.generate();
/// final words = mnemonic.getWords();
/// // Save words securely (paper backup, password manager)
///
/// // Restore from words
/// final restored = Mnemonic.fromString(words.join(' '));
///
/// // Derive accounts
/// final account0Key = await mnemonic.deriveKey(addressIndex: 0);
/// final account1Key = await mnemonic.deriveKey(addressIndex: 1);
///
/// // Create Account instances
/// final account0 = Account.fromSecretKey(account0Key);
/// final account1 = Account.fromSecretKey(account1Key);
///
/// // Cleanup
/// mnemonic.dispose();
/// ```
class Mnemonic {
  Mnemonic._(String text) {
    _textBytes = Uint8List.fromList(utf8.encode(text));
    _mnemonicFinalizer.attach(this, _textBytes!, detach: this);
  }

  /// Generates new 24-word mnemonic phrase.
  ///
  /// #### Returns New random BIP39 mnemonic (256-bit entropy).
  ///
  /// #### Example
  /// ```dart
  /// final mnemonic = Mnemonic.generate();
  /// final words = mnemonic.getWords();
  /// print('Backup these ${words.length} words:');
  /// for (int i = 0; i < words.length; i++) {
  ///   print('${i + 1}. ${words[i]}');
  /// }
  ///
  /// // Derive first account
  /// final secretKey = await mnemonic.deriveKey(addressIndex: 0);
  /// ```
  factory Mnemonic.generate() {
    final text = bip39.generateMnemonic(strength: mnemonicStrength);
    return Mnemonic._(text);
  }

  /// Creates mnemonic from string with validation.
  ///
  /// #### Parameters
  /// - `text` - Space-separated mnemonic words (12 or 24 words)
  ///
  /// #### Returns
  /// `Mnemonic` - Validated mnemonic instance
  ///
  /// #### Throws
  /// - `MnemonicException` - If mnemonic is invalid
  ///
  /// #### Example
  /// ```dart
  /// final words = 'word1 word2 word3 ... word24';
  /// final mnemonic = Mnemonic.fromString(words);
  ///
  /// // Derive accounts
  /// for (int i = 0; i < 5; i++) {
  ///   final secretKey = await mnemonic.deriveKey(addressIndex: i);
  ///   final publicKey = await secretKey.generatePublicKey();
  ///   print('Account $i: ${publicKey.toAddress().bech32}');
  /// }
  /// ```
  factory Mnemonic.fromString(String text) {
    text = text.trim();
    assertTextIsValid(text);
    return Mnemonic._(text);
  }

  /// Creates mnemonic from entropy bytes.
  factory Mnemonic.fromEntropy(Uint8List entropy) {
    try {
      final text = bip39.entropyToMnemonic(hex.encode(entropy));
      return Mnemonic._(text);
    } catch (e) {
      throw MnemonicException('Bad mnemonic entropy: $e');
    }
  }

  Uint8List? _textBytes;
  bool _disposed = false;

  /// Reconstructs mnemonic text from bytes.
  String _getText() {
    if (_disposed) {
      throw StateError('Mnemonic has been disposed');
    }
    if (_textBytes == null) {
      throw StateError('Mnemonic bytes are null');
    }
    return utf8.decode(_textBytes!);
  }

  /// Validates mnemonic phrase without throwing exception.
  static bool isValid(String text) {
    try {
      return bip39.validateMnemonic(text);
    } catch (e) {
      return false;
    }
  }

  /// Validates mnemonic text against BIP39 standard.
  ///
  /// Checks:
  /// - Word count is valid (12, 15, 18, 21, or 24 words)
  /// - All words exist in BIP39 English wordlist
  /// - Checksum is valid
  static void assertTextIsValid(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    final validWordCounts = [12, 15, 18, 21, 24];
    if (!validWordCounts.contains(words.length)) {
      throw MnemonicException(
        'Invalid word count: ${words.length}. Must be one of: ${validWordCounts.join(", ")}',
      );
    }
    final bool isValid = bip39.validateMnemonic(text);
    if (!isValid) {
      throw const MnemonicException(
        'Invalid mnemonic: words not in BIP39 wordlist or checksum failed',
      );
    }
  }

  /// Derives secret key at address index.
  ///
  /// #### Parameters
  /// - `addressIndex` - Account index in BIP44 path (default: 0)
  /// - `password` - Optional BIP39 passphrase (default: '')
  ///
  /// #### Returns
  /// `Future<UserSecretKey>` - Secret key for the specified account index
  ///
  /// #### Example
  /// ```dart
  /// // Derive multiple accounts
  /// final key0 = await mnemonic.deriveKey(addressIndex: 0);
  /// final key1 = await mnemonic.deriveKey(addressIndex: 1);
  /// final key2 = await mnemonic.deriveKey(addressIndex: 2);
  ///
  /// // With passphrase (extra security layer)
  /// final keyWithPass = await mnemonic.deriveKey(
  ///   addressIndex: 0,
  ///   password: 'my-secure-passphrase',
  /// );
  ///
  /// // Create Account instances
  /// final account0 = Account.fromSecretKey(key0);
  /// final account1 = Account.fromSecretKey(key1);
  /// ```
  Future<UserSecretKey> deriveKey({
    int addressIndex = 0,
    String password = '',
  }) async {
    final text = _getText();
    final String normalizedText = unorm.nfkd(text);
    final String normalizedPassword = unorm.nfkd(password);
    final Uint8List seed = bip39.mnemonicToSeed(
      normalizedText,
      passphrase: normalizedPassword,
    );
    final String derivationPath = "$bip44DerivationPrefix/$addressIndex'";

    try {
      final KeyData derivationResult = await ED25519_HD_KEY.derivePath(
        derivationPath,
        seed,
      );

      final secretKey = UserSecretKey(Uint8List.fromList(derivationResult.key));

      derivationResult.key.fillRange(0, derivationResult.key.length, 0);
      derivationResult.chainCode.fillRange(
        0,
        derivationResult.chainCode.length,
        0,
      );

      return secretKey;
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
  }

  /// Gets individual words.
  List<String> getWords() => _getText().split(' ');

  /// Gets entropy bytes.
  Uint8List getEntropy() {
    final text = _getText();
    final String entropyHex = bip39.mnemonicToEntropy(text);
    return Uint8List.fromList(hex.decode(entropyHex));
  }

  /// Securely zeros mnemonic from memory.
  void dispose() {
    _mnemonicFinalizer.detach(this);
    if (_textBytes != null) {
      _textBytes!.fillRange(0, _textBytes!.length, 0);
      _textBytes = null;
    }
    _disposed = true;
  }

  @override
  String toString() {
    if (_disposed) {
      return 'Mnemonic(<disposed>)';
    }
    return 'Mnemonic(${getWords().length} words)';
  }
}
