import 'dart:typed_data';

import '../address.dart';
import '../message/message.dart';
import '../transaction/transaction.dart';

/// Account abstraction for signing transactions and messages.
/// Interface for signing transactions and messages. Implementations include Account (local signing with private key) and remote signers (hardware wallets, custodial services).
///
/// #### Example
/// ```dart
/// // Using local account
/// IAccount account = Account.fromPem(pemContent, 0);
/// final signature = await account.signTransaction(transaction);
///
/// // Verifying signature
/// final isValid = await account.verifyTransactionSignature(
///   transaction,
///   signature,
/// );
///
/// // Signing message
/// final message = Message(utf8.encode('Hello MultiversX'));
/// final messageSignature = await account.signMessage(message);
/// ```
abstract interface class IAccount {
  /// Account address.
  ///
  /// #### Returns
  /// `Address` - The blockchain address associated with this account
  Address get address;

  /// Signs raw data.
  /// Use signTransaction or signMessage for structured signing.
  ///
  /// #### Parameters
  /// - `data` - Raw bytes to sign
  ///
  /// #### Returns
  /// `Future<Uint8List>` - Ed25519 signature (64 bytes)
  ///
  /// #### Example
  /// ```dart
  /// final data = Uint8List.fromList(utf8.encode('test'));
  /// final signature = await account.sign(data);
  /// print('Signature length: ${signature.length}'); // 64 bytes
  /// ```
  Future<Uint8List> sign(Uint8List data);

  /// Signs transaction and returns signature.
  /// Transaction must have all required fields set (sender, receiver, value, gasLimit, chainID).
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to sign
  ///
  /// #### Returns
  /// `Future<Uint8List>` - Ed25519 signature (64 bytes)
  ///
  /// #### Example
  /// ```dart
  /// final tx = Transaction(
  ///   sender: account.address,
  ///   receiver: Address.fromBech32('erd1...'),
  ///   value: Balance.fromEgld(0.1),
  ///   gasLimit: 50000,
  ///   chainID: 'D',
  /// );
  /// final signature = await account.signTransaction(tx);
  /// tx.signature = Signature.fromUint8List(signature);
  /// ```
  Future<Uint8List> signTransaction(Transaction transaction);

  /// Signs multiple transactions and returns their signatures.
  /// Each transaction must have all required fields set. Transactions are signed independently in order.
  ///
  /// #### Parameters
  /// - `transactions` - List of transactions to sign
  ///
  /// #### Returns
  /// `Future<List<Uint8List>>` - List of Ed25519 signatures (64 bytes each), in same order as input
  ///
  /// #### Example
  /// ```dart
  /// final tx1 = Transaction(
  ///   nonce: Nonce(5),
  ///   sender: account.address,
  ///   receiver: Address.fromBech32('erd1...'),
  ///   value: Balance.fromEgld(0.1),
  ///   gasLimit: GasLimit(50000),
  ///   gasPrice: GasPrice(1000000000),
  ///   chainId: ChainId('D'),
  ///   version: TransactionVersion(1),
  ///   data: Uint8List(0),
  /// );
  /// final tx2 = Transaction(
  ///   nonce: Nonce(6),
  ///   sender: account.address,
  ///   receiver: Address.fromBech32('erd1...'),
  ///   value: Balance.fromEgld(0.2),
  ///   gasLimit: GasLimit(50000),
  ///   gasPrice: GasPrice(1000000000),
  ///   chainId: ChainId('D'),
  ///   version: TransactionVersion(1),
  ///   data: Uint8List(0),
  /// );
  ///
  /// // Sign batch
  /// final signatures = await account.signTransactions([tx1, tx2]);
  ///
  /// // Apply signatures
  /// final signedTx1 = tx1.copyWith(
  ///   newSignature: Signature.fromUint8List(signatures[0]),
  /// );
  /// final signedTx2 = tx2.copyWith(
  ///   newSignature: Signature.fromUint8List(signatures[1]),
  /// );
  /// ```
  Future<List<Uint8List>> signTransactions(List<Transaction> transactions);

  /// Verifies transaction signature.
  /// Validates signature matches transaction and was signed by this account.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction that was signed
  /// - `signature` - Signature to verify (64 bytes)
  ///
  /// #### Returns
  /// `Future<bool>` - True if signature is valid, false otherwise
  ///
  /// #### Example
  /// ```dart
  /// final signature = await account.signTransaction(tx);
  /// final isValid = await account.verifyTransactionSignature(tx, signature);
  /// print('Valid: $isValid'); // true
  ///
  /// // Invalid signature
  /// final fakeSignature = Uint8List(64);
  /// final isInvalid = await account.verifyTransactionSignature(tx, fakeSignature);
  /// print('Valid: $isInvalid'); // false
  /// ```
  Future<bool> verifyTransactionSignature(
    Transaction transaction,
    Uint8List signature,
  );

  /// Signs message and returns signature.
  /// Message signing for authentication and verification. Used for login, proof of ownership, etc.
  ///
  /// #### Parameters
  /// - `message` - Message to sign
  ///
  /// #### Returns
  /// `Future<Uint8List>` - Ed25519 signature (64 bytes)
  ///
  /// #### Example
  /// ```dart
  /// final message = Message(utf8.encode('Login request'));
  /// final signature = await account.signMessage(message);
  ///
  /// // Send to backend for verification
  /// final authRequest = {
  ///   'address': account.address.bech32,
  ///   'message': base64.encode(message.bytes),
  ///   'signature': hex.encode(signature),
  /// };
  /// ```
  Future<Uint8List> signMessage(Message message);

  /// Verifies message signature.
  /// Validates signature matches message and was signed by this account.
  ///
  /// #### Parameters
  /// - `message` - Message that was signed
  /// - `signature` - Signature to verify (64 bytes)
  ///
  /// #### Returns
  /// `Future<bool>` - True if signature is valid, false otherwise
  ///
  /// #### Example
  /// ```dart
  /// final message = Message(utf8.encode('Verify me'));
  /// final signature = await account.signMessage(message);
  ///
  /// // Verify signature
  /// final isValid = await account.verifyMessageSignature(message, signature);
  /// print('Valid: $isValid'); // true
  ///
  /// // Someone else's signature
  /// final otherAccount = Account.fromMnemonic(otherMnemonic, 0);
  /// final otherIsValid = await otherAccount.verifyMessageSignature(
  ///   message,
  ///   signature,
  /// );
  /// print('Valid: $otherIsValid'); // false
  /// ```
  Future<bool> verifyMessageSignature(Message message, Uint8List signature);
}
