/// Controller for token management transactions.
///
/// Provides API for ESDT token operations including issuance, role
/// management, NFT operations, and token control. Supports all MultiversX token
/// standards: fungible, semi-fungible, non-fungible, and Meta-ESDT.

import '../../core.dart';

/// Controller for token management operations.
///
/// Extends BaseController for gas estimation and signing. Handles all token types and management functions.
///
/// #### Example
/// ```dart
/// final controller = TokenManagementController(
///   chainId: '1',
///   gasLimitEstimator: estimator,
/// );
/// ```
class TokenManagementController extends BaseController {
  /// Creates token management controller with chain ID and optional gas estimator.
  ///
  /// #### Parameters
  /// - `chainId` - Network chain ID
  /// - `gasLimitEstimator` - Optional gas estimator
  TokenManagementController({required ChainId chainId, super.gasLimitEstimator})
    : factory = TokenManagementTransactionsFactory(
        config: TokenManagementConfig(chainId: chainId),
      );

  /// Factory for creating token management transactions.
  final TokenManagementTransactionsFactory factory;

  List<String> _buildFungibleRoles(FungibleSpecialRoleInput options) {
    final roles = <String>[];
    if (options.addRoleLocalMint) roles.add('ESDTRoleLocalMint');
    if (options.addRoleLocalBurn) roles.add('ESDTRoleLocalBurn');
    if (options.addRoleESDTTransferRole) roles.add('ESDTTransferRole');
    return roles;
  }

  List<String> _buildFungibleUnsetRoles(UnsetFungibleSpecialRoleInput options) {
    final roles = <String>[];
    if (options.removeRoleLocalMint) roles.add('ESDTRoleLocalMint');
    if (options.removeRoleLocalBurn) roles.add('ESDTRoleLocalBurn');
    if (options.removeRoleESDTTransferRole) roles.add('ESDTTransferRole');
    return roles;
  }

  List<String> _buildNFTRoles(SpecialRoleInput options) {
    final roles = <String>[];
    if (options.addRoleNFTCreate) roles.add('ESDTRoleNFTCreate');
    if (options.addRoleNFTBurn) roles.add('ESDTRoleNFTBurn');
    if (options.addRoleNFTUpdateAttributes) {
      roles.add('ESDTRoleNFTUpdateAttributes');
    }
    if (options.addRoleNFTAddURI) roles.add('ESDTRoleNFTAddURI');
    if (options.addRoleESDTTransferRole) roles.add('ESDTTransferRole');
    return roles;
  }

  List<String> _buildNFTUnsetRoles(UnsetSpecialRoleInput options) {
    final roles = <String>[];
    if (options.removeRoleNFTBurn) roles.add('ESDTRoleNFTBurn');
    if (options.removeRoleNFTUpdateAttributes) {
      roles.add('ESDTRoleNFTUpdateAttributes');
    }
    if (options.removeRoleNFTAddURI) roles.add('ESDTRoleNFTAddURI');
    if (options.removeRoleESDTTransferRole) roles.add('ESDTTransferRole');
    return roles;
  }

