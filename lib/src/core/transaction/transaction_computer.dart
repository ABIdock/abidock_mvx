/// Transaction computer for serialization, signing, and hashing.
/// Handles different transaction versions, options, and serialization formats.
import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../../utils/hex_utils.dart';
import '../address.dart';
import '../network_configuration.dart';
import 'controllers/base_controller.dart'
    show
        extraGasLimitForGuardedTransactions,
        extraGasLimitForRelayedTransactions;
import 'proto_serializer.dart';
import 'transaction.dart';
import 'transaction_constants.dart';
import 'transaction_version.dart';

/// Utility for transaction serialization, signing, and hashing.
/// Handles protocol serialization.
///
/// #### Example
/// ```dart
/// final computer = TransactionComputer();
///
/// // Compute bytes for signing
/// final bytesToSign = computer.computeBytesForSigning(transaction);
///
/// // Compute transaction hash
/// final txHash = computer.computeTransactionHash(signedTransaction);
///
/// // Apply guardian
/// final guardedTx = computer.applyGuardian(transaction, guardianAddress);
/// ```
class TransactionComputer {
  /// Creates transaction computer.
  const TransactionComputer();

  /// Computes bytes for signing.
  /// Validates required fields before serialization.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to prepare for signing
  ///
  /// #### Returns
  /// `Uint8List` - UTF-8 encoded JSON bytes ready to be signed
  ///
  /// #### Throws
  /// - `ArgumentError` - If chainID is empty or options require version >= 2
  Uint8List computeBytesForSigning(Transaction transaction) {
    _ensureValidTransactionFields(transaction);

    final Map<String, dynamic> plainObject = toPlainObject(transaction);
    final String jsonString = jsonEncode(plainObject);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  /// Computes bytes for verifying signature.
  /// Returns Keccak256 hash for hash-signed transactions, otherwise same as signing bytes.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to verify
  ///
  /// #### Returns
  /// `Uint8List` - Bytes to verify against signature
  Uint8List computeBytesForVerifying(Transaction transaction) {
    final bool isTxSignedByHash = hasOptionsSetForHashSigning(transaction);

    if (isTxSignedByHash) {
      return computeHashForSigning(transaction);
    }

    return computeBytesForSigning(transaction);
  }

  /// Computes Keccak256 hash for hash signing transactions.
  Uint8List computeHashForSigning(Transaction transaction) {
    final Map<String, dynamic> plainObject = toPlainObject(transaction);
    final String jsonString = jsonEncode(plainObject);
    final Uint8List bytes = utf8.encode(jsonString);

    final KeccakDigest digest = KeccakDigest(256);
    return digest.process(Uint8List.fromList(bytes));
  }

  /// Computes transaction hash (transaction ID on network).
  /// Uses Protocol Buffers serialization followed by Blake2b-256 hashing.
  ///
  /// #### Parameters
  /// - `transaction` - Signed transaction
  ///
  /// #### Returns
  /// `String` - Transaction hash as lowercase hex string
  String computeTransactionHash(Transaction transaction) {
    const ProtoSerializer serializer = ProtoSerializer();
    final Uint8List serialized = serializer.serializeTransaction(transaction);

    final Blake2bDigest digest = Blake2bDigest(digestSize: 32);
    final Uint8List hash = digest.process(serialized);

    return _bytesToHex(hash);
  }

  /// Checks if transaction has guarded option set.
  bool hasOptionsSetForGuardedTransaction(Transaction transaction) {
    return (transaction.options & transactionOptionsTxGuarded) ==
        transactionOptionsTxGuarded;
  }

  /// Checks if transaction has hash signing enabled.
  bool hasOptionsSetForHashSigning(Transaction transaction) {
    return (transaction.options & transactionOptionsTxHashSign) ==
        transactionOptionsTxHashSign;
  }

  /// Applies guardian to transaction.
  /// Automatically upgrades version to 2 if needed.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to guard
  /// - `guardian` - Guardian address
  ///
  /// #### Returns
  /// `Transaction` - New transaction with guardian enabled
  Transaction applyGuardian(Transaction transaction, Address guardian) {
    if (transaction.guardian != null &&
        !transaction.guardian!.isEmpty &&
        transaction.guardian != guardian) {
      throw StateError(
        'Transaction already has a different guardian '
        '(${transaction.guardian!.bech32}); construct a fresh transaction '
        'before re-guarding.',
      );
    }

    int version = transaction.version.value;
    int options = transaction.options;

    if (version < minTransactionVersionThatSupportsOptions) {
      version = minTransactionVersionThatSupportsOptions;
    }

    options = options | transactionOptionsTxGuarded;

    return transaction.copyWith(
      newVersion: TransactionVersion(version),
      newOptions: options,
      newGuardian: guardian,
    );
  }

  /// Checks if transaction is relayed v3.
  bool isRelayedV3Transaction(Transaction transaction) {
    return transaction.relayer != null;
  }

  /// Applies hash signing options to transaction.
  /// Reduces signature size for large transactions. Automatically upgrades version to 2 if needed.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to enable hash signing for
  ///
  /// #### Returns
  /// `Transaction` - New transaction with hash signing enabled
  Transaction applyOptionsForHashSigning(Transaction transaction) {
    int version = transaction.version.value;
    int options = transaction.options;

    if (version < minTransactionVersionThatSupportsOptions) {
      version = minTransactionVersionThatSupportsOptions;
    }

    options = options | transactionOptionsTxHashSign;

    return transaction.copyWith(
      newVersion: TransactionVersion(version),
      newOptions: options,
    );
  }

  /// Converts transaction to plain map for JSON serialization.
  Map<String, dynamic> toPlainObject(
    Transaction transaction, {
    bool withSignature = false,
  }) {
    final Map<String, dynamic> map = <String, dynamic>{
      'nonce': transaction.nonce.value,
      'value': transaction.value.value.toString(),
      'receiver': transaction.receiver.bech32,
      'sender': transaction.sender.bech32,
    };

    if (transaction.senderUsername.isNotEmpty) {
      map['senderUsername'] = base64.encode(
        utf8.encode(transaction.senderUsername),
      );
    }

    if (transaction.receiverUsername.isNotEmpty) {
      map['receiverUsername'] = base64.encode(
        utf8.encode(transaction.receiverUsername),
      );
    }

    map['gasPrice'] = transaction.gasPrice.value;
    map['gasLimit'] = transaction.gasLimit.value;

    if (transaction.data.isNotEmpty) {
      map['data'] = base64.encode(transaction.data);
    }

    map['chainID'] = transaction.chainId.value;
    map['version'] = transaction.version.value;

    if (transaction.options != transactionOptionsDefault) {
      map['options'] = transaction.options;
    }

    if (transaction.guardian != null) {
      map['guardian'] = transaction.guardian!.bech32;
    }

    if (transaction.relayer != null) {
      map['relayer'] = transaction.relayer!.bech32;
    }

    if (withSignature && transaction.signature.isNotEmpty) {
      map['signature'] = transaction.signature.hex;
    }

    if (withSignature &&
        transaction.guardian != null &&
        transaction.guardianSignature.isNotEmpty) {
      map['guardianSignature'] = transaction.guardianSignature.hex;
    }

    if (withSignature &&
        transaction.relayer != null &&
        transaction.relayerSignature.isNotEmpty) {
      map['relayerSignature'] = transaction.relayerSignature.hex;
    }

    if (transaction.innerTransactions.isNotEmpty) {
      map['innerTransactions'] = transaction.innerTransactions
          .map(
            (Transaction inner) =>
                toPlainObject(inner, withSignature: withSignature),
          )
          .toList();
    }

    return map;
  }

  /// Validates required transaction fields.
  void _ensureValidTransactionFields(Transaction transaction) {
    if (transaction.chainId.value.isEmpty) {
      throw ArgumentError('The `chainID` field is not set');
    }

    if (transaction.version.value < minTransactionVersionThatSupportsOptions) {
      if (hasOptionsSetForGuardedTransaction(transaction) ||
          hasOptionsSetForHashSigning(transaction)) {
        throw ArgumentError(
          'Non-empty transaction options requires transaction version >= $minTransactionVersionThatSupportsOptions',
        );
      }
      if (transaction.relayer != null && !transaction.relayer!.isEmpty) {
        throw ArgumentError(
          'Relayed v3 transactions require transaction version >= $minTransactionVersionThatSupportsOptions',
        );
      }
    }

    const int knownOptionBits =
        transactionOptionsTxHashSign | transactionOptionsTxGuarded;
    if ((transaction.options & ~knownOptionBits) != 0) {
      throw ArgumentError(
        'Unknown transaction option bits: '
        '0x${(transaction.options & ~knownOptionBits).toRadixString(16)}',
      );
    }

    if (transaction.guardian != null &&
        !transaction.guardian!.isEmpty &&
        !hasOptionsSetForGuardedTransaction(transaction)) {
      throw ArgumentError(
        'Guardian address set but transactionOptionsTxGuarded bit is not enabled',
      );
    }

    if (transaction.senderUsername.length > 32 ||
        transaction.receiverUsername.length > 32) {
      throw ArgumentError('Herotag must be <= 32 bytes');
    }
  }

  /// Converts bytes to hex string.
  String _bytesToHex(Uint8List bytes) => HexUtils.bytesToHex(bytes);

  /// Computes the transaction fee based on network configuration.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to compute fee for
  /// - `networkConfig` - Network configuration with gas parameters
  ///
  /// #### Returns
  /// `BigInt` - Transaction fee in EGLD
  ///
  /// #### Throws
  /// - `ArgumentError` - If gas limit is less than minimum required
  ///
  /// #### Example
  /// ```dart
  /// final computer = TransactionComputer();
  /// final config = NetworkConfiguration.mainnet();
  /// final fee = computer.computeTransactionFee(transaction, config);
  /// print('Fee: ${Balance(fee).toDenominatedTrimmed} EGLD');
  /// ```
  BigInt computeTransactionFee(
    Transaction transaction,
    NetworkConfiguration networkConfig,
  ) {
    final int dataLength = transaction.data.length;
    BigInt moveBalanceGas =
        networkConfig.minGasLimit.toBigInt +
        BigInt.from(dataLength) * BigInt.from(networkConfig.gasPerDataByte);

    if (hasOptionsSetForGuardedTransaction(transaction)) {
      moveBalanceGas += BigInt.from(extraGasLimitForGuardedTransactions);
    }
    if (isRelayedV3Transaction(transaction)) {
      moveBalanceGas += BigInt.from(extraGasLimitForRelayedTransactions);
    }

    if (transaction.gasLimit.toBigInt < moveBalanceGas) {
      throw ArgumentError(
        'Gas limit (${transaction.gasLimit.value}) is less than minimum required ($moveBalanceGas)',
      );
    }

    final BigInt gasPrice = transaction.gasPrice.toBigInt;
    final BigInt feeForMove = moveBalanceGas * gasPrice;

    if (transaction.gasLimit.toBigInt == moveBalanceGas) {
      return feeForMove;
    }

    final BigInt processingGas = transaction.gasLimit.toBigInt - moveBalanceGas;
    const int denominator = 10000;
    final int numerator = (networkConfig.gasPriceModifier.value * denominator)
        .round();
    final BigInt feeForProcessing =
        processingGas *
        gasPrice *
        BigInt.from(numerator) ~/
        BigInt.from(denominator);

    return feeForMove + feeForProcessing;
  }
}
