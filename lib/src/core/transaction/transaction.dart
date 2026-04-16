/// Transaction for MultiversX blockchain.
/// Represents blockchain operations: EGLD transfers, smart contract calls, or token transfers.

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../utils/collection_utils.dart';
import '../../utils/helpers.dart';
import '../../utils/json_utils.dart';
import '../address.dart';
import '../balance.dart';
import '../nonce.dart';
import '../signature.dart';
import 'chain_id.dart';
import 'gas_models/gas_limit.dart';
import 'gas_models/gas_price.dart';
import 'transaction_computer.dart';
import 'transaction_version.dart';

/// Smart contract transaction with type-safe argument encoding.
/// Use `copyWith` to create modified versions (e.g., after signing).
///
/// #### Example
/// ```dart
/// // Manual construction
/// final tx = Transaction(
///   nonce: Nonce(5),
///   sender: Address.fromBech32('erd1...'),
///   receiver: Address.fromBech32('erd1qqqqqqqqqqqqqpgq...'),
///   value: Balance.fromEgld(0.5),
///   gasLimit: GasLimit(60000000),
///   gasPrice: GasPrice(1000000000),
///   chainId: ChainId('1'),
///   version: TransactionVersion(1),
///   data: Uint8List.fromList(utf8.encode('stake')),
///   senderUsername: 'alice.elrond',
/// );
///
/// // From JSON (API response)
/// final txFromJson = Transaction.fromJson(apiData);
///
/// // Guarded transaction (2FA)
/// final guardedTx = tx.copyWith(
///   newGuardian: guardianAddress,
///   newOptions: 0x02, // transactionOptionsTxGuarded
///   newVersion: TransactionVersion(2),
/// );
/// ```
@immutable
final class Transaction {
  /// Creates transaction.
  ///
  /// Use transaction builders or factories for easier creation.
  ///
  /// #### Parameters
  /// - `nonce` - Transaction sequence number from sender account
  /// - `sender` - Sender address
  /// - `receiver` - Receiver address (can be smart contract)
  /// - `data` - Transaction data (function call, memo, etc.) as UTF-8 bytes
  /// - `gasLimit` - Maximum gas to spend
  /// - `gasPrice` - Gas price in base units
  /// - `chainId` - Chain identifier ('1' mainnet, 'D' devnet, 'T' testnet)
  /// - `version` - Transaction version (1 or 2 for options support)
  /// - `value` - EGLD amount to send (optional, defaults to 0)
  /// - `senderUsername` - Sender herotag (optional)
  /// - `receiverUsername` - Receiver herotag (optional)
  /// - `options` - Transaction options bitmask (optional, default 0)
  /// - `signature` - Transaction signature (optional, added after signing)
  /// - `guardian` - Guardian address for 2FA (optional)
  /// - `guardianSignature` - Guardian signature for 2FA (optional)
  /// - `relayer` - Relayer address for relayed v3 (optional)
  /// - `relayerSignature` - Relayer signature (optional)
  ///
  /// #### Throws
  /// - `ArgumentError` - If required fields are invalid
  ///
  /// #### Example
  /// ```dart
  /// final tx = Transaction(
  ///   nonce: Nonce(10),
  ///   sender: myAddress,
  ///   receiver: targetAddress,
  ///   value: Balance.fromEgld(2.0),
  ///   gasLimit: GasLimit(50000),
  ///   gasPrice: GasPrice(1000000000),
  ///   chainId: ChainId('D'),
  ///   version: TransactionVersion(1),
  ///   data: Uint8List(0),
  /// );
  /// ```
  Transaction({
    required this.nonce,
    required this.sender,
    required this.receiver,
    required Uint8List data,
    required this.gasLimit,
    required this.gasPrice,
    required this.chainId,
    required this.version,
    Balance? value,
    this.senderUsername = '',
    this.receiverUsername = '',
    this.options = 0,
    this.signature = const Signature.empty(),
    this.guardian,
    this.guardianSignature = const Signature.empty(),
    this.relayer,
    this.relayerSignature = const Signature.empty(),
    List<Transaction> innerTransactions = const <Transaction>[],
  }) : _data = data,
       innerTransactions = List<Transaction>.unmodifiable(innerTransactions),
       value = value ?? Balance.zero();