  /// Creates transaction for issuing fungible ESDT token.
  Future<Transaction> createTransactionForIssuingFungible(
    IAccount sender,
    Nonce nonce,
    IssueFungibleInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForIssuingFungible(
      sender: sender.address,
      tokenName: options.tokenName,
      tokenTicker: options.tokenTicker,
      initialSupply: options.initialSupply,
      decimals: options.numDecimals.toInt(),
      properties: TokenProperties(
        canFreeze: options.canFreeze,
        canWipe: options.canWipe,
        canPause: options.canPause,
        canChangeOwner: options.canChangeOwner,
        canUpgrade: options.canUpgrade,
        canAddSpecialRoles: options.canAddSpecialRoles,
      ),
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for issuing semi-fungible ESDT token.
  Future<Transaction> createTransactionForIssuingSemiFungible(
    IAccount sender,
    Nonce nonce,
    IssueSemiFungibleInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForIssuingSemiFungible(
      sender: sender.address,
      tokenName: options.tokenName,
      tokenTicker: options.tokenTicker,
      properties: TokenProperties(
        canFreeze: options.canFreeze,
        canWipe: options.canWipe,
        canPause: options.canPause,
        canChangeOwner: options.canChangeOwner,
        canUpgrade: options.canUpgrade,
        canAddSpecialRoles: options.canAddSpecialRoles,
        canTransferNFTCreateRole: options.canTransferNFTCreateRole,
      ),
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for issuing non-fungible ESDT token.
  Future<Transaction> createTransactionForIssuingNonFungible(
    IAccount sender,
    Nonce nonce,
    IssueNonFungibleInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForIssuingNonFungible(
      sender: sender.address,
      tokenName: options.tokenName,
      tokenTicker: options.tokenTicker,
      properties: TokenProperties(
        canFreeze: options.canFreeze,
        canWipe: options.canWipe,
        canPause: options.canPause,
        canChangeOwner: options.canChangeOwner,
        canUpgrade: options.canUpgrade,
        canAddSpecialRoles: options.canAddSpecialRoles,
        canTransferNFTCreateRole: options.canTransferNFTCreateRole,
      ),
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for registering Meta-ESDT token.
  Future<Transaction> createTransactionForRegisteringMetaEsdt(
    IAccount sender,
    Nonce nonce,
    RegisterMetaESDTInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForRegisteringMetaEsdt(
      sender: sender.address,
      tokenName: options.tokenName,
      tokenTicker: options.tokenTicker,
      decimals: options.numDecimals.toInt(),
      properties: TokenProperties(
        canFreeze: options.canFreeze,
        canWipe: options.canWipe,
        canPause: options.canPause,
        canChangeOwner: options.canChangeOwner,
        canUpgrade: options.canUpgrade,
        canAddSpecialRoles: options.canAddSpecialRoles,
        canTransferNFTCreateRole: options.canTransferNFTCreateRole,
      ),
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for registering and setting all roles.
  Future<Transaction> createTransactionForRegisteringAndSettingRoles(
    IAccount sender,
    Nonce nonce,
    RegisterRolesInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForRegisteringAndSettingRoles(
      sender: sender.address,
      tokenName: options.tokenName,
      tokenTicker: options.tokenTicker,
      decimals: options.numDecimals.toInt(),
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for setting burn role globally.
  Future<Transaction> createTransactionForSettingBurnRoleGlobally(
    IAccount sender,
    Nonce nonce,
    BurnRoleGloballyInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForSettingBurnRoleGlobally(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for unsetting burn role globally.
  Future<Transaction> createTransactionForUnsettingBurnRoleGlobally(
    IAccount sender,
    Nonce nonce,
    BurnRoleGloballyInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForUnsettingBurnRoleGlobally(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for setting special role on fungible token.
  Future<Transaction> createTransactionForSettingSpecialRoleOnFungibleToken(
    IAccount sender,
    Nonce nonce,
    FungibleSpecialRoleInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory
        .createTransactionForSettingSpecialRoleOnFungibleToken(
          sender: sender.address,
          user: options.user,
          tokenIdentifier: options.tokenIdentifier,
          roles: _buildFungibleRoles(options),
        );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for unsetting special role on fungible token.
  Future<Transaction> createTransactionForUnsettingSpecialRoleOnFungibleToken(
    IAccount sender,
    Nonce nonce,
    UnsetFungibleSpecialRoleInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory
        .createTransactionForUnsettingSpecialRoleOnFungibleToken(
          sender: sender.address,
          user: options.user,
          tokenIdentifier: options.tokenIdentifier,
          roles: _buildFungibleUnsetRoles(options),
        );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for setting special role on semi-fungible token.
  Future<Transaction> createTransactionForSettingSpecialRoleOnSemiFungibleToken(
    IAccount sender,
    Nonce nonce,
    SemiFungibleSpecialRoleInput options,
    BaseControllerInput baseOptions,
  ) async {
    final roles = <String>[];
    if (options.addRoleNFTCreate) roles.add('ESDTRoleNFTCreate');
    if (options.addRoleNFTBurn) roles.add('ESDTRoleNFTBurn');
    if (options.addRoleNFTAddQuantity) roles.add('ESDTRoleNFTAddQuantity');
    if (options.addRoleESDTTransferRole) roles.add('ESDTTransferRole');

    final transaction = factory
        .createTransactionForSettingSpecialRoleOnNonFungibleToken(
          sender: sender.address,
          user: options.user,
          tokenIdentifier: options.tokenIdentifier,
          roles: roles,
        );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for unsetting special role on semi-fungible token.
  Future<Transaction>
  createTransactionForUnsettingSpecialRoleOnSemiFungibleToken(
    IAccount sender,
    Nonce nonce,
    UnsetSemiFungibleSpecialRoleInput options,
    BaseControllerInput baseOptions,
  ) async {
    final roles = <String>[];
    if (options.removeRoleNFTBurn) roles.add('ESDTRoleNFTBurn');
    if (options.removeRoleNFTAddQuantity) roles.add('ESDTRoleNFTAddQuantity');
    if (options.removeRoleESDTTransferRole) roles.add('ESDTTransferRole');

    final transaction = factory
        .createTransactionForUnsettingSpecialRoleOnNonFungibleToken(
          sender: sender.address,
          user: options.user,
          tokenIdentifier: options.tokenIdentifier,
          roles: roles,
        );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for setting special role on Meta-ESDT.
  Future<Transaction> createTransactionForSettingSpecialRoleOnMetaESDT(
    IAccount sender,
    Nonce nonce,
    SemiFungibleSpecialRoleInput options,
    BaseControllerInput baseOptions,
  ) async {
    final roles = <String>[];
    if (options.addRoleNFTCreate) roles.add('ESDTRoleNFTCreate');
    if (options.addRoleNFTBurn) roles.add('ESDTRoleNFTBurn');
    if (options.addRoleNFTAddQuantity) roles.add('ESDTRoleNFTAddQuantity');
    if (options.addRoleESDTTransferRole) roles.add('ESDTTransferRole');

    final transaction = factory
        .createTransactionForSettingSpecialRoleOnNonFungibleToken(
          sender: sender.address,
          user: options.user,
          tokenIdentifier: options.tokenIdentifier,
          roles: roles,
        );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for unsetting special role on Meta-ESDT.
  Future<Transaction> createTransactionForUnsettingSpecialRoleOnMetaESDT(
    IAccount sender,
    Nonce nonce,
    UnsetSemiFungibleSpecialRoleInput options,
    BaseControllerInput baseOptions,
  ) async {
    final roles = <String>[];
    if (options.removeRoleNFTBurn) roles.add('ESDTRoleNFTBurn');
    if (options.removeRoleNFTAddQuantity) roles.add('ESDTRoleNFTAddQuantity');
    if (options.removeRoleESDTTransferRole) roles.add('ESDTTransferRole');

    final transaction = factory
        .createTransactionForUnsettingSpecialRoleOnNonFungibleToken(
          sender: sender.address,
          user: options.user,
          tokenIdentifier: options.tokenIdentifier,
          roles: roles,
        );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for setting special role on non-fungible token.
  Future<Transaction> createTransactionForSettingSpecialRoleOnNonFungibleToken(
    IAccount sender,
    Nonce nonce,
    SpecialRoleInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory
        .createTransactionForSettingSpecialRoleOnNonFungibleToken(
          sender: sender.address,
          user: options.user,
          tokenIdentifier: options.tokenIdentifier,
          roles: _buildNFTRoles(options),
        );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for unsetting special role on non-fungible token.
  Future<Transaction>
  createTransactionForUnsettingSpecialRoleOnNonFungibleToken(
    IAccount sender,
    Nonce nonce,
    UnsetSpecialRoleInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory
        .createTransactionForUnsettingSpecialRoleOnNonFungibleToken(
          sender: sender.address,
          user: options.user,
          tokenIdentifier: options.tokenIdentifier,
          roles: _buildNFTUnsetRoles(options),
        );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for creating NFT.
  Future<Transaction> createTransactionForCreatingNft(
    IAccount sender,
    Nonce nonce,
    MintInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForCreatingNft(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
      initialQuantity: options.initialQuantity,
      name: options.name,
      royalties: options.royalties,
      hash: options.hash,
      attributes: options.attributes,
      uris: options.uris,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for local minting.
  Future<Transaction> createTransactionForLocalMinting(
    IAccount sender,
    Nonce nonce,
    LocalMintInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForLocalMint(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
      supplyToMint: options.supplyToMint,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for local burning.
  Future<Transaction> createTransactionForLocalBurning(
    IAccount sender,
    Nonce nonce,
    LocalBurnInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForLocalBurn(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
      supplyToBurn: options.supplyToBurn,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for updating attributes.
  Future<Transaction> createTransactionForUpdatingAttributes(
    IAccount sender,
    Nonce nonce,
    UpdateAttributesInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForUpdatingAttributes(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
      nonce: options.tokenNonce.toInt(),
      attributes: options.attributes,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for adding quantity.
  Future<Transaction> createTransactionForAddingQuantity(
    IAccount sender,
    Nonce nonce,
    UpdateQuantityInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForAddingQuantity(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
      nonce: options.tokenNonce.toInt(),
      quantityToAdd: options.quantity,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for burning quantity.
  Future<Transaction> createTransactionForBurningQuantity(
    IAccount sender,
    Nonce nonce,
    UpdateQuantityInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForBurningQuantity(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
      nonce: options.tokenNonce.toInt(),
      quantityToBurn: options.quantity,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for pausing token.
  Future<Transaction> createTransactionForPausing(
    IAccount sender,
    Nonce nonce,
    PausingInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForPausing(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for unpausing token.
  Future<Transaction> createTransactionForUnpausing(
    IAccount sender,
    Nonce nonce,
    PausingInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForUnpausing(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for freezing token.
  Future<Transaction> createTransactionForFreezing(
    IAccount sender,
    Nonce nonce,
    ManagementInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForFreezing(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
      addressToFreeze: options.user,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for unfreezing token.
  Future<Transaction> createTransactionForUnfreezing(
    IAccount sender,
    Nonce nonce,
    ManagementInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForUnfreezing(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
      addressToUnfreeze: options.user,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for wiping token.
  Future<Transaction> createTransactionForWiping(
    IAccount sender,
    Nonce nonce,
    ManagementInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForWiping(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
      addressToWipe: options.user,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for modifying royalties.
  Future<Transaction> createTransactionForModifyingRoyalties(
    IAccount sender,
    Nonce nonce,
    ModifyRoyaltiesInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForModifyingRoyalties(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
      nonce: options.tokenNonce.toInt(),
      newRoyalties: options.newRoyalties.toInt(),
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for setting new URIs.
  Future<Transaction> createTransactionForSettingNewUris(
    IAccount sender,
    Nonce nonce,
    SetNewUriInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForSettingNewUris(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
      nonce: options.tokenNonce.toInt(),
      newUris: options.newUris,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for modifying creator.
  Future<Transaction> createTransactionForModifyingCreator(
    IAccount sender,
    Nonce nonce,
    ModifyCreatorInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForModifyingCreator(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
      nonce: options.tokenNonce.toInt(),
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for updating metadata.
  Future<Transaction> createTransactionForUpdatingMetadata(
    IAccount sender,
    Nonce nonce,
    ManageMetadataInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForUpdatingMetadata(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
      nonce: options.tokenNonce.toInt(),
      newName: options.newTokenName ?? '',
      newRoyalties: options.newRoyalties?.toInt() ?? 0,
      newHash: options.newHash ?? '',
      newAttributes: options.newAttributes,
      newUris: options.newUris,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for recreating metadata.
  Future<Transaction> createTransactionForMetadataRecreate(
    IAccount sender,
    Nonce nonce,
    ManageMetadataInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForRecreatingMetadata(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
      nonce: options.tokenNonce.toInt(),
      newName: options.newTokenName ?? '',
      newRoyalties: options.newRoyalties?.toInt() ?? 0,
      newHash: options.newHash ?? '',
      newAttributes: options.newAttributes,
      newUris: options.newUris,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for changing token to dynamic.
  Future<Transaction> createTransactionForChangingTokenToDynamic(
    IAccount sender,
    Nonce nonce,
    ChangeTokenToDynamicInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForChangingToDynamic(
      sender: sender.address,
      tokenIdentifier: options.tokenIdentifier,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }

  /// Creates transaction for registering dynamic token.
  Future<Transaction> createTransactionForRegisteringDynamicToken(
    IAccount sender,
    Nonce nonce,
    RegisteringDynamicTokenInput options,
    BaseControllerInput baseOptions,
  ) async {
    final transaction = factory.createTransactionForRegisteringDynamic(
      sender: sender.address,
      tokenName: options.tokenName,
      tokenTicker: options.tokenTicker,
    );

    return setupAndSignTransaction(transaction, baseOptions, nonce, sender);
  }
}
