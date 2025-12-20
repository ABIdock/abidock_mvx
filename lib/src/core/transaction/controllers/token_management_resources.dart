/// Input types for token management operations.
/// Provides strongly typed input classes for issuance, roles, NFT operations, and token control.

import 'dart:typed_data';

import '../../core.dart';

/// Input for token issuance.
///
/// Base class for all token issuance operations. Contains common properties
/// that control token capabilities and permissions.
///
/// #### Parameters
/// - `tokenName` - Human-readable token name (3-20 alphanumeric chars)
/// - `tokenTicker` - Token ticker symbol (3-10 uppercase alphanumeric)
/// - `canFreeze` - Allow freezing token balance in specific accounts
/// - `canWipe` - Allow wiping token balance from frozen accounts
/// - `canPause` - Allow pausing all token operations
/// - `canChangeOwner` - Allow transferring token ownership
/// - `canUpgrade` - Allow upgrading token properties
/// - `canAddSpecialRoles` - Allow setting special roles for accounts
///
/// #### Example
/// ```dart
/// // Used via subclasses like IssueFungibleInput
/// final input = IssueFungibleInput(
///   tokenName: 'MyToken',
///   tokenTicker: 'MTK',
///   initialSupply: BigInt.from(1000000),
///   numDecimals: BigInt.from(18),
///   canFreeze: true,
///   canWipe: true,
/// );
/// ```
class IssueInput {
  /// Constructor for IssueInput.
  const IssueInput({
    required this.tokenName,
    required this.tokenTicker,
    this.canFreeze = false,
    this.canWipe = false,
    this.canPause = false,
    this.canChangeOwner = false,
    this.canUpgrade = false,
    this.canAddSpecialRoles = false,
  });

  /// Token name.
  final String tokenName;

  /// Token ticker.
  final String tokenTicker;

  /// Can freeze.
  final bool canFreeze;

  /// Can wipe.
  final bool canWipe;

  /// Can pause.
  final bool canPause;

  /// Can change owner.
  final bool canChangeOwner;

  /// Can upgrade.
  final bool canUpgrade;

  /// Can add special roles.
  final bool canAddSpecialRoles;
}

/// Input for issuing fungible tokens.
///
/// Creates a new ESDT (eStandard Digital Token) fungible token with fixed or variable supply.
///
/// #### Parameters
/// - `tokenName` - Token name (inherited from IssueInput)
/// - `tokenTicker` - Token ticker (inherited from IssueInput)
/// - `initialSupply` - Initial token supply in smallest units
/// - `numDecimals` - Number of decimal places (typically 18)
/// - Token capability flags (inherited from IssueInput)
///
/// #### Example
/// ```dart
/// final input = IssueFungibleInput(
///   tokenName: 'MyToken',
///   tokenTicker: 'MTK',
///   initialSupply: BigInt.from(1000000) * BigInt.from(10).pow(18),
///   numDecimals: BigInt.from(18),
///   canFreeze: true,
///   canMint: true,
/// );
/// ```
class IssueFungibleInput extends IssueInput {
  const IssueFungibleInput({
    required super.tokenName,
    required super.tokenTicker,
    required this.initialSupply,
    required this.numDecimals,
    super.canFreeze,
    super.canWipe,
    super.canPause,
    super.canChangeOwner,
    super.canUpgrade,
    super.canAddSpecialRoles,
  });

  final BigInt initialSupply;
  final BigInt numDecimals;
}

/// Input for issuing non-fungible tokens.
class IssueNonFungibleInput extends IssueInput {
  const IssueNonFungibleInput({
    required super.tokenName,
    required super.tokenTicker,
    this.canTransferNFTCreateRole = false,
    super.canFreeze,
    super.canWipe,
    super.canPause,
    super.canChangeOwner,
    super.canUpgrade,
    super.canAddSpecialRoles,
  });

  final bool canTransferNFTCreateRole;
}

/// Input for issuing semi-fungible tokens.
typedef IssueSemiFungibleInput = IssueNonFungibleInput;

/// Input for registering Meta-ESDT.
class RegisterMetaESDTInput {
  const RegisterMetaESDTInput({
    required this.tokenName,
    required this.tokenTicker,
    required this.numDecimals,
    this.canFreeze = false,
    this.canWipe = false,
    this.canPause = false,
    this.canTransferNFTCreateRole = false,
    this.canChangeOwner = false,
    this.canUpgrade = false,
    this.canAddSpecialRoles = false,
  });

  final String tokenName;
  final String tokenTicker;
  final BigInt numDecimals;
  final bool canFreeze;
  final bool canWipe;
  final bool canPause;
  final bool canTransferNFTCreateRole;
  final bool canChangeOwner;
  final bool canUpgrade;
  final bool canAddSpecialRoles;
}

