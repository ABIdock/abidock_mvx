/// Parser for token management transaction outcomes.
/// Extracts structured results from ESDT operations including issuance, roles, NFT operations, and control.
import 'dart:typed_data';

import '../../../utils/sdk_exceptions.dart';
import '../../address.dart';
import '../smart_contract_result.dart';
import '../transaction_event.dart';
import '../transaction_logs.dart';
import '../transaction_on_network.dart';

/// Exception for token management parsing failures.
/// Thrown when outcomes cannot be parsed due to missing events, errors, or unexpected data format.
/// Part of the unified SDK hierarchy: catch it as [TransactionException] or as
/// [AbidockException].
class TokenManagementParseException extends TransactionException {
  /// Creates token management parse exception.
  const TokenManagementParseException(super.message, [Object? cause])
    : super(cause: cause);

  @override
  String toString() {
    if (cause != null) {
      return 'TokenManagementParseException: $message\nCaused by: $cause';
    }
    return 'TokenManagementParseException: $message';
  }
}

/// Result of issuing fungible token.
/// Contains the token identifier assigned by the ESDT system contract.
class IssueFungibleResult {
  /// Creates issue fungible result.
  const IssueFungibleResult({required this.tokenIdentifier});

  final String tokenIdentifier;

  @override
  String toString() => 'IssueFungibleResult(tokenIdentifier: $tokenIdentifier)';
}

/// Result of issuing non-fungible token collection.
class IssueNonFungibleResult {
  /// Creates issue non-fungible result.
  const IssueNonFungibleResult({required this.tokenIdentifier});

  final String tokenIdentifier;

  @override
  String toString() =>
      'IssueNonFungibleResult(tokenIdentifier: $tokenIdentifier)';
}

/// Result of issuing semi-fungible token collection.
class IssueSemiFungibleResult {
  /// Creates issue semi-fungible result.
  const IssueSemiFungibleResult({required this.tokenIdentifier});

  final String tokenIdentifier;

  @override
  String toString() =>
      'IssueSemiFungibleResult(tokenIdentifier: $tokenIdentifier)';
}

/// Result of registering meta-ESDT token.
class RegisterMetaEsdtResult {
  /// Creates register meta-ESDT result.
  const RegisterMetaEsdtResult({required this.tokenIdentifier});

  final String tokenIdentifier;

  @override
  String toString() =>
      'RegisterMetaEsdtResult(tokenIdentifier: $tokenIdentifier)';
}

/// Result of register and set all roles operation.
class RegisterAndSetAllRolesResult {
  /// Creates register and set all roles result.
  const RegisterAndSetAllRolesResult({
    required this.tokenIdentifier,
    required this.roles,
  });

  final String tokenIdentifier;
  final List<String> roles;

  @override
  String toString() =>
      'RegisterAndSetAllRolesResult(tokenIdentifier: $tokenIdentifier, roles: $roles)';
}

/// Result of setting special roles.
class SetSpecialRoleResult {
  /// Creates set special role result.
  const SetSpecialRoleResult({
    required this.userAddress,
    required this.tokenIdentifier,
    required this.roles,
  });

  final Address userAddress;
  final String tokenIdentifier;
  final List<String> roles;

  @override
  String toString() =>
      'SetSpecialRoleResult(userAddress: ${userAddress.bech32}, tokenIdentifier: $tokenIdentifier, roles: $roles)';
}

/// Result of NFT creation.
class NftCreateResult {
  /// Creates NFT create result.
  const NftCreateResult({
    required this.tokenIdentifier,
    required this.nonce,
    required this.initialQuantity,
  });

  final String tokenIdentifier;
  final BigInt nonce;
  final BigInt initialQuantity;

  @override
  String toString() =>
      'NftCreateResult(tokenIdentifier: $tokenIdentifier, nonce: $nonce, initialQuantity: $initialQuantity)';
}

/// Result of local mint operation.
class LocalMintResult {
  /// Creates local mint result.
  const LocalMintResult({
    required this.userAddress,
    required this.tokenIdentifier,
    required this.nonce,
    required this.mintedSupply,
  });

  final Address userAddress;
  final String tokenIdentifier;
  final BigInt nonce;
  final BigInt mintedSupply;

  @override
  String toString() =>
      'LocalMintResult(userAddress: ${userAddress.bech32}, tokenIdentifier: $tokenIdentifier, nonce: $nonce, mintedSupply: $mintedSupply)';
}

