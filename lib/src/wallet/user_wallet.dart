/// User wallet for keystore encryption and decryption with password-based security.
/// Uses Scrypt KDF and AES-128-CTR encryption, compatible with MultiversX Web Wallet and CLI.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;

import '../utils/helpers.dart';
import 'crypto/constants.dart';
import 'crypto/decryptor.dart';
import 'crypto/encrypted_data.dart';
import 'crypto/encryptor.dart';
import 'crypto/randomness.dart';
import 'mnemonic.dart';
import 'user_keys.dart';

enum UserWalletKind {
  secretKey('secretKey'),
  mnemonic('mnemonic');

  final String value;
  const UserWalletKind(this.value);

  static UserWalletKind fromString(String value) {
    return UserWalletKind.values.firstWhere(
      (UserWalletKind e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown wallet kind: $value'),
    );
  }
}

/// Encrypted wallet container for secure key storage.
/// Use static methods to create from keys or load from files.
///
/// #### Example
/// ```dart
/// // From secret key
/// final wallet = await UserWallet.fromSecretKey(
///   secretKey: mySecretKey,
///   password: 'password',
/// );
///
/// // From mnemonic
/// final wallet = UserWallet.fromMnemonic(
///   mnemonic: '24 word phrase...',
///   password: 'password',
/// );
///
/// // Save to file
/// wallet.save('wallet.json');
///
/// // Load and decrypt
/// final key = await UserWallet.loadSecretKey('wallet.json', 'password');
/// ```
class UserWallet {
  const UserWallet._({
    required this.kind,
    required this.encryptedData,
    this.publicKeyWhenKindIsSecretKey,
  });

  /// Creates encrypted wallet from secret key.
  ///
  /// #### Parameters
  /// - `secretKey` - Secret key to encrypt
  /// - `password` - Encryption password
  /// - `randomness` - Optional randomness source for testing
  ///
  /// #### Returns
  /// `Future<UserWallet>` - Encrypted wallet ready to save
  ///
  /// #### Example
  /// ```dart
  /// final secretKey = UserSecretKey.generate();
  /// final wallet = await UserWallet.fromSecretKey(
  ///   secretKey: secretKey,
  ///   password: 'MyStrongPassword123!',
  /// );
  ///
  /// // Save to file
  /// wallet.save('wallet.json', addressHrp: 'erd');
  ///
  /// // Later, load it back
  /// final loadedKey = await UserWallet.loadSecretKey(
  ///   'wallet.json',
  ///   'MyStrongPassword123!',
  /// );
  /// ```
  static Future<UserWallet> fromSecretKey({
    required UserSecretKey secretKey,
    required String password,
    Randomness? randomness,
  }) async {
    randomness ??= Randomness();

    final publicKey = await secretKey.generatePublicKey();
    final data = Uint8List.fromList([...secretKey.bytes, ...publicKey.bytes]);

    final encryptedData = Encryptor.encrypt(
      data,
      password,
      randomness: randomness,
    );

    return UserWallet._(
      kind: UserWalletKind.secretKey,
      encryptedData: encryptedData,
      publicKeyWhenKindIsSecretKey: publicKey,
    );
  }

  /// Creates encrypted wallet from mnemonic phrase.
  ///
  /// #### Parameters
  /// - `mnemonic` - BIP39 mnemonic phrase (12 or 24 words)
  /// - `password` - Encryption password
  /// - `randomness` - Optional randomness source for testing
  ///
  /// #### Returns
  /// `UserWallet` - Encrypted wallet ready to save
  ///
  /// #### Example
  /// ```dart
  /// final mnemonic = Mnemonic.generate();
  /// final words = mnemonic.getWords().join(' ');
  ///
  /// final wallet = UserWallet.fromMnemonic(
  ///   mnemonic: words,
  ///   password: 'MyStrongPassword123!',
  /// );
  ///
  /// wallet.save('mnemonic-wallet.json');
  ///
  /// // Later, load account 0
  /// final key0 = await UserWallet.loadSecretKey(
  ///   'mnemonic-wallet.json',
  ///   'MyStrongPassword123!',
  ///   addressIndex: 0,
  /// );
  ///
  /// // Load account 1
  /// final key1 = await UserWallet.loadSecretKey(
  ///   'mnemonic-wallet.json',
  ///   'MyStrongPassword123!',
  ///   addressIndex: 1,
  /// );
  /// ```
  factory UserWallet.fromMnemonic({
    required String mnemonic,
    required String password,
    Randomness? randomness,
  }) {
    randomness ??= Randomness();

    Mnemonic.assertTextIsValid(mnemonic);
    final data = Uint8List.fromList(utf8.encode(mnemonic));
    final encryptedData = Encryptor.encrypt(
      data,
      password,
      randomness: randomness,
    );

    return UserWallet._(
      kind: UserWalletKind.mnemonic,
      encryptedData: encryptedData,
    );
  }
  final UserWalletKind kind;
  final EncryptedData encryptedData;
  final UserPublicKey? publicKeyWhenKindIsSecretKey;

