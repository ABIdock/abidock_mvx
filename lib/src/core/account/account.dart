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
import '../transaction/transaction_computer.dart';
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
  /// final secretKey = UserSecretKey(seedBytes); // 32-byte Ed25519 seed
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
    try {
      final UserSecretKey secretKey = await mnemonicObj.deriveKey(
        addressIndex: addressIndex,
      );
      return await fromSecretKey(secretKey);
    } finally {
      mnemonicObj.dispose();
    }
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
    return secretKey.sign(_signingBytes(transaction));
  }

  @override
  Future<List<Uint8List>> signTransactions(
    List<Transaction> transactions,
  ) async {
    final signatures = <Uint8List>[];
    for (final transaction in transactions) {
      final signature = await secretKey.sign(_signingBytes(transaction));
      signatures.add(signature);
    }
    return signatures;
  }

  @override
  Future<bool> verifyTransactionSignature(
    Transaction transaction,
    Uint8List signature,
  ) async {
    return publicKey.verify(_signingBytes(transaction), signature);
  }

  @override
  bool get prefersHashSigning => false;

  @override
  Future<Uint8List> signAsGuardian(Transaction transaction) =>
      signTransaction(transaction);

  @override
  Future<Uint8List> signAsRelayer(Transaction outerTransaction) =>
      signTransaction(outerTransaction);

  /// Bytes to be fed into Ed25519 for this transaction. When the tx has the
  /// `hashSign` option bit set, the chain expects the signature over the
  /// Keccak-256 of the signing JSON, not the raw JSON bytes.
  static Uint8List _signingBytes(Transaction transaction) {
    const computer = TransactionComputer();
    return computer.hasOptionsSetForHashSigning(transaction)
        ? computer.computeHashForSigning(transaction)
        : computer.computeBytesForSigning(transaction);
  }

  @override
  Future<Uint8List> signMessage(Message message) async {
    const MessageComputer computer = MessageComputer();
    return secretKey.sign(computer.computeBytesForSigning(message));
  }

  @override
  Future<bool> verifyMessageSignature(
    Message message,
    Uint8List signature,
  ) async {
    const MessageComputer computer = MessageComputer();
    return publicKey.verify(
      computer.computeBytesForVerifying(message),
      signature,
    );
  }

  /// Verifies raw signature.
  Future<bool> verify(Uint8List data, Uint8List signature) async {
    return publicKey.verify(data, signature);
  }
}