/// Result of local burn operation.
class LocalBurnResult {
  /// Creates local burn result.
  const LocalBurnResult({
    required this.userAddress,
    required this.tokenIdentifier,
    required this.nonce,
    required this.burntSupply,
  });

  final Address userAddress;
  final String tokenIdentifier;
  final BigInt nonce;
  final BigInt burntSupply;

  @override
  String toString() =>
      'LocalBurnResult(userAddress: ${userAddress.bech32}, tokenIdentifier: $tokenIdentifier, nonce: $nonce, burntSupply: $burntSupply)';
}

/// Result of pause operation.
class PauseResult {
  /// Creates pause result.
  const PauseResult({required this.tokenIdentifier});

  final String tokenIdentifier;

  @override
  String toString() => 'PauseResult(tokenIdentifier: $tokenIdentifier)';
}

/// Result of unpause operation.
class UnpauseResult {
  /// Creates unpause result.
  const UnpauseResult({required this.tokenIdentifier});

  final String tokenIdentifier;

  @override
  String toString() => 'UnpauseResult(tokenIdentifier: $tokenIdentifier)';
}

/// Result of freeze operation.
class FreezeResult {
  /// Creates freeze result.
  const FreezeResult({
    required this.userAddress,
    required this.tokenIdentifier,
    required this.nonce,
    required this.balance,
  });

  final String userAddress;
  final String tokenIdentifier;
  final BigInt nonce;
  final BigInt balance;

  @override
  String toString() =>
      'FreezeResult(userAddress: $userAddress, tokenIdentifier: $tokenIdentifier, nonce: $nonce, balance: $balance)';
}

/// Result of unfreeze operation.
class UnfreezeResult {
  /// Creates unfreeze result.
  const UnfreezeResult({
    required this.userAddress,
    required this.tokenIdentifier,
    required this.nonce,
    required this.balance,
  });

  final String userAddress;
  final String tokenIdentifier;
  final BigInt nonce;
  final BigInt balance;

  @override
  String toString() =>
      'UnfreezeResult(userAddress: $userAddress, tokenIdentifier: $tokenIdentifier, nonce: $nonce, balance: $balance)';
}

/// Result of wipe operation.
class WipeResult {
  /// Creates wipe result.
  const WipeResult({
    required this.userAddress,
    required this.tokenIdentifier,
    required this.nonce,
    required this.balance,
  });

  final String userAddress;
  final String tokenIdentifier;
  final BigInt nonce;
  final BigInt balance;

  @override
  String toString() =>
      'WipeResult(userAddress: $userAddress, tokenIdentifier: $tokenIdentifier, nonce: $nonce, balance: $balance)';
}

/// Result of update attributes operation.
class UpdateAttributesResult {
  /// Creates an update attributes result.
  const UpdateAttributesResult({
    required this.tokenIdentifier,
    required this.nonce,
    required this.attributes,
  });

  /// The token identifier.
  final String tokenIdentifier;

  /// The nonce.
  final BigInt nonce;

  /// The new attributes.
  final Uint8List attributes;

  @override
  String toString() =>
      'UpdateAttributesResult(tokenIdentifier: $tokenIdentifier, nonce: $nonce, attributes: ${attributes.length} bytes)';
}

/// Result of add quantity operation.
class AddQuantityResult {
  /// Creates an add quantity result.
  const AddQuantityResult({
    required this.tokenIdentifier,
    required this.nonce,
    required this.addedQuantity,
  });

  /// The token identifier.
  final String tokenIdentifier;

  /// The nonce.
  final BigInt nonce;

  /// The quantity added.
  final BigInt addedQuantity;

  @override
  String toString() =>
      'AddQuantityResult(tokenIdentifier: $tokenIdentifier, nonce: $nonce, addedQuantity: $addedQuantity)';
}

/// Result of burn quantity operation.
class BurnQuantityResult {
  /// Creates a burn quantity result.
  const BurnQuantityResult({
    required this.tokenIdentifier,
    required this.nonce,
    required this.burntQuantity,
  });

  /// The token identifier.
  final String tokenIdentifier;

  /// The nonce.
  final BigInt nonce;

  /// The quantity burnt.
  final BigInt burntQuantity;

