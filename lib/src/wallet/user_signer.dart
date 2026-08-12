/// User signer for transaction signing with Ed25519.
///
/// High-level interface for signing transactions and messages using
/// Ed25519 private keys with convenient loading from PEM or encrypted wallets.
import 'dart:convert';
import 'dart:typed_data';

import '../core/address.dart';
import '../utils/helpers.dart';
import '../utils/sdk_exceptions.dart';
import 'mnemonic.dart';
import 'user_keys.dart';
import 'user_wallet.dart';

/// Signs transactions and messages using Ed25519 private keys.
///
/// #### Example
/// ```dart
/// // Create from existing key
/// final signer = UserSigner(mySecretKey);
///
/// // Sign transaction
/// final txBytes = transaction.serializeForSigning();
/// final signature = await signer.sign(txBytes);
///
/// // Sign message
/// final message = Message(utf8.encode('Hello'));
/// final msgBytes = const MessageComputer().computeBytesForSigning(message);
/// final msgSignature = await signer.sign(msgBytes);
///
/// // Get address
/// final address = await signer.getAddress();
/// ```
class UserSigner {
  /// Creates signer with secret key.
  ///
  /// #### Parameters
  /// - `secretKey` - Ed25519 secret key for signing
  ///
  /// #### Example
  /// ```dart
  /// final secretKey = UserSecretKey.generate();
  /// final signer = UserSigner(secretKey);
  ///
  /// final address = await signer.getAddress();
  /// print('Address: ${address.bech32}');
  /// ```
  const UserSigner(this.secretKey);

  /// Creates signer from PEM file.
  ///
  /// #### Parameters
  /// - `text` - PEM file content
  /// - `index` - Key index if PEM contains multiple keys (default: 0)
  ///
  /// #### Returns
  /// `UserSigner` - Signer with key at specified index
  ///
  /// #### Throws
  /// - `PemException` - If PEM is invalid or index out of bounds
  ///
  /// #### Example
  /// ```dart
  /// // Load from file
  /// final pemContent = await File('wallet.pem').readAsString();
  /// final signer = UserSigner.fromPem(pemContent);
  ///
  /// // Multiple keys in one PEM
  /// final signer0 = UserSigner.fromPem(pemContent, index: 0);
  /// final signer1 = UserSigner.fromPem(pemContent, index: 1);
  ///
  /// // Sign transaction
  /// final signature = await signer.sign(txBytes);
  /// ```
  factory UserSigner.fromPem(String text, {int index = 0}) {
    final secretKey = UserSecretKey.fromPem(text, index: index);
    return UserSigner(secretKey);
  }

  /// Secret key used for signing.
  final UserSecretKey secretKey;

  /// Creates signer from secret key.
  ///
  /// #### Parameters
  /// - `secretKey` - UserSecretKey instance
  ///
  /// #### Returns
  /// `UserSigner` - Signer instance
  ///
  /// #### Example
  /// ```dart
  /// final secretKey = UserSecretKey(seedBytes); // 32-byte Ed25519 seed
  /// final signer = UserSigner.fromSecretKey(secretKey);
  /// ```
  factory UserSigner.fromSecretKey(UserSecretKey secretKey) {
    return UserSigner(secretKey);
  }

  /// Creates signer from mnemonic phrase.
  ///
  /// #### Parameters
  /// - `mnemonic` - BIP39 mnemonic phrase (12/24 words)
  /// - `addressIndex` - Derivation index (default: 0)
  ///
  /// #### Returns
  /// `Future<UserSigner>` - Signer instance
  ///
  /// #### Example
  /// ```dart
  /// final signer = await UserSigner.fromMnemonic(
  ///   'word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12',
  ///   addressIndex: 0,
  /// );
  /// ```
  static Future<UserSigner> fromMnemonic(
    String mnemonic, {
    int addressIndex = 0,
  }) async {
    final Mnemonic mnemonicObj = Mnemonic.fromString(mnemonic);
    try {
      final UserSecretKey secretKey = await mnemonicObj.deriveKey(
        addressIndex: addressIndex,
      );
      return UserSigner.fromSecretKey(secretKey);
    } finally {
      mnemonicObj.dispose();
    }
  }

  /// Creates signer from keystore file.
  ///
  /// #### Parameters
  /// - `keystoreJson` - JSON keystore content
  /// - `password` - Keystore password
  /// - `addressIndex` - Optional address index for multi-account keystores
  ///
  /// #### Returns
  /// `Future<UserSigner>` - Signer instance
  ///
  /// #### Throws
  /// - `Exception` - If password is incorrect or keystore is invalid
  ///
  /// #### Example
  /// ```dart
  /// final keystoreJson = File('keystore.json').readAsStringSync();
  /// final signer = await UserSigner.fromKeystore(keystoreJson, 'password123');
  /// ```
  static Future<UserSigner> fromKeystore(
    String keystoreJson,
    String password, {
    int? addressIndex,
  }) async {
    final Map<String, dynamic> keyFileObject = requireAs<Map<String, dynamic>>(
      jsonDecode(keystoreJson),
      'keystoreJson',
    );
    final UserSecretKey secretKey = await UserWallet.decrypt(
      keyFileObject,
      password,
      addressIndex: addressIndex,
    );
    return UserSigner.fromSecretKey(secretKey);
  }

  /// Signs data and returns Ed25519 signature.
  ///
  /// #### Parameters
  /// - `data` - Data to sign (transaction bytes, message bytes, etc.)
  ///
  /// #### Returns
  /// `Uint8List` - 64-byte Ed25519 signature
  ///
  /// #### Throws
  /// - `SignerException` - If signing fails
  ///
  /// #### Example
  /// ```dart
  /// // Sign transaction
  /// final txBytes = tx.serializeForSigning();
  /// final signature = await signer.sign(txBytes);
  /// final signedTx = tx.copyWith(
  ///   newSignature: Signature.fromUint8List(signature),
  /// );
  ///
  /// // Sign message
  /// final message = Message(utf8.encode('Hello World'));
  /// final msgBytes = const MessageComputer().computeBytesForSigning(message);
  /// final msgSignature = await signer.sign(msgBytes);
  ///
  /// // Sign arbitrary data
  /// final data = utf8.encode('custom data');
  /// final sig = await signer.sign(Uint8List.fromList(data));
  /// ```
  Future<Uint8List> sign(Uint8List data) async {
    try {
      return await secretKey.sign(data);
    } catch (e) {
      throw SignerException('Cannot sign', cause: e);
    }
  }

  /// Gets address corresponding to public key.
  ///
  /// #### Parameters
  /// - `hrp` - Human-readable part for bech32 address (optional, default: 'erd')
  ///
  /// #### Returns
  /// `Address` - Address derived from this signer's public key
  ///
  /// #### Example
  /// ```dart
  /// // Default mainnet address
  /// final address = await signer.getAddress();
  /// print('Address: ${address.bech32}'); // erd1...
  ///
  /// // Custom HRP
  /// final testnetAddr = await signer.getAddress(hrp: 'erd');
  ///
  /// // Use for account info
  /// final accountInfo = await provider.getAccount(address);
  /// print('Balance: ${accountInfo.balance.value}');
  /// ```
  Future<Address> getAddress({String? hrp}) async {
    return (await secretKey.generatePublicKey()).toAddress(hrp: hrp);
  }
}
