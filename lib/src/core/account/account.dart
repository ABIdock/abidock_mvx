import 'dart:convert';
import 'dart:typed_data';

import '../../utils/helpers.dart';
import '../../wallet/mnemonic.dart';
import '../../wallet/user_keys.dart';
import '../../wallet/user_wallet.dart';
import '../address.dart';
import '../message/message.dart';
import '../nonce.dart';
import '../transaction/transaction.dart';
import 'account_interface.dart';

/// Account on the network with local signing.
/// Can be created from PEM, mnemonic, keystore, or secret key. Implements IAccount interface for signing transactions and messages.
///
/// #### Example
/// ```dart
/// // From mnemonic
/// final account = await Account.fromMnemonic(
///   'word1 word2 word3 ...',
///   addressIndex: 0,
/// );
///
/// // From PEM
/// final account2 = await Account.fromPem(pemContent);
///
/// // Sign transaction
/// final signature = await account.signTransaction(tx);
///
/// // Nonce management
/// final currentNonce = account.getNonceThenIncrement();
/// ```
class Account implements IAccount {
  /// Creates account from PEM string.
  ///
  /// #### Parameters
  /// - `pemContent` - PEM formatted private key string
  /// - `index` - Key index in PEM (default: 0)
  ///
  /// #### Returns
  /// `Future<Account>` - Account instance
  ///
  /// #### Example
  /// ```dart
  /// final pem = '-----BEGIN PRIVATE KEY-----\n...';
  /// final account = await Account.fromPem(pem);
  /// print(account.address.bech32);
  /// ```
  static Future<Account> fromPem(String pemContent, {int index = 0}) async {
    final secretKey = UserSecretKey.fromPem(pemContent, index: index);
    return fromSecretKey(secretKey);
  }

  Account._(this.secretKey, this.publicKey, this.address);

  /// Creates account from secret key.
  ///
  /// #### Parameters
  /// - `secretKey` - UserSecretKey instance
  ///
  /// #### Returns
  /// `Future<Account>` - Account instance
  ///
  /// #### Example
  /// ```dart
  /// final secretKey = UserSecretKey.fromBytes([...]);
  /// final account = await Account.fromSecretKey(secretKey);
  /// ```
  static Future<Account> fromSecretKey(UserSecretKey secretKey) async {
    final publicKey = await secretKey.generatePublicKey();
    final address = publicKey.toAddress();
    return Account._(secretKey, publicKey, address);
  }

  /// Creates account from mnemonic phrase.
  ///
  /// #### Parameters
  /// - `mnemonic` - BIP39 mnemonic phrase (12/24 words)
  /// - `addressIndex` - Derivation index (default: 0)
  ///
  /// #### Returns
  /// `Future<Account>` - Account instance
  ///
  /// #### Example
  /// ```dart
  /// final account = await Account.fromMnemonic(
  ///   'word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12',
  ///   addressIndex: 0,
  /// );
  /// ```
  static Future<Account> fromMnemonic(
    String mnemonic, {
    int addressIndex = 0,
  }) async {
    final Mnemonic mnemonicObj = Mnemonic.fromString(mnemonic);
    final UserSecretKey secretKey = await mnemonicObj.deriveKey(
      addressIndex: addressIndex,
    );
    return fromSecretKey(secretKey);
  }

  /// Creates account from keystore file.
  ///
  /// #### Parameters
  /// - `keystoreJson` - JSON keystore content
  /// - `password` - Keystore password
  /// - `addressIndex` - Optional address index for multi-account keystores
  ///
  /// #### Returns
  /// `Future<Account>` - Account instance
  ///
  /// #### Throws
  /// - `Exception` - If password is incorrect or keystore is invalid
  ///
  /// #### Example
  /// ```dart
  /// final keystoreJson = File('keystore.json').readAsStringSync();
  /// final account = await Account.fromKeystore(keystoreJson, 'password123');
  /// ```
  static Future<Account> fromKeystore(
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
    return fromSecretKey(secretKey);
  }

  /// Secret key.
  final UserSecretKey secretKey;

  /// Public key.
  final UserPublicKey publicKey;

  @override
  final Address address;

  /// Local copy of account nonce.
  Nonce nonce = const Nonce.zero();

  /// Increments nonce.
  ///
  /// #### Example
  /// ```dart
  /// account.nonce = Nonce(42);
  /// account.incrementNonce();
  /// print(account.nonce.value); // 43
  /// ```
  void incrementNonce() {
    nonce = nonce.increment();
  }

  /// Gets nonce and increments it.
  ///
  /// #### Returns
  /// `Nonce` - Current nonce value (before increment)
  ///
  /// #### Example
  /// ```dart
  /// account.nonce = Nonce(42);
  /// final nonce1 = account.getNonceThenIncrement(); // Nonce(42)
  /// final nonce2 = account.getNonceThenIncrement(); // Nonce(43)
  /// print(account.nonce.value); // 44
  /// ```
  Nonce getNonceThenIncrement() {
    final Nonce currentNonce = nonce;
    nonce = nonce.increment();
    return currentNonce;
  }

  @override
  Future<Uint8List> sign(Uint8List data) async {
    return secretKey.sign(data);
  }

  @override
  Future<Uint8List> signTransaction(Transaction transaction) async {
    final Uint8List serialized = transaction.serializeForSigning();
    return secretKey.sign(serialized);
  }

  @override
  Future<List<Uint8List>> signTransactions(
    List<Transaction> transactions,
  ) async {
    final signatures = <Uint8List>[];
    for (final transaction in transactions) {
      final Uint8List serialized = transaction.serializeForSigning();
      final signature = await secretKey.sign(serialized);
      signatures.add(signature);
    }
    return signatures;
  }

  @override
  Future<bool> verifyTransactionSignature(
    Transaction transaction,
    Uint8List signature,
  ) async {
    final Uint8List serialized = transaction.serializeForSigning();
    return publicKey.verify(serialized, signature);
  }

  @override
  Future<Uint8List> signMessage(Message message) async {
    return secretKey.sign(Uint8List.fromList(message.bytes));
  }

  @override
  Future<bool> verifyMessageSignature(
    Message message,
    Uint8List signature,
  ) async {
    return publicKey.verify(Uint8List.fromList(message.bytes), signature);
  }

  /// Verifies raw signature.
  Future<bool> verify(Uint8List data, Uint8List signature) async {
    return publicKey.verify(data, signature);
  }
}