  @override
  String toString() =>
      'BurnQuantityResult(tokenIdentifier: $tokenIdentifier, nonce: $nonce, burntQuantity: $burntQuantity)';
}

/// Result of modify royalties operation.
class ModifyRoyaltiesResult {
  /// Creates a modify royalties result.
  const ModifyRoyaltiesResult({
    required this.tokenIdentifier,
    required this.nonce,
    required this.royalties,
  });

  /// The token identifier.
  final String tokenIdentifier;

  /// The nonce.
  final BigInt nonce;

  /// The new royalties (basis points, e.g., 1000 = 10%).
  final BigInt royalties;

  @override
  String toString() =>
      'ModifyRoyaltiesResult(tokenIdentifier: $tokenIdentifier, nonce: $nonce, royalties: $royalties)';
}

/// Result of set new URIs operation.
class SetNewUrisResult {
  /// Creates a set new URIs result.
  const SetNewUrisResult({
    required this.tokenIdentifier,
    required this.nonce,
    required this.uris,
  });

  /// The token identifier.
  final String tokenIdentifier;

  /// The nonce.
  final BigInt nonce;

  /// The new URIs.
  final List<String> uris;

  @override
  String toString() =>
      'SetNewUrisResult(tokenIdentifier: $tokenIdentifier, nonce: $nonce, uris: $uris)';
}

/// Result of modify creator operation.
class ModifyCreatorResult {
  /// Creates a modify creator result.
  const ModifyCreatorResult({
    required this.tokenIdentifier,
    required this.nonce,
  });

  /// The token identifier.
  final String tokenIdentifier;

  /// The nonce.
  final BigInt nonce;

  @override
  String toString() =>
      'ModifyCreatorResult(tokenIdentifier: $tokenIdentifier, nonce: $nonce)';
}

/// Result of update metadata operation.
class UpdateMetadataResult {
  /// Creates an update metadata result.
  const UpdateMetadataResult({
    required this.tokenIdentifier,
    required this.nonce,
    required this.metadata,
  });

  /// The token identifier.
  final String tokenIdentifier;

  /// The nonce.
  final BigInt nonce;

  /// The new metadata.
  final Uint8List metadata;

  @override
  String toString() =>
      'UpdateMetadataResult(tokenIdentifier: $tokenIdentifier, nonce: $nonce, metadata: ${metadata.length} bytes)';
}

/// Result of metadata recreate operation.
class MetadataRecreateResult {
  /// Creates a metadata recreate result.
  const MetadataRecreateResult({
    required this.tokenIdentifier,
    required this.nonce,
    required this.metadata,
  });

  /// The token identifier.
  final String tokenIdentifier;

  /// The nonce.
  final BigInt nonce;

  /// The recreated metadata.
  final Uint8List metadata;

  @override
  String toString() =>
      'MetadataRecreateResult(tokenIdentifier: $tokenIdentifier, nonce: $nonce, metadata: ${metadata.length} bytes)';
}

/// Result of change token to dynamic operation.
class ChangeToDynamicResult {
  /// Creates a change to dynamic result.
  const ChangeToDynamicResult({
    required this.tokenIdentifier,
    required this.tokenName,
    required this.tickerName,
    required this.tokenType,
  });

  /// The token identifier.
  final String tokenIdentifier;

  /// The token name.
  final String tokenName;

  /// The ticker name.
  final String tickerName;

  /// The token type.
  final String tokenType;

  @override
  String toString() =>
      'ChangeToDynamicResult(tokenIdentifier: $tokenIdentifier, tokenName: $tokenName, tickerName: $tickerName, tokenType: $tokenType)';
}

/// Result of register dynamic token operation.
class RegisterDynamicResult {
  /// Creates a register dynamic result.
  const RegisterDynamicResult({
    required this.tokenIdentifier,
    required this.tokenName,
    required this.tokenTicker,
    required this.tokenType,
    required this.numOfDecimals,
  });

  /// The token identifier.
  final String tokenIdentifier;

  /// The token name.
  final String tokenName;

  /// The token ticker.
  final String tokenTicker;

  /// The token type.
  final String tokenType;

  /// The number of decimals.
  final int numOfDecimals;

  @override
  String toString() =>
      'RegisterDynamicResult(tokenIdentifier: $tokenIdentifier, tokenName: $tokenName, tokenTicker: $tokenTicker, tokenType: $tokenType, numOfDecimals: $numOfDecimals)';
}