/// Input for registering and setting all roles.
class RegisterRolesInput {
  const RegisterRolesInput({
    required this.tokenName,
    required this.tokenTicker,
    required this.tokenType,
    required this.numDecimals,
  });

  final String tokenName;
  final String tokenTicker;
  final String tokenType;
  final BigInt numDecimals;
}

/// Input for setting burn role globally.
class BurnRoleGloballyInput {
  const BurnRoleGloballyInput({required this.tokenIdentifier});
  final String tokenIdentifier;
}

/// Input for setting special role on fungible token.
class FungibleSpecialRoleInput {
  const FungibleSpecialRoleInput({
    required this.user,
    required this.tokenIdentifier,
    this.addRoleLocalMint = false,
    this.addRoleLocalBurn = false,
    this.addRoleESDTTransferRole = false,
  });

  final Address user;
  final String tokenIdentifier;
  final bool addRoleLocalMint;
  final bool addRoleLocalBurn;
  final bool addRoleESDTTransferRole;
}

/// Input for unsetting special role on fungible token.
class UnsetFungibleSpecialRoleInput {
  const UnsetFungibleSpecialRoleInput({
    required this.user,
    required this.tokenIdentifier,
    this.removeRoleLocalMint = false,
    this.removeRoleLocalBurn = false,
    this.removeRoleESDTTransferRole = false,
  });

  final Address user;
  final String tokenIdentifier;
  final bool removeRoleLocalMint;
  final bool removeRoleLocalBurn;
  final bool removeRoleESDTTransferRole;
}

/// Input for setting special role on semi-fungible token.
class SemiFungibleSpecialRoleInput {
  const SemiFungibleSpecialRoleInput({
    required this.user,
    required this.tokenIdentifier,
    this.addRoleNFTCreate = false,
    this.addRoleNFTBurn = false,
    this.addRoleNFTAddQuantity = false,
    this.addRoleESDTTransferRole = false,
    this.addRoleNFTUpdate,
    this.addRoleESDTModifyRoyalties,
    this.addRoleESDTSetNewUri,
    this.addRoleESDTModifyCreator,
    this.addRoleNFTRecreate,
  });

  final Address user;
  final String tokenIdentifier;
  final bool addRoleNFTCreate;
  final bool addRoleNFTBurn;
  final bool addRoleNFTAddQuantity;
  final bool addRoleESDTTransferRole;
  final bool? addRoleNFTUpdate;
  final bool? addRoleESDTModifyRoyalties;
  final bool? addRoleESDTSetNewUri;
  final bool? addRoleESDTModifyCreator;
  final bool? addRoleNFTRecreate;
}

/// Input for unsetting special role on semi-fungible token.
class UnsetSemiFungibleSpecialRoleInput {
  const UnsetSemiFungibleSpecialRoleInput({
    required this.user,
    required this.tokenIdentifier,
    this.removeRoleNFTBurn = false,
    this.removeRoleNFTAddQuantity = false,
    this.removeRoleESDTTransferRole = false,
    this.removeRoleNFTUpdate,
    this.removeRoleESDTModifyRoyalties,
    this.removeRoleESDTSetNewUri,
    this.removeRoleESDTModifyCreator,
    this.removeRoleNFTRecreate,
  });

  final Address user;
  final String tokenIdentifier;
  final bool removeRoleNFTBurn;
  final bool removeRoleNFTAddQuantity;
  final bool removeRoleESDTTransferRole;
  final bool? removeRoleNFTUpdate;
  final bool? removeRoleESDTModifyRoyalties;
  final bool? removeRoleESDTSetNewUri;
  final bool? removeRoleESDTModifyCreator;
  final bool? removeRoleNFTRecreate;
}

/// Input for setting special role on non-fungible token.
class SpecialRoleInput {
  const SpecialRoleInput({
    required this.user,
    required this.tokenIdentifier,
    this.addRoleNFTCreate = false,
    this.addRoleNFTBurn = false,
    this.addRoleNFTUpdateAttributes = false,
    this.addRoleNFTAddURI = false,
    this.addRoleESDTTransferRole = false,
    this.addRoleESDTModifyCreator,
    this.addRoleNFTRecreate,
    this.addRoleESDTSetNewURI,
    this.addRoleESDTModifyRoyalties,
  });

  final Address user;
  final String tokenIdentifier;
  final bool addRoleNFTCreate;
  final bool addRoleNFTBurn;
  final bool addRoleNFTUpdateAttributes;
  final bool addRoleNFTAddURI;
  final bool addRoleESDTTransferRole;
  final bool? addRoleESDTModifyCreator;
  final bool? addRoleNFTRecreate;
  final bool? addRoleESDTSetNewURI;
  final bool? addRoleESDTModifyRoyalties;
}