  /// Creates transaction from JSON.
  ///
  /// #### Parameters
  /// - `json` - JSON map with transaction fields
  ///
  /// #### Returns
  /// `Transaction` - Parsed transaction instance
  ///
  /// #### Example
  /// ```dart
  /// final txData = {
  ///   'nonce': 5,
  ///   'sender': 'erd1...',
  ///   'receiver': 'erd1qqqqqqqqqqqqqpgq...',
  ///   'value': '1000000000000000000',
  ///   'gasLimit': 60000000,
  ///   'gasPrice': 1000000000,
  ///   'chainID': '1',
  ///   'version': 1,
  ///   'data': 'Y2xhaW1SZXdhcmRz', // base64 encoded
  /// };
  /// final tx = Transaction.fromJson(txData);
  /// ```
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return newFromPlainObject(json);
  }

  final Nonce nonce;
  final Balance value;
  final Address sender;
  final Address receiver;
  final String senderUsername;
  final String receiverUsername;
  final GasPrice gasPrice;
  final GasLimit gasLimit;
  final ChainId chainId;
  final TransactionVersion version;
  final int options;
  final Signature signature;
  final Address? guardian;
  final Signature guardianSignature;
  final Address? relayer;
  final Signature relayerSignature;

  /// Inner pre-signed transactions wrapped by a relayed-v3 outer transaction.
  /// Empty for non-relayed-v3 flows.
  final List<Transaction> innerTransactions;

  /// Transaction data (cached).
  final Uint8List _data;

  /// Gets transaction data as bytes.
  ///
  /// #### Returns
  /// `Uint8List` - Transaction data field as byte array
  ///
  /// #### Example
  /// ```dart
  /// final dataStr = utf8.decode(tx.data);
  /// print('Function: $dataStr'); // e.g., "claimRewards"
  ///
  /// // For smart contract call
  /// if (tx.data.isNotEmpty) {
  ///   final function = utf8.decode(tx.data.sublist(0, tx.data.indexOf(64))); // '@'
  ///   print('Calling: $function');
  /// }
  /// ```
  Uint8List get data => Uint8List.fromList(_data);

  /// Creates copy with optional new values.
  ///
  /// Original transaction is immutable.
  ///
  /// #### Parameters All parameters optional - provide only fields to change
  /// - `newNonce` - New nonce
  /// - `newValue` - New value
  /// - `newSender` - New sender
  /// - `newReceiver` - New receiver
  /// - `newSenderUsername` - New sender username
  /// - `newReceiverUsername` - New receiver username
  /// - `newGasPrice` - New gas price
  /// - `newGasLimit` - New gas limit
  /// - `newChainId` - New chain ID
  /// - `newVersion` - New version
  /// - `newOptions` - New options
  /// - `newSignature` - New signature (after signing)
  /// - `newGuardian` - New guardian address
  /// - `newGuardianSignature` - New guardian signature
  /// - `newRelayer` - New relayer address
  /// - `newRelayerSignature` - New relayer signature
  ///
  /// #### Returns
  /// `Transaction` - New transaction with updated fields
  ///
  /// #### Example
  /// ```dart
  /// // Add signature after signing
  /// final signature = await account.signTransaction(tx);
  /// final signedTx = tx.copyWith(
  ///   newSignature: Signature.fromUint8List(signature),
  /// );
  ///
  /// // Update nonce
  /// final txWithNewNonce = tx.copyWith(newNonce: Nonce(43));
  ///
  /// // Add guardian (enable 2FA)
  /// final guardedTx = tx.copyWith(
  ///   newGuardian: guardianAddress,
  ///   newOptions: 0x02,
  ///   newVersion: TransactionVersion(2),
  /// );
  /// ```
  Transaction copyWith({
    Nonce? newNonce,
    Balance? newValue,
    Address? newSender,
    Address? newReceiver,
    Uint8List? newData,
    String? newSenderUsername,
    String? newReceiverUsername,
    GasPrice? newGasPrice,
    GasLimit? newGasLimit,
    ChainId? newChainId,
    TransactionVersion? newVersion,
    int? newOptions,
    Signature? newSignature,
    Address? newGuardian,
    Signature? newGuardianSignature,
    Address? newRelayer,
    Signature? newRelayerSignature,
    List<Transaction>? newInnerTransactions,
  }) {
    return Transaction(
      nonce: newNonce ?? nonce,
      sender: newSender ?? sender,
      receiver: newReceiver ?? receiver,
      data: newData ?? _data,
      gasLimit: newGasLimit ?? gasLimit,
      gasPrice: newGasPrice ?? gasPrice,
      chainId: newChainId ?? chainId,
      version: newVersion ?? version,
      value: newValue ?? value,
      senderUsername: newSenderUsername ?? senderUsername,
      receiverUsername: newReceiverUsername ?? receiverUsername,
      options: newOptions ?? options,
      signature: newSignature ?? signature,
      guardian: newGuardian ?? guardian,
      guardianSignature: newGuardianSignature ?? guardianSignature,
      relayer: newRelayer ?? relayer,
      relayerSignature: newRelayerSignature ?? relayerSignature,
      innerTransactions: newInnerTransactions ?? innerTransactions,
    );
  }

  /// Converts transaction to the canonical JSON shape used for broadcast.
  ///
  /// Delegates to [TransactionComputer.toPlainObject] with `withSignature: true`
  /// so broadcast and signing share a single field-order contract.
  Map<String, dynamic> toJson() =>
      const TransactionComputer().toPlainObject(this, withSignature: true);

  /// Serializes transaction for signing.
  ///
  /// Uses TransactionComputer to serialize according to protocol.
  ///
  /// #### Returns
  /// `Uint8List` - UTF-8 encoded JSON representation for signing
  ///
  /// #### Example
  /// ```dart
  /// final bytesToSign = tx.serializeForSigning();
  /// final signature = await account.sign(bytesToSign);
  /// final signedTx = tx.copyWith(
  ///   newSignature: Signature.fromUint8List(signature),
  /// );
  /// ```
  Uint8List serializeForSigning() {
    const TransactionComputer computer = TransactionComputer();
    return computer.computeBytesForSigning(this);
  }

  @override
  String toString() {
    return 'Transaction{'
        'data: $_data, '
        'sender: ${sender.bech32}, '
        'receiver: ${receiver.bech32}, '
        'value: $value, '
        'gasLimit: $gasLimit, '
        'nonce: ${nonce.value}'
        '}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transaction &&
          runtimeType == other.runtimeType &&
          nonce == other.nonce &&
          value == other.value &&
          sender == other.sender &&
          receiver == other.receiver &&
          senderUsername == other.senderUsername &&
          receiverUsername == other.receiverUsername &&
          gasPrice == other.gasPrice &&
          gasLimit == other.gasLimit &&
          chainId == other.chainId &&
          version == other.version &&
          options == other.options &&
          signature == other.signature &&
          guardian == other.guardian &&
          guardianSignature == other.guardianSignature &&
          relayer == other.relayer &&
          relayerSignature == other.relayerSignature &&
          _listEquals(innerTransactions, other.innerTransactions) &&
          CollectionUtils.bytesEquals(_data, other._data);

  static bool _listEquals(List<Transaction> a, List<Transaction> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    nonce,
    value,
    sender,
    receiver,
    senderUsername,
    receiverUsername,
    gasPrice,
    gasLimit,
    chainId,
    version,
    options,
    signature,
    guardian,
    guardianSignature,
    relayer,
    relayerSignature,
    Object.hashAll(_data),
    Object.hashAll(innerTransactions),
  );

  /// Checks if transaction is guarded.
  ///
  ///
  /// #### Returns
  /// `bool` - True if guardian address is set and guarded option is enabled
  ///
  /// #### Example
  /// ```dart
  /// if (tx.isGuardedTransaction) {
  ///   print('Transaction requires guardian signature');
  ///   final guardianSig = await guardian.signTransaction(tx);
  ///   final guardedTx = tx.copyWith(
  ///     newGuardianSignature: Signature.fromUint8List(guardianSig),
  ///   );
  /// }
  /// ```
  bool get isGuardedTransaction {
    return guardian != null && !guardian!.isEmpty && (options & 0x02) != 0;
  }

  /// Converts transaction to sendable format for API.
  Map<String, dynamic> toSendable() {
    return toJson();
  }

  /// Creates transaction from plain JSON object.
  static Transaction newFromPlainObject(Map<String, dynamic> plain) {
    Uint8List? dataBytes;
    if (plain.containsKey('data') && plain['data'] != null) {
      dataBytes = JsonUtils.parseBytes(plain['data']);
    }

    String senderUsername = '';
    String receiverUsername = '';
    if (plain.containsKey('senderUsername') &&
        plain['senderUsername'] != null) {
      senderUsername = utf8.decode(
        base64.decode(
          requireAs<String>(plain['senderUsername'], 'senderUsername'),
        ),
      );
    }
    if (plain.containsKey('receiverUsername') &&
        plain['receiverUsername'] != null) {
      receiverUsername = utf8.decode(
        base64.decode(
          requireAs<String>(plain['receiverUsername'], 'receiverUsername'),
        ),
      );
    }

    Address? guardian;
    Address? relayer;
    if (plain.containsKey('guardian') && plain['guardian'] != null) {
      guardian = Address.fromBech32(
        requireAs<String>(plain['guardian'], 'guardian'),
      );
    }
    if (plain.containsKey('relayer') && plain['relayer'] != null) {
      relayer = Address.fromBech32(
        requireAs<String>(plain['relayer'], 'relayer'),
      );
    }

    Signature signature = const Signature.empty();
    Signature guardianSignature = const Signature.empty();
    Signature relayerSignature = const Signature.empty();
    if (plain.containsKey('signature') && plain['signature'] != null) {
      signature = Signature(requireAs<String>(plain['signature'], 'signature'));
    }
    if (plain.containsKey('guardianSignature') &&
        plain['guardianSignature'] != null) {
      guardianSignature = Signature(
        requireAs<String>(plain['guardianSignature'], 'guardianSignature'),
      );
    }
    if (plain.containsKey('relayerSignature') &&
        plain['relayerSignature'] != null) {
      relayerSignature = Signature(
        requireAs<String>(plain['relayerSignature'], 'relayerSignature'),
      );
    }

    final chainIdValue = plain['chainID'] ?? plain['chainId'];

    return Transaction(
      nonce: Nonce(JsonUtils.parseInt(plain['nonce'], 0)),
      sender: Address.fromBech32(requireAs<String>(plain['sender'], 'sender')),
      receiver: Address.fromBech32(
        requireAs<String>(plain['receiver'], 'receiver'),
      ),
      value: Balance.fromString(plain['value']?.toString() ?? '0'),
      gasLimit: GasLimit(JsonUtils.parseInt(plain['gasLimit'], 50000)),
      gasPrice: GasPrice(JsonUtils.parseInt(plain['gasPrice'], 1000000000)),
      chainId: ChainId(optionalAs<String>(chainIdValue, 'chainId') ?? '1'),
      version: TransactionVersion.validated(
        JsonUtils.parseInt(plain['version'], 1),
      ),
      data: dataBytes ?? Uint8List(0),
      senderUsername: senderUsername,
      receiverUsername: receiverUsername,
      options: JsonUtils.parseInt(plain['options'], 0),
      guardian: guardian,
      signature: signature,
      guardianSignature: guardianSignature,
      relayer: relayer,
      relayerSignature: relayerSignature,
    );
  }
}
