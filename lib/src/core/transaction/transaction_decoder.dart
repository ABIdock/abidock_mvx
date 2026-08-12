import 'dart:convert';
import 'dart:typed_data';

import '../address.dart';
import '../balance.dart';
import 'transaction.dart';

/// Decoded interpretation of a [Transaction]'s `data` field.
///
/// MultiversX encodes high-level intent into the `data` field: native EGLD
/// memos, ESDT/NFT/MetaESDT transfers use built-in function names, and
/// contract calls use `<function>@<argHex>...`. `DecodedTransaction`
/// flattens this into a sealed hierarchy so you can pattern-match on the
/// result instead of re-parsing data strings.
///
/// Produced by [TransactionDecoder.decode].
sealed class DecodedTransaction {
  const DecodedTransaction({required this.transaction});

  /// The source transaction this decoding describes.
  final Transaction transaction;

  /// Sender of the outer transaction.
  Address get sender => transaction.sender;

  /// Receiver of the outer transaction.
  Address get receiver => transaction.receiver;

  /// Raw `data` bytes (unchanged from the source transaction).
  Uint8List get dataBytes => transaction.data;
}

/// Native EGLD transfer — no ESDT, no contract call.
///
/// The `data` field is either empty or contains a free-form UTF-8 memo.
final class NativeEgldTransfer extends DecodedTransaction {
  const NativeEgldTransfer({required super.transaction, this.memo});

  /// Optional memo decoded from the data field.
  final String? memo;

  /// EGLD amount being transferred.
  Balance get value => transaction.value;
}

/// Single ESDT (fungible) transfer via the built-in `ESDTTransfer` function.
final class EsdtTransfer extends DecodedTransaction {
  const EsdtTransfer({
    required super.transaction,
    required this.tokenIdentifier,
    required this.amount,
    this.functionCall,
  });

  final String tokenIdentifier;
  final BigInt amount;

  /// Inner contract call embedded after the transfer, if any.
  /// For plain ESDT transfers this is `null`.
  final DecodedContractCall? functionCall;
}

/// Single NFT / SFT / MetaESDT transfer via `ESDTNFTTransfer`.
final class NftTransfer extends DecodedTransaction {
  const NftTransfer({
    required super.transaction,
    required this.collection,
    required this.nonce,
    required this.amount,
    required this.destination,
    this.functionCall,
  });

  final String collection;
  final int nonce;
  final BigInt amount;

  /// The actual recipient (NFT transfers are self-addressed — the outer
  /// `receiver` equals the sender, with the true destination embedded in
  /// the data field).
  final Address destination;

  /// Inner contract call embedded after the transfer, if any.
  final DecodedContractCall? functionCall;
}

/// Multiple ESDT/NFT/MetaESDT transfers in one call via `MultiESDTNFTTransfer`.
final class MultiTransfer extends DecodedTransaction {
  const MultiTransfer({
    required super.transaction,
    required this.destination,
    required this.transfers,
    this.functionCall,
  });

  /// The actual recipient.
  final Address destination;

  /// Transfers bundled in the call.
  final List<MultiTransferItem> transfers;

  /// Inner contract call embedded after the transfers, if any.
  final DecodedContractCall? functionCall;
}

/// A single leg of a `MultiESDTNFTTransfer`.
class MultiTransferItem {
  const MultiTransferItem({
    required this.tokenIdentifier,
    required this.nonce,
    required this.amount,
  });

  final String tokenIdentifier;
  final int nonce;
  final BigInt amount;

  /// Whether this leg is a plain fungible transfer (nonce == 0).
  bool get isFungible => nonce == 0;
}

/// A plain contract call (no token transfer prefix).
final class ContractCall extends DecodedTransaction {
  const ContractCall({required super.transaction, required this.call});

  final DecodedContractCall call;
}

/// A contract deployment (receiver is the zero address, data starts with
/// the WASM bytecode, then VM type, then code metadata, then constructor args).
final class ContractDeploy extends DecodedTransaction {
  const ContractDeploy({
    required super.transaction,
    required this.bytecode,
    required this.vmType,
    required this.codeMetadata,
    required this.arguments,
  });

  final Uint8List bytecode;
  final Uint8List vmType;
  final Uint8List codeMetadata;
  final List<Uint8List> arguments;
}