/// Parser for token management transaction outcomes.
class TokenManagementOutcomeParser {
  /// Creates token management outcome parser.
  const TokenManagementOutcomeParser();

  /// Parses result of issuing fungible token.
  List<IssueFungibleResult> parseIssueFungible(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(transaction, 'issue');
    return events.map((TransactionEvent event) {
      return IssueFungibleResult(
        tokenIdentifier: _extractTokenIdentifier(event),
      );
    }).toList();
  }

  /// Parses result of issuing non-fungible token collection.
  List<IssueNonFungibleResult> parseIssueNonFungible(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'issueNonFungible',
    );
    return events.map((TransactionEvent event) {
      return IssueNonFungibleResult(
        tokenIdentifier: _extractTokenIdentifier(event),
      );
    }).toList();
  }

  /// Parses result of issuing semi-fungible token collection.
  List<IssueSemiFungibleResult> parseIssueSemiFungible(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'issueSemiFungible',
    );
    return events.map((TransactionEvent event) {
      return IssueSemiFungibleResult(
        tokenIdentifier: _extractTokenIdentifier(event),
      );
    }).toList();
  }

  /// Parses the result of registering a meta-ESDT token.
  ///
  /// #### Returns
  /// `List<RegisterMetaEsdtResult>` - Usually contains one element
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<RegisterMetaEsdtResult> parseRegisterMetaEsdt(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'registerMetaESDT',
    );
    return events.map((TransactionEvent event) {
      return RegisterMetaEsdtResult(
        tokenIdentifier: _extractTokenIdentifier(event),
      );
    }).toList();
  }

  /// Parses the result of register and set all roles operation.
  ///
  /// #### Returns
  /// `List<RegisterAndSetAllRolesResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors or events don't match
  List<RegisterAndSetAllRolesResult> parseRegisterAndSetAllRoles(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction);

    final List<TransactionEvent> registerEvents = _findEvents(
      transaction,
      'registerAndSetAllRoles',
    );
    final List<TransactionEvent> setRoleEvents = _findEvents(
      transaction,
      'ESDTSetRole',
    );

    if (registerEvents.length != setRoleEvents.length) {
      throw const TokenManagementParseException(
        'Register events and set role events mismatch. Should have the same number of events.',
      );
    }

    final List<RegisterAndSetAllRolesResult> results =
        <RegisterAndSetAllRolesResult>[];
    for (int i = 0; i < registerEvents.length; i++) {
      final String tokenIdentifier = _extractTokenIdentifier(registerEvents[i]);
      final List<String> roles = setRoleEvents[i].topics
          .skip(3)
          .map((Uint8List role) => _decodeTopicAsString(role))
          .toList();

      results.add(
        RegisterAndSetAllRolesResult(
          tokenIdentifier: tokenIdentifier,
          roles: roles,
        ),
      );
    }

    return results;
  }

  /// Parses the result of set burn role globally operation.
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  void parseSetBurnRoleGlobally(TransactionOnNetwork transaction) {
    _ensureNoError(transaction);
  }

  /// Parses the result of unset burn role globally operation.
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  void parseUnsetBurnRoleGlobally(TransactionOnNetwork transaction) {
    _ensureNoError(transaction);
  }

  /// Parses the result of setting special roles.
  ///
  /// #### Returns
  /// `List<SetSpecialRoleResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<SetSpecialRoleResult> parseSetSpecialRole(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTSetRole',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForSetSpecialRoleEvent(event);
    }).toList();
  }

  /// Parses the result of NFT creation.
  ///
  /// #### Returns
  /// `List<NftCreateResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<NftCreateResult> parseNftCreate(TransactionOnNetwork transaction) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTNFTCreate',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForNftCreateEvent(event);
    }).toList();
  }

  /// Parses the result of local mint operation.
  ///
  /// #### Returns
  /// `List<LocalMintResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<LocalMintResult> parseLocalMint(TransactionOnNetwork transaction) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTLocalMint',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForLocalMintEvent(event);
    }).toList();
  }

  /// Parses the result of local burn operation.
  ///
  /// #### Returns
  /// `List<LocalBurnResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<LocalBurnResult> parseLocalBurn(TransactionOnNetwork transaction) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTLocalBurn',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForLocalBurnEvent(event);
    }).toList();
  }

  /// Parses the result of pause operation.
  ///
  /// #### Returns
  /// `List<PauseResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<PauseResult> parsePause(TransactionOnNetwork transaction) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(transaction, 'ESDTPause');
    return events.map((TransactionEvent event) {
      return PauseResult(tokenIdentifier: _extractTokenIdentifier(event));
    }).toList();
  }

  /// Parses the result of unpause operation.
  ///
  /// #### Returns
  /// `List<UnpauseResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<UnpauseResult> parseUnpause(TransactionOnNetwork transaction) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTUnPause',
    );
    return events.map((TransactionEvent event) {
      return UnpauseResult(tokenIdentifier: _extractTokenIdentifier(event));
    }).toList();
  }

  /// Parses the result of freeze operation.
  ///
  /// #### Returns
  /// `List<FreezeResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<FreezeResult> parseFreeze(TransactionOnNetwork transaction) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTFreeze',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForFreezeEvent(event);
    }).toList();
  }

  /// Parses the result of unfreeze operation.
  ///
  /// #### Returns
  /// `List<UnfreezeResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<UnfreezeResult> parseUnfreeze(TransactionOnNetwork transaction) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTUnFreeze',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForUnfreezeEvent(event);
    }).toList();
  }

  /// Parses the result of wipe operation.
  ///
  /// #### Returns
  /// `List<WipeResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<WipeResult> parseWipe(TransactionOnNetwork transaction) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(transaction, 'ESDTWipe');
    return events.map((TransactionEvent event) {
      return _getOutputForWipeEvent(event);
    }).toList();
  }

  /// Parses the result of update attributes operation.
  ///
  /// #### Returns
  /// `List<UpdateAttributesResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<UpdateAttributesResult> parseUpdateAttributes(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTNFTUpdateAttributes',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForUpdateAttributesEvent(event);
    }).toList();
  }

  /// Parses the result of add quantity operation.
  ///
  /// #### Returns
  /// `List<AddQuantityResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<AddQuantityResult> parseAddQuantity(TransactionOnNetwork transaction) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTNFTAddQuantity',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForAddQuantityEvent(event);
    }).toList();
  }

  /// Parses the result of burn quantity operation.
  ///
  /// #### Returns
  /// `List<BurnQuantityResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<BurnQuantityResult> parseBurnQuantity(TransactionOnNetwork transaction) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTNFTBurn',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForBurnQuantityEvent(event);
    }).toList();
  }

  /// Parses the result of modify royalties operation.
  ///
  /// #### Returns
  /// `List<ModifyRoyaltiesResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<ModifyRoyaltiesResult> parseModifyRoyalties(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTModifyRoyalties',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForModifyRoyaltiesEvent(event);
    }).toList();
  }

  /// Parses the result of set new URIs operation.
  ///
  /// #### Returns
  /// `List<SetNewUrisResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<SetNewUrisResult> parseSetNewUris(TransactionOnNetwork transaction) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTSetNewURIs',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForSetNewUrisEvent(event);
    }).toList();
  }

  /// Parses the result of modify creator operation.
  ///
  /// #### Returns
  /// `List<ModifyCreatorResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<ModifyCreatorResult> parseModifyCreator(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTModifyCreator',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForModifyCreatorEvent(event);
    }).toList();
  }

  /// Parses the result of update metadata operation.
  ///
  /// #### Returns
  /// `List<UpdateMetadataResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<UpdateMetadataResult> parseUpdateMetadata(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTMetaDataUpdate',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForUpdateMetadataEvent(event);
    }).toList();
  }

  /// Parses the result of metadata recreate operation.
  ///
  /// #### Returns
  /// `List<MetadataRecreateResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<MetadataRecreateResult> parseMetadataRecreate(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'ESDTMetaDataRecreate',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForMetadataRecreateEvent(event);
    }).toList();
  }

  /// Parses the result of change token to dynamic operation.
  ///
  /// #### Returns
  /// `List<ChangeToDynamicResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<ChangeToDynamicResult> parseChangeTokenToDynamic(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'changeToDynamic',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForChangeToDynamicEvent(event);
    }).toList();
  }

  /// Parses the result of register dynamic token operation.
  ///
  /// #### Returns
  /// `List<RegisterDynamicResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<RegisterDynamicResult> parseRegisterDynamicToken(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'registerDynamic',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForRegisterDynamicEvent(event);
    }).toList();
  }

  /// Parses the result of register dynamic token and setting roles operation.
  ///
  /// #### Returns
  /// `List<RegisterDynamicResult>`
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If transaction has errors
  List<RegisterDynamicResult> parseRegisterDynamicTokenAndSettingRoles(
    TransactionOnNetwork transaction,
  ) {
    _ensureNoError(transaction);

    final List<TransactionEvent> events = _findEvents(
      transaction,
      'registerAndSetAllRolesDynamic',
    );
    return events.map((TransactionEvent event) {
      return _getOutputForRegisterDynamicEvent(event);
    }).toList();
  }

  /// Collects the transaction's own logs together with the logs of every
  /// smart-contract result it produced.
  ///
  /// Token-management endpoints that act on another account — `freeze`,
  /// `unFreeze`, `wipe`, `setSpecialRole`, `unSetSpecialRole` and the local
  /// mint/burn pair — are executed by the system contract forwarding a
  /// built-in call to the target address. That call runs on the target's
  /// shard, so its events are reported on the resulting smart-contract result
  /// rather than on the original transaction.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to collect logs from
  ///
  /// #### Returns
  /// `List<TransactionLogs>` - Every log container attached to the
  /// transaction, in transaction-first order.
  List<TransactionLogs> _allLogs(TransactionOnNetwork transaction) {
    final List<TransactionLogs> logs = <TransactionLogs>[];
    final TransactionLogs? transactionLogs = transaction.logs;
    if (transactionLogs != null) {
      logs.add(transactionLogs);
    }
    for (final SmartContractResult result
        in transaction.smartContractResults ?? const <SmartContractResult>[]) {
      final TransactionLogs? resultLogs = result.logs;
      if (resultLogs != null) {
        logs.add(resultLogs);
      }
    }
    return logs;
  }

  /// Finds every event named [identifier] across the transaction and its
  /// smart-contract results.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to search
  /// - `identifier` - Event identifier to match
  ///
  /// #### Returns
  /// `List<TransactionEvent>` - Matching events, in transaction-first order.
  List<TransactionEvent> _findEvents(
    TransactionOnNetwork transaction,
    String identifier,
  ) {
    return <TransactionEvent>[
      for (final TransactionLogs logs in _allLogs(transaction))
        ...logs.findEvents(identifier),
    ];
  }

  /// Throws when the transaction reported a `signalError` anywhere.
  ///
  /// #### Parameters
  /// - `transaction` - Transaction to inspect
  ///
  /// #### Throws
  /// - `TokenManagementParseException` - If no logs are present at all, or if
  ///   a `signalError` event was emitted by the transaction or by any of its
  ///   smart-contract results.
  void _ensureNoError(TransactionOnNetwork transaction) {
    final List<TransactionLogs> allLogs = _allLogs(transaction);
    if (allLogs.isEmpty) {
      throw const TokenManagementParseException(
        'Transaction has no logs - cannot parse token management outcome',
      );
    }

    for (final TransactionLogs logs in allLogs) {
      for (final TransactionEvent event in logs.events) {
        if (event.identifier == 'signalError') {
          final String data = event.additionalData.isNotEmpty
              ? _decodeTopicAsString(event.additionalData[0])
              : '';
          final String message = event.topics.length > 1
              ? _decodeTopicAsString(event.topics[1])
              : '';

          throw TokenManagementParseException(
            'encountered signalError: $message ($data)',
          );
        }
      }
    }
  }

  String _extractTokenIdentifier(TransactionEvent event) {
    if (event.topics.isEmpty || event.topics[0].isEmpty) {
      return '';
    }
    return _decodeTopicAsString(event.topics[0]);
  }

  BigInt _extractNonce(TransactionEvent event) {
    if (event.topics.length < 2 || event.topics[1].isEmpty) {
      return BigInt.zero;
    }
    return _bufferToBigInt(event.topics[1]);
  }

  BigInt _extractAmount(TransactionEvent event) {
    if (event.topics.length < 3 || event.topics[2].isEmpty) {
      return BigInt.zero;
    }
    return _bufferToBigInt(event.topics[2]);
  }

  String _extractAddress(TransactionEvent event) {
    if (event.topics.length < 4 || event.topics[3].isEmpty) {
      return '';
    }
    final Address address = Address(event.topics[3]);
    return address.bech32;
  }

  String _decodeTopicAsString(Uint8List topic) {
    return String.fromCharCodes(topic);
  }

  BigInt _bufferToBigInt(Uint8List buffer) {
    if (buffer.isEmpty) return BigInt.zero;
    BigInt result = BigInt.zero;
    for (final int byte in buffer) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  SetSpecialRoleResult _getOutputForSetSpecialRoleEvent(
    TransactionEvent event,
  ) {
    final Address userAddress = event.address;
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final List<String> roles = event.topics
        .skip(3)
        .map((Uint8List role) => _decodeTopicAsString(role))
        .toList();

    return SetSpecialRoleResult(
      userAddress: userAddress,
      tokenIdentifier: tokenIdentifier,
      roles: roles,
    );
  }

  NftCreateResult _getOutputForNftCreateEvent(TransactionEvent event) {
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final BigInt nonce = _extractNonce(event);
    final BigInt amount = _extractAmount(event);

    return NftCreateResult(
      tokenIdentifier: tokenIdentifier,
      nonce: nonce,
      initialQuantity: amount,
    );
  }

  LocalMintResult _getOutputForLocalMintEvent(TransactionEvent event) {
    final Address userAddress = event.address;
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final BigInt nonce = _extractNonce(event);
    final BigInt mintedSupply = _extractAmount(event);

    return LocalMintResult(
      userAddress: userAddress,
      tokenIdentifier: tokenIdentifier,
      nonce: nonce,
      mintedSupply: mintedSupply,
    );
  }

  LocalBurnResult _getOutputForLocalBurnEvent(TransactionEvent event) {
    final Address userAddress = event.address;
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final BigInt nonce = _extractNonce(event);
    final BigInt burntSupply = _extractAmount(event);

    return LocalBurnResult(
      userAddress: userAddress,
      tokenIdentifier: tokenIdentifier,
      nonce: nonce,
      burntSupply: burntSupply,
    );
  }

  FreezeResult _getOutputForFreezeEvent(TransactionEvent event) {
    final String userAddress = _extractAddress(event);
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final BigInt nonce = _extractNonce(event);
    final BigInt balance = _extractAmount(event);

    return FreezeResult(
      userAddress: userAddress,
      tokenIdentifier: tokenIdentifier,
      nonce: nonce,
      balance: balance,
    );
  }

  UnfreezeResult _getOutputForUnfreezeEvent(TransactionEvent event) {
    final String userAddress = _extractAddress(event);
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final BigInt nonce = _extractNonce(event);
    final BigInt balance = _extractAmount(event);

    return UnfreezeResult(
      userAddress: userAddress,
      tokenIdentifier: tokenIdentifier,
      nonce: nonce,
      balance: balance,
    );
  }

  WipeResult _getOutputForWipeEvent(TransactionEvent event) {
    final String userAddress = _extractAddress(event);
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final BigInt nonce = _extractNonce(event);
    final BigInt balance = _extractAmount(event);

    return WipeResult(
      userAddress: userAddress,
      tokenIdentifier: tokenIdentifier,
      nonce: nonce,
      balance: balance,
    );
  }

  UpdateAttributesResult _getOutputForUpdateAttributesEvent(
    TransactionEvent event,
  ) {
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final BigInt nonce = _extractNonce(event);
    final Uint8List attributes =
        event.topics.length > 3 && event.topics[3].isNotEmpty
        ? event.topics[3]
        : Uint8List(0);

    return UpdateAttributesResult(
      tokenIdentifier: tokenIdentifier,
      nonce: nonce,
      attributes: attributes,
    );
  }

  AddQuantityResult _getOutputForAddQuantityEvent(TransactionEvent event) {
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final BigInt nonce = _extractNonce(event);
    final BigInt addedQuantity = _extractAmount(event);

    return AddQuantityResult(
      tokenIdentifier: tokenIdentifier,
      nonce: nonce,
      addedQuantity: addedQuantity,
    );
  }

  BurnQuantityResult _getOutputForBurnQuantityEvent(TransactionEvent event) {
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final BigInt nonce = _extractNonce(event);
    final BigInt burntQuantity = _extractAmount(event);

    return BurnQuantityResult(
      tokenIdentifier: tokenIdentifier,
      nonce: nonce,
      burntQuantity: burntQuantity,
    );
  }

  ModifyRoyaltiesResult _getOutputForModifyRoyaltiesEvent(
    TransactionEvent event,
  ) {
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final BigInt nonce = _extractNonce(event);
    final BigInt royalties =
        event.topics.length > 3 && event.topics[3].isNotEmpty
        ? _bufferToBigInt(event.topics[3])
        : BigInt.zero;

    return ModifyRoyaltiesResult(
      tokenIdentifier: tokenIdentifier,
      nonce: nonce,
      royalties: royalties,
    );
  }

  SetNewUrisResult _getOutputForSetNewUrisEvent(TransactionEvent event) {
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final BigInt nonce = _extractNonce(event);
    final List<String> uris = event.topics
        .skip(3)
        .where((Uint8List uri) => uri.isNotEmpty)
        .map((Uint8List uri) => _decodeTopicAsString(uri))
        .toList();

    return SetNewUrisResult(
      tokenIdentifier: tokenIdentifier,
      nonce: nonce,
      uris: uris,
    );
  }

  ModifyCreatorResult _getOutputForModifyCreatorEvent(TransactionEvent event) {
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final BigInt nonce = _extractNonce(event);

    return ModifyCreatorResult(tokenIdentifier: tokenIdentifier, nonce: nonce);
  }

  UpdateMetadataResult _getOutputForUpdateMetadataEvent(
    TransactionEvent event,
  ) {
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final BigInt nonce = _extractNonce(event);
    final Uint8List metadata =
        event.topics.length > 3 && event.topics[3].isNotEmpty
        ? event.topics[3]
        : Uint8List(0);

    return UpdateMetadataResult(
      tokenIdentifier: tokenIdentifier,
      nonce: nonce,
      metadata: metadata,
    );
  }

  MetadataRecreateResult _getOutputForMetadataRecreateEvent(
    TransactionEvent event,
  ) {
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final BigInt nonce = _extractNonce(event);
    final Uint8List metadata =
        event.topics.length > 3 && event.topics[3].isNotEmpty
        ? event.topics[3]
        : Uint8List(0);

    return MetadataRecreateResult(
      tokenIdentifier: tokenIdentifier,
      nonce: nonce,
      metadata: metadata,
    );
  }

  ChangeToDynamicResult _getOutputForChangeToDynamicEvent(
    TransactionEvent event,
  ) {
    final String tokenIdentifier = _extractTokenIdentifier(event);
    final String tokenName =
        event.topics.length > 1 && event.topics[1].isNotEmpty
        ? _decodeTopicAsString(event.topics[1])
        : '';
    final String tickerName =
        event.topics.length > 2 && event.topics[2].isNotEmpty
        ? _decodeTopicAsString(event.topics[2])
        : '';
    final String tokenType =
        event.topics.length > 3 && event.topics[3].isNotEmpty
        ? _decodeTopicAsString(event.topics[3])
        : '';

    return ChangeToDynamicResult(
      tokenIdentifier: tokenIdentifier,
      tokenName: tokenName,
      tickerName: tickerName,
      tokenType: tokenType,
    );
  }

  RegisterDynamicResult _getOutputForRegisterDynamicEvent(
    TransactionEvent event,
  ) {
    final String tokenIdentifier =
        event.topics.isNotEmpty && event.topics[0].isNotEmpty
        ? _decodeTopicAsString(event.topics[0])
        : '';
    final String tokenName =
        event.topics.length > 1 && event.topics[1].isNotEmpty
        ? _decodeTopicAsString(event.topics[1])
        : '';
    final String tokenTicker =
        event.topics.length > 2 && event.topics[2].isNotEmpty
        ? _decodeTopicAsString(event.topics[2])
        : '';
    final String tokenType =
        event.topics.length > 3 && event.topics[3].isNotEmpty
        ? _decodeTopicAsString(event.topics[3])
        : '';
    final int numOfDecimals =
        event.topics.length > 4 && event.topics[4].isNotEmpty
        ? _bufferToBigInt(event.topics[4]).toInt()
        : 0;

    return RegisterDynamicResult(
      tokenIdentifier: tokenIdentifier,
      tokenName: tokenName,
      tokenTicker: tokenTicker,
      tokenType: tokenType,
      numOfDecimals: numOfDecimals,
    );
  }
}