  /// Loads secret key from encrypted keystore file.
  ///
  /// #### Parameters
  /// - `filePath` - Path to JSON keystore file
  /// - `password` - Decryption password
  /// - `addressIndex` - Account index (required for mnemonic wallets)
  ///
  /// #### Returns
  /// `Future<UserSecretKey>` - Decrypted secret key
  ///
  /// #### Throws
  /// - `ArgumentError` - If addressIndex provided for secretKey wallet or missing for mnemonic
  /// - Exception - If password is incorrect or file is corrupted
  ///
  /// #### Example
  /// ```dart
  /// // Load from secretKey wallet
  /// final key = await UserWallet.loadSecretKey(
  ///   'wallet.json',
  ///   'password',
  /// );
  ///
  /// // Load from mnemonic wallet (account 0)
  /// final key0 = await UserWallet.loadSecretKey(
  ///   'mnemonic-wallet.json',
  ///   'password',
  ///   addressIndex: 0,
  /// );
  ///
  /// // Use in Account
  /// final account = Account.fromSecretKey(key);
  /// ```
  static Future<UserSecretKey> loadSecretKey(
    String filePath,
    String password, {
    int? addressIndex,
  }) async {
    final String resolvedPath = path.isAbsolute(filePath)
        ? filePath
        : path.join(Directory.current.path, filePath);

    final String keyFileJson = File(resolvedPath).readAsStringSync();
    final Map<String, dynamic> keyFileObject = requireAs<Map<String, dynamic>>(
      jsonDecode(keyFileJson),
      'keyFileJson',
    );

    return decrypt(keyFileObject, password, addressIndex: addressIndex);
  }

  /// Decrypts keystore file and returns secret key.
  static Future<UserSecretKey> decrypt(
    Map<String, dynamic> keyFileObject,
    String password, {
    int? addressIndex,
  }) async {
    final String kindStr =
        optionalAs<String>(keyFileObject['kind'], 'kind') ??
        UserWalletKind.secretKey.value;
    final UserWalletKind kind = UserWalletKind.fromString(kindStr);

    if (kind == UserWalletKind.secretKey) {
      if (addressIndex != null) {
        throw ArgumentError(
          'addressIndex must not be provided when kind == "secretKey"',
        );
      }
      return _decryptSecretKey(keyFileObject, password);
    }

    if (kind == UserWalletKind.mnemonic) {
      final Mnemonic mnemonic = _decryptMnemonic(keyFileObject, password);
      return mnemonic.deriveKey(addressIndex: addressIndex ?? 0);
    }

    throw ArgumentError('Unknown kind: $kindStr');
  }

  /// Decrypts secret key from keystore.
  static UserSecretKey _decryptSecretKey(
    Map<String, dynamic> keyFileObject,
    String password,
  ) {
    final String? kind = optionalAs<String>(keyFileObject['kind'], 'kind');
    if (kind != null && kind != UserWalletKind.secretKey.value) {
      throw ArgumentError(
        'Expected keystore kind to be ${UserWalletKind.secretKey.value}, but it was $kind',
      );
    }

    final EncryptedData encryptedData = EncryptedData.fromJson(keyFileObject);
    final Uint8List text = Decryptor.decrypt(encryptedData, password);
    try {
      if (text.length != 32 && text.length != 64) {
        throw FormatException(
          'Decrypted keystore payload is ${text.length} bytes; '
          'expected 32 (seed) or 64 (seed || pubkey).',
        );
      }
      return UserSecretKey(text.sublist(0, 32));
    } finally {
      text.fillRange(0, text.length, 0);
    }
  }

  /// Loads and decrypts a mnemonic-kind keystore from a file on disk.
  ///
  /// Throws `ArgumentError` when the keystore's `kind` is not `"mnemonic"`.
  /// The returned [Mnemonic] owns a zeroable internal buffer; call
  /// `Mnemonic.dispose()` when you are done.
  static Future<Mnemonic> loadMnemonic(String filePath, String password) async {
    final String resolvedPath = path.isAbsolute(filePath)
        ? filePath
        : path.join(Directory.current.path, filePath);

    final String keyFileJson = File(resolvedPath).readAsStringSync();
    final Map<String, dynamic> keyFileObject = requireAs<Map<String, dynamic>>(
      jsonDecode(keyFileJson),
      'keyFileJson',
    );
    return decryptMnemonic(keyFileObject, password);
  }