/// An `upgradeContract@...` call.
final class ContractUpgrade extends DecodedTransaction {
  const ContractUpgrade({
    required super.transaction,
    required this.bytecode,
    required this.codeMetadata,
    required this.arguments,
  });

  final Uint8List bytecode;
  final Uint8List codeMetadata;
  final List<Uint8List> arguments;
}

/// A `ChangeOwnerAddress@<newOwner>` call.
final class ContractChangeOwner extends DecodedTransaction {
  const ContractChangeOwner({
    required super.transaction,
    required this.newOwner,
  });

  final Address newOwner;
}

/// A `ClaimDeveloperRewards` call.
final class ClaimDeveloperRewards extends DecodedTransaction {
  const ClaimDeveloperRewards({required super.transaction});
}

/// The data-field-level view of `<function>@<argHex>...`.
class DecodedContractCall {
  const DecodedContractCall({required this.function, required this.arguments});

  /// Called function name.
  final String function;

  /// Raw argument bytes (hex-decoded from the `@`-delimited segments).
  final List<Uint8List> arguments;
}

/// Fallback when the data field is not recognized as any known pattern.
final class UnknownTransaction extends DecodedTransaction {
  const UnknownTransaction({required super.transaction, this.reason});

  /// Optional explanation (e.g. "malformed argument at index 2").
  final String? reason;
}

/// Parser that turns a [Transaction] into a typed [DecodedTransaction].
///
/// This is a pure, stateless decoder — no network round-trips, no ABI. For
/// full typed return decoding of contract calls, combine with the ABI-driven
/// `SmartContractController.query` / `call` pipeline.
///
/// #### Example
/// ```dart
/// final decoded = const TransactionDecoder().decode(tx);
/// switch (decoded) {
///   case NativeEgldTransfer(:final memo):
///     print('EGLD memo: $memo');
///   case EsdtTransfer(:final tokenIdentifier, :final amount):
///     print('$amount of $tokenIdentifier');
///   case NftTransfer(:final collection, :final nonce):
///     print('$collection #$nonce');
///   case MultiTransfer(:final transfers):
///     print('${transfers.length} tokens bundled');
///   case ContractCall(:final call):
///     print('call ${call.function}(${call.arguments.length} args)');
///   case ContractDeploy(:final bytecode):
///     print('deploy of ${bytecode.length} bytes');
///   case ContractUpgrade(:final bytecode):
///     print('upgrade to ${bytecode.length} bytes');
///   case ContractChangeOwner() || ClaimDeveloperRewards():
///     print('contract maintenance call');
///   case UnknownTransaction():
///     print('could not decode');
/// }
/// ```
class TransactionDecoder {
  /// Creates a new decoder.
  const TransactionDecoder();

  /// Decodes [transaction] into a typed [DecodedTransaction].
  ///
  /// A relayed transaction is a single flat transaction carrying a `relayer`
  /// and a `relayerSignature`, so it decodes exactly like the call it wraps.
  ///
  /// Never throws — anything unrecognized becomes [UnknownTransaction].
  DecodedTransaction decode(Transaction transaction) {
    final Uint8List data = transaction.data;
    if (data.isEmpty) {
      return NativeEgldTransfer(transaction: transaction);
    }

    final String text;
    try {
      text = utf8.decode(data);
    } catch (_) {
      return UnknownTransaction(
        transaction: transaction,
        reason: 'data field is not valid UTF-8',
      );
    }

    final List<String> parts = text.split('@');
    final String head = parts.first;

    switch (head) {
      case 'ESDTTransfer':
        return _decodeEsdtTransfer(transaction, parts);
      case 'ESDTNFTTransfer':
        return _decodeNftTransfer(transaction, parts);
      case 'MultiESDTNFTTransfer':
        return _decodeMultiTransfer(transaction, parts);
      case 'upgradeContract':
        return _decodeUpgrade(transaction, parts);
      case 'ChangeOwnerAddress':
        return _decodeChangeOwner(transaction, parts);
      case 'ClaimDeveloperRewards':
        return ClaimDeveloperRewards(transaction: transaction);
    }

    if (head.isEmpty && transaction.receiver.isZero) {
      return _decodeDeploy(transaction, parts);
    }

    if (parts.length == 1) {
      return NativeEgldTransfer(transaction: transaction, memo: text);
    }

    final DecodedContractCall? call = _decodeCall(parts);
    if (call == null) {
      return UnknownTransaction(
        transaction: transaction,
        reason: 'malformed argument list',
      );
    }
    return ContractCall(transaction: transaction, call: call);
  }

