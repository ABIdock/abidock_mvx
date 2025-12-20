/// Extension methods for signing transactions with relayers and guardians.
import 'dart:typed_data';

import '../../core/address.dart';
import '../../core/signature.dart';
import '../../core/transaction/transaction.dart';
import '../../utils/sdk_exceptions.dart';
import '../../wallet/user_signer.dart';

/// Extension methods for signing transactions as relayer or guardian.
extension TransactionSigningExtensions on Transaction {
  /// Signs the transaction with a user signer and returns a copy with the signature.
  ///
  /// #### Parameters
  /// - `signer` - UserSigner to sign the transaction
  ///
  /// #### Returns
  /// `Transaction` - New Transaction with the signature set
  Future<Transaction> signWith(UserSigner signer) async {
    final Uint8List bytesToSign = serializeForSigning();
    final Uint8List signatureBytes = await signer.sign(bytesToSign);
    return copyWith(newSignature: Signature.fromUint8List(signatureBytes));
  }

  /// Signs the transaction as a relayer and returns a copy with the relayer signature.
  ///
  /// #### Parameters
  /// - `relayerSigner` - UserSigner of the relayer
  /// - `numberOfShards` - Number of shards in the network (default: 3)
  ///
  /// #### Returns
  /// `Transaction` - New Transaction with relayer signature set
  ///
  /// #### Throws
  /// - `Exception` - If the relayer field is not set in the transaction
  /// - `Exception` - If sender and relayer are in different shards
  Future<Transaction> signAsRelayer(
    UserSigner relayerSigner, {
    int numberOfShards = 3,
  }) async {
    if (relayer == null || relayer!.isEmpty) {
      throw const TransactionException(
        'Cannot sign as relayer: relayer address is not set in the transaction. '
        'The relayer field must be set BEFORE the user signs the transaction.',
      );
    }
    final senderShard = Address.getShardOfAddress(
      sender,
      numberOfShards: numberOfShards,
    );
    final relayerShard = Address.getShardOfAddress(
      relayer!,
      numberOfShards: numberOfShards,
    );

    if (senderShard != relayerShard) {
      throw TransactionException(
        'Cannot sign as relayer: sender and relayer must be in the same shard for Relayed V3 transactions.\n'
        'Sender address: ${sender.bech32} (shard $senderShard)\n'
        'Relayer address: ${relayer!.bech32} (shard $relayerShard)\n'
        'Relayed V3 transactions require both addresses to be in the same shard.',
      );
    }

    final Uint8List bytesToSign = serializeForSigning();
    final Uint8List signatureBytes = await relayerSigner.sign(bytesToSign);
    return copyWith(
      newRelayerSignature: Signature.fromUint8List(signatureBytes),
    );
  }

  /// Signs the transaction as a guardian and returns a copy with the guardian signature.
  ///
  /// #### Parameters
  /// - `guardianSigner` - UserSigner of the guardian
  ///
  /// #### Returns
  /// `Transaction` - New Transaction with guardian signature set
  ///
  /// #### Throws
  /// - `Exception` - If the guardian field is not set in the transaction
  Future<Transaction> signAsGuardian(UserSigner guardianSigner) async {
    if (guardian == null || guardian!.isEmpty) {
      throw const TransactionException(
        'Cannot sign as guardian: guardian address is not set in the transaction. '
        'The guardian field must be set before signing.',
      );
    }

    final Uint8List bytesToSign = serializeForSigning();
    final Uint8List signatureBytes = await guardianSigner.sign(bytesToSign);
    return copyWith(
      newGuardianSignature: Signature.fromUint8List(signatureBytes),
    );
  }

  /// Checks if the transaction is a relayed transaction (Relayed V3).
  ///
  /// #### Returns
  /// `bool` - True if the transaction has a relayer set, false otherwise
  bool get isRelayedTransaction => relayer != null && !relayer!.isEmpty;

  /// Checks if the transaction is a guarded transaction (2FA enabled).
  ///
  /// #### Returns
  /// `bool` - True if the transaction has a guardian set, false otherwise
  bool get isGuardedTransaction => guardian != null && !guardian!.isEmpty;

  /// Checks if the transaction has all required signatures.
  ///
  /// #### Returns
  /// `bool` - True if all required signatures are present, false otherwise
  bool get isFullySigned {
    if (signature.isEmpty) {
      return false;
    }
    if (isRelayedTransaction && relayerSignature.isEmpty) {
      return false;
    }
    if (isGuardedTransaction && guardianSignature.isEmpty) {
      return false;
    }

    return true;
  }

  /// Returns a list of missing signature types.
  ///
  /// #### Returns
  /// `List<String>` - List of missing signature type names
  List<String> get missingSignatures {
    final List<String> missing = <String>[];

    if (signature.isEmpty) {
      missing.add('user');
    }

    if (isRelayedTransaction && relayerSignature.isEmpty) {
      missing.add('relayer');
    }

    if (isGuardedTransaction && guardianSignature.isEmpty) {
      missing.add('guardian');
    }

    return missing;
  }
}