/// Input for unsetting special role on non-fungible token.
class UnsetSpecialRoleInput {
  const UnsetSpecialRoleInput({
    required this.user,
    required this.tokenIdentifier,
    this.removeRoleNFTBurn = false,
    this.removeRoleNFTUpdateAttributes = false,
    this.removeRoleNFTAddURI = false,
    this.removeRoleESDTTransferRole = false,
    this.removeRoleESDTModifyCreator,
    this.removeRoleNFTRecreate,
    this.removeRoleESDTSetNewURI,
    this.removeRoleESDTModifyRoyalties,
  });

  final Address user;
  final String tokenIdentifier;
  final bool removeRoleNFTBurn;
  final bool removeRoleNFTUpdateAttributes;
  final bool removeRoleNFTAddURI;
  final bool removeRoleESDTTransferRole;
  final bool? removeRoleESDTModifyCreator;
  final bool? removeRoleNFTRecreate;
  final bool? removeRoleESDTSetNewURI;
  final bool? removeRoleESDTModifyRoyalties;
}

/// Input for creating NFT.
class MintInput {
  const MintInput({
    required this.tokenIdentifier,
    required this.initialQuantity,
    required this.name,
    required this.royalties,
    required this.hash,
    required this.attributes,
    required this.uris,
  });

  final String tokenIdentifier;
  final BigInt initialQuantity;
  final String name;
  final int royalties;
  final String hash;
  final Uint8List attributes;
  final List<String> uris;
}

/// Input for local mint.
class LocalMintInput {
  const LocalMintInput({
    required this.tokenIdentifier,
    required this.supplyToMint,
  });

  final String tokenIdentifier;
  final BigInt supplyToMint;
}

/// Input for local burn.
class LocalBurnInput {
  const LocalBurnInput({
    required this.tokenIdentifier,
    required this.supplyToBurn,
  });

  final String tokenIdentifier;
  final BigInt supplyToBurn;
}

/// Input for management operations.
class ManagementInput {
  const ManagementInput({required this.user, required this.tokenIdentifier});

  final Address user;
  final String tokenIdentifier;
}

/// Input for pause operations.
class PausingInput {
  const PausingInput({required this.tokenIdentifier});
  final String tokenIdentifier;
}

/// Input for update operations.
class UpdateInput {
  const UpdateInput({required this.tokenIdentifier, required this.tokenNonce});

  final String tokenIdentifier;
  final BigInt tokenNonce;
}

/// Input for updating attributes.
class UpdateAttributesInput extends UpdateInput {
  const UpdateAttributesInput({
    required super.tokenIdentifier,
    required super.tokenNonce,
    required this.attributes,
  });

  final Uint8List attributes;
}

/// Input for updating quantity.
class UpdateQuantityInput extends UpdateInput {
  const UpdateQuantityInput({
    required super.tokenIdentifier,
    required super.tokenNonce,
    required this.quantity,
  });

  final BigInt quantity;
}

/// Input for metadata operations.
class BaseInput {
  const BaseInput({required this.tokenIdentifier, required this.tokenNonce});

  final String tokenIdentifier;
  final BigInt tokenNonce;
}

/// Input for modifying royalties.
class ModifyRoyaltiesInput extends BaseInput {
  const ModifyRoyaltiesInput({
    required super.tokenIdentifier,
    required super.tokenNonce,
    required this.newRoyalties,
  });

  final BigInt newRoyalties;
}

/// Input for modifying creator.
typedef ModifyCreatorInput = BaseInput;

/// Input for setting new URIs.
class SetNewUriInput extends BaseInput {
  const SetNewUriInput({
    required super.tokenIdentifier,
    required super.tokenNonce,
    required this.newUris,
  });

  final List<String> newUris;
}

/// Input for managing metadata.
class ManageMetadataInput {
  const ManageMetadataInput({
    required this.tokenIdentifier,
    required this.tokenNonce,
    this.newTokenName,
    this.newRoyalties,
    this.newHash,
    this.newAttributes,
    this.newUris,
  });

  final String tokenIdentifier;
  final BigInt tokenNonce;
  final String? newTokenName;
  final BigInt? newRoyalties;
  final String? newHash;
  final Uint8List? newAttributes;
  final List<String>? newUris;
}

/// Input for updating token ID.
class UpdateTokenIDInput {
  const UpdateTokenIDInput({required this.tokenIdentifier});
  final String tokenIdentifier;
}

/// Input for changing token to dynamic.
class ChangeTokenToDynamicInput {
  const ChangeTokenToDynamicInput({required this.tokenIdentifier});
  final String tokenIdentifier;
}

/// Input for registering dynamic token.
class RegisteringDynamicTokenInput {
  const RegisteringDynamicTokenInput({
    required this.tokenName,
    required this.tokenTicker,
    required this.tokenType,
  });

  final String tokenName;
  final String tokenTicker;
  final String tokenType;
}