  /// Decodes an `ESDTTransfer@<tokenIdentifierHex>@<amountHex>[@<function>@<arg>...]`
  /// payload.
  DecodedTransaction _decodeEsdtTransfer(Transaction tx, List<String> parts) {
    if (parts.length < 3) {
      return UnknownTransaction(
        transaction: tx,
        reason: 'ESDTTransfer expects at least tokenIdentifier and amount',
      );
    }
    final String? token = _hexToString(parts[1]);
    final BigInt? amount = _hexToBigInt(parts[2]);
    if (token == null || amount == null) {
      return UnknownTransaction(
        transaction: tx,
        reason: 'ESDTTransfer has malformed identifier or amount',
      );
    }
    final DecodedContractCall? inner = parts.length > 3
        ? _decodeCall(parts.sublist(3))
        : null;
    return EsdtTransfer(
      transaction: tx,
      tokenIdentifier: token,
      amount: amount,
      functionCall: inner,
    );
  }

  /// Decodes an `ESDTNFTTransfer@<collectionHex>@<nonceHex>@<amountHex>@<destinationHex>[@<function>@<arg>...]`
  /// payload.
  DecodedTransaction _decodeNftTransfer(Transaction tx, List<String> parts) {
    if (parts.length < 5) {
      return UnknownTransaction(
        transaction: tx,
        reason:
            'ESDTNFTTransfer expects collection, nonce, amount, destination',
      );
    }
    final String? collection = _hexToString(parts[1]);
    final int? nonce = _hexToInt(parts[2]);
    final BigInt? amount = _hexToBigInt(parts[3]);
    final Address? dest = _hexToAddress(parts[4]);
    if (collection == null || nonce == null || amount == null || dest == null) {
      return UnknownTransaction(
        transaction: tx,
        reason: 'ESDTNFTTransfer has malformed fields',
      );
    }
    final DecodedContractCall? inner = parts.length > 5
        ? _decodeCall(parts.sublist(5))
        : null;
    return NftTransfer(
      transaction: tx,
      collection: collection,
      nonce: nonce,
      amount: amount,
      destination: dest,
      functionCall: inner,
    );
  }

  /// Decodes a `MultiESDTNFTTransfer@<destinationHex>@<countHex>@(<tokenHex>@<nonceHex>@<amountHex>)+[@<function>@<arg>...]`
  /// payload.
  DecodedTransaction _decodeMultiTransfer(Transaction tx, List<String> parts) {
    if (parts.length < 3) {
      return UnknownTransaction(
        transaction: tx,
        reason: 'MultiESDTNFTTransfer expects destination and count',
      );
    }
    final Address? dest = _hexToAddress(parts[1]);
    final int? count = _hexToInt(parts[2]);
    if (dest == null || count == null || count < 0) {
      return UnknownTransaction(
        transaction: tx,
        reason: 'MultiESDTNFTTransfer has malformed destination or count',
      );
    }

    const int firstItemIdx = 3;
    final int transferPartsNeeded = count * 3;
    if (parts.length < firstItemIdx + transferPartsNeeded) {
      return UnknownTransaction(
        transaction: tx,
        reason: 'MultiESDTNFTTransfer truncated (expected $count legs)',
      );
    }

    final List<MultiTransferItem> items = <MultiTransferItem>[];
    for (int i = 0; i < count; i++) {
      final int base = firstItemIdx + (i * 3);
      final String? token = _hexToString(parts[base]);
      final int? nonce = _hexToInt(parts[base + 1]);
      final BigInt? amount = _hexToBigInt(parts[base + 2]);
      if (token == null || nonce == null || amount == null) {
        return UnknownTransaction(
          transaction: tx,
          reason: 'MultiESDTNFTTransfer leg $i has malformed fields',
        );
      }
      items.add(
        MultiTransferItem(tokenIdentifier: token, nonce: nonce, amount: amount),
      );
    }

    final int callStart = firstItemIdx + transferPartsNeeded;
    final DecodedContractCall? inner = parts.length > callStart
        ? _decodeCall(parts.sublist(callStart))
        : null;

    return MultiTransfer(
      transaction: tx,
      destination: dest,
      transfers: items,
      functionCall: inner,
    );
  }