  /// Decrypts a mnemonic-kind keystore to a [Mnemonic].
  ///
  /// The [Mnemonic] internally holds the decrypted bytes wrapped in a
  /// zeroing `Finalizer`; callers should still invoke `dispose()` when
  /// they are finished for deterministic clearing.
  static Mnemonic decryptMnemonic(
    Map<String, dynamic> keyFileObject,
    String password,
  ) {
    final Uint8List bytes = decryptMnemonicBytes(keyFileObject, password);
    try {
      return Mnemonic.fromString(utf8.decode(bytes));
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  /// Decrypts a mnemonic-kind keystore to the raw UTF-8 bytes of the
  /// mnemonic phrase.
  ///
  /// Use this when integrating with external consumers (other wallet
  /// libraries, custom `Mnemonic`-like wrappers, test tooling) that need
  /// the raw bytes. **The returned buffer contains sensitive material;
  /// the caller is responsible for zeroing it via `fillRange(0, len, 0)`
  /// as soon as the bytes have been consumed.**
  ///
  /// Throws `ArgumentError` when the keystore's `kind` is not `"mnemonic"`.
  static Uint8List decryptMnemonicBytes(
    Map<String, dynamic> keyFileObject,
    String password,
  ) {
    final String? kind = optionalAs<String>(keyFileObject['kind'], 'kind');
    if (kind != UserWalletKind.mnemonic.value) {
      throw ArgumentError(
        'Expected keystore kind to be ${UserWalletKind.mnemonic.value}, but it was $kind',
      );
    }
    final EncryptedData encryptedData = EncryptedData.fromJson(keyFileObject);
    return Decryptor.decrypt(encryptedData, password);
  }

  static Mnemonic _decryptMnemonic(
    Map<String, dynamic> keyFileObject,
    String password,
  ) => decryptMnemonic(keyFileObject, password);

  /// Converts encrypted wallet to JSON.
  Map<String, dynamic> toJson({String? addressHrp}) {
    if (kind == UserWalletKind.secretKey) {
      return _toJsonWhenKindIsSecretKey(addressHrp);
    }
    return _toJsonWhenKindIsMnemonic();
  }

  Map<String, dynamic> _toJsonWhenKindIsSecretKey(String? addressHrp) {
    if (publicKeyWhenKindIsSecretKey == null) {
      throw StateError('Public key is not available');
    }

    final Map<String, dynamic> cryptoSection = _getCryptoSectionAsJson();

    return <String, dynamic>{
      'version': encryptedData.version,
      'kind': kind.value,
      'id': encryptedData.id,
      'address': publicKeyWhenKindIsSecretKey!.hex,
      'bech32': publicKeyWhenKindIsSecretKey!.toAddress(hrp: addressHrp).bech32,
      'crypto': cryptoSection,
    };
  }

  Map<String, dynamic> _toJsonWhenKindIsMnemonic() {
    final Map<String, dynamic> cryptoSection = _getCryptoSectionAsJson();

    return <String, dynamic>{
      'version': encryptedData.version,
      'id': encryptedData.id,
      'kind': kind.value,
      'crypto': cryptoSection,
    };
  }

  Map<String, dynamic> _getCryptoSectionAsJson() {
    return <String, dynamic>{
      'ciphertext': encryptedData.ciphertext,
      'cipherparams': <String, String>{'iv': encryptedData.iv},
      'cipher': cipherAlgorithm,
      'kdf': keyDerivationFunction,
      'kdfparams': <String, Object>{
        'dklen': encryptedData.kdfparams.dklen,
        'salt': encryptedData.salt,
        'n': encryptedData.kdfparams.n,
        'r': encryptedData.kdfparams.r,
        'p': encryptedData.kdfparams.p,
      },
      'mac': encryptedData.mac,
    };
  }

  /// Saves encrypted wallet to file.
  void save(String filePath, {String? addressHrp}) {
    final String resolvedPath = path.isAbsolute(filePath)
        ? filePath
        : path.join(Directory.current.path, filePath);

    final Map<String, dynamic> jsonContent = toJson(addressHrp: addressHrp);
    final String jsonString = const JsonEncoder.withIndent(
      '    ',
    ).convert(jsonContent);
    File(resolvedPath).writeAsStringSync(jsonString);
  }
}