  DecodedTransaction _decodeDeploy(Transaction tx, List<String> parts) {
    if (parts.length < 4) {
      return UnknownTransaction(
        transaction: tx,
        reason: 'Deploy expects codeHex, vmType, metadata',
      );
    }
    final Uint8List? code = _hexToBytes(parts[1]);
    final Uint8List? vmType = _hexToBytes(parts[2]);
    final Uint8List? metadata = _hexToBytes(parts[3]);
    if (code == null || vmType == null || metadata == null) {
      return UnknownTransaction(
        transaction: tx,
        reason: 'Deploy has malformed code/vmType/metadata',
      );
    }
    final List<Uint8List> args = <Uint8List>[];
    for (int i = 4; i < parts.length; i++) {
      final Uint8List? b = _hexToBytes(parts[i]);
      if (b == null) {
        return UnknownTransaction(
          transaction: tx,
          reason: 'Deploy arg $i malformed',
        );
      }
      args.add(b);
    }
    return ContractDeploy(
      transaction: tx,
      bytecode: code,
      vmType: vmType,
      codeMetadata: metadata,
      arguments: args,
    );
  }

  DecodedTransaction _decodeUpgrade(Transaction tx, List<String> parts) {
    if (parts.length < 3) {
      return UnknownTransaction(
        transaction: tx,
        reason: 'upgradeContract expects code and metadata',
      );
    }
    final Uint8List? code = _hexToBytes(parts[1]);
    final Uint8List? metadata = _hexToBytes(parts[2]);
    if (code == null || metadata == null) {
      return UnknownTransaction(
        transaction: tx,
        reason: 'upgradeContract has malformed code or metadata',
      );
    }
    final List<Uint8List> args = <Uint8List>[];
    for (int i = 3; i < parts.length; i++) {
      final Uint8List? b = _hexToBytes(parts[i]);
      if (b == null) {
        return UnknownTransaction(
          transaction: tx,
          reason: 'upgradeContract arg $i malformed',
        );
      }
      args.add(b);
    }
    return ContractUpgrade(
      transaction: tx,
      bytecode: code,
      codeMetadata: metadata,
      arguments: args,
    );
  }

  DecodedTransaction _decodeChangeOwner(Transaction tx, List<String> parts) {
    if (parts.length != 2) {
      return UnknownTransaction(
        transaction: tx,
        reason: 'ChangeOwnerAddress expects exactly one argument',
      );
    }
    final Address? owner = _hexToAddress(parts[1]);
    if (owner == null) {
      return UnknownTransaction(
        transaction: tx,
        reason: 'ChangeOwnerAddress argument is not a 32-byte address',
      );
    }
    return ContractChangeOwner(transaction: tx, newOwner: owner);
  }

  DecodedContractCall? _decodeCall(List<String> parts) {
    if (parts.isEmpty) return null;
    final String function = parts.first;
    if (function.isEmpty) return null;
    final List<Uint8List> args = <Uint8List>[];
    for (int i = 1; i < parts.length; i++) {
      final Uint8List? bytes = _hexToBytes(parts[i]);
      if (bytes == null) return null;
      args.add(bytes);
    }
    return DecodedContractCall(function: function, arguments: args);
  }

  String? _hexToString(String hex) {
    final Uint8List? bytes = _hexToBytes(hex);
    if (bytes == null) return null;
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  int? _hexToInt(String hex) {
    if (hex.isEmpty) return 0;
    return int.tryParse(hex, radix: 16);
  }

  BigInt? _hexToBigInt(String hex) {
    if (hex.isEmpty) return BigInt.zero;
    return BigInt.tryParse(hex, radix: 16);
  }

  Address? _hexToAddress(String hex) {
    final Uint8List? bytes = _hexToBytes(hex);
    if (bytes == null || bytes.length != 32) return null;
    try {
      return Address(bytes);
    } catch (_) {
      return null;
    }
  }

  Uint8List? _hexToBytes(String hex) {
    if (hex.isEmpty) return Uint8List(0);
    if (hex.length.isOdd) return null;
    final Uint8List out = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      final int? byte = int.tryParse(
        hex.substring(i * 2, i * 2 + 2),
        radix: 16,
      );
      if (byte == null) return null;
      out[i] = byte;
    }
    return out;
  }
}
