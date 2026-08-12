/// Factory for creating token management transactions.
/// Provides low-level builders for ESDT token operations including issuance, roles, NFTs, and control.
import 'dart:convert';
import 'dart:typed_data';

import '../../../abi/abi.dart';
import '../../core.dart';

/// ESDT system smart contract address
const String esdtContractAddressHex =
    '000000000000000000010000000000000000000000000000000000000002ffff';

/// Token type argument denoting a fungible ESDT.
const String tokenTypeFungible = 'FNG';

/// Token type argument denoting a MetaESDT.
const String tokenTypeMeta = 'META';

/// Token type arguments accepted by `registerAndSetAllRoles`.
const Set<String> tokenTypes = <String>{
  'NFT',
  'SFT',
  tokenTypeMeta,
  tokenTypeFungible,
};

/// Token type arguments accepted by the dynamic registration endpoints.
const Set<String> dynamicTokenTypes = <String>{'NFT', 'SFT', tokenTypeMeta};

/// Configuration for token management transactions.
/// Defines gas limits and costs for ESDT token operations.
class TokenManagementConfig {
  /// Creates token management configuration.
  const TokenManagementConfig({
    required this.chainId,
    this.minGasLimit = 50000,
    this.gasLimitPerByte = 1500,
    this.gasLimitIssue = 60000000,
    this.gasLimitToggleBurnRoleGlobally = 60000000,
    this.gasLimitEsdtLocalMint = 300000,
    this.gasLimitEsdtLocalBurn = 300000,
    this.gasLimitSetSpecialRole = 60000000,
    this.gasLimitPausing = 60000000,
    this.gasLimitFreezing = 60000000,
    this.gasLimitWiping = 60000000,
    this.gasLimitEsdtNftCreate = 3000000,
    this.gasLimitEsdtNftUpdateAttributes = 1000000,
    this.gasLimitEsdtNftAddQuantity = 1000000,
    this.gasLimitEsdtNftBurn = 1000000,
    this.gasLimitStorePerByte = 10000,
    this.gasLimitEsdtModifyRoyalties = 60000000,
    this.gasLimitEsdtModifyCreator = 60000000,
    this.gasLimitEsdtMetadataUpdate = 60000000,
    this.gasLimitSetNewUris = 60000000,
    this.gasLimitNftMetadataRecreate = 60000000,
    this.gasLimitNftChangeToDynamic = 60000000,
    this.gasLimitUpdateTokenId = 60000000,
    this.gasLimitRegisterDynamic = 60000000,
    this.issueCost = '50000000000000000',
  });

  /// Builds a [TokenManagementConfig] from a shared [TransactionsFactoryConfig].
  ///
  /// #### Parameters
  /// - `shared` - Aggregate factory config populated by `NetworkEntrypoint`.
  ///
  /// #### Returns
  /// A new [TokenManagementConfig] mirroring `shared`'s token-management fields.
  static TokenManagementConfig fromShared(TransactionsFactoryConfig shared) =>
      TokenManagementConfig(
        chainId: shared.chainId,
        minGasLimit: shared.minGasLimit,
        gasLimitPerByte: shared.gasLimitPerByte,
        gasLimitIssue: shared.gasLimitIssue,
        gasLimitToggleBurnRoleGlobally: shared.gasLimitToggleBurnRoleGlobally,
        gasLimitEsdtLocalMint: shared.gasLimitEsdtLocalMint,
        gasLimitEsdtLocalBurn: shared.gasLimitEsdtLocalBurn,
        gasLimitSetSpecialRole: shared.gasLimitSetSpecialRole,
        gasLimitPausing: shared.gasLimitPausing,
        gasLimitFreezing: shared.gasLimitFreezing,
        gasLimitWiping: shared.gasLimitWiping,
        gasLimitEsdtNftCreate: shared.gasLimitEsdtNftCreate,
        gasLimitEsdtNftUpdateAttributes: shared.gasLimitEsdtNftUpdateAttributes,
        gasLimitEsdtNftAddQuantity: shared.gasLimitEsdtNftAddQuantity,
        gasLimitEsdtNftBurn: shared.gasLimitEsdtNftBurn,
        gasLimitStorePerByte: shared.gasLimitStorePerByte,
        gasLimitEsdtModifyRoyalties: shared.gasLimitEsdtModifyRoyalties,
        gasLimitEsdtModifyCreator: shared.gasLimitEsdtModifyCreator,
        gasLimitEsdtMetadataUpdate: shared.gasLimitEsdtMetadataUpdate,
        gasLimitSetNewUris: shared.gasLimitSetNewUris,
        gasLimitNftMetadataRecreate: shared.gasLimitNftMetadataRecreate,
        gasLimitNftChangeToDynamic: shared.gasLimitNftChangeToDynamic,
        gasLimitUpdateTokenId: shared.gasLimitUpdateTokenId,
        gasLimitRegisterDynamic: shared.gasLimitRegisterDynamic,
      );

  final ChainId chainId;
  final int minGasLimit;
  final int gasLimitPerByte;
  final int gasLimitIssue;
  final int gasLimitToggleBurnRoleGlobally;
  final int gasLimitEsdtLocalMint;
  final int gasLimitEsdtLocalBurn;
  final int gasLimitSetSpecialRole;
  final int gasLimitPausing;
  final int gasLimitFreezing;
  final int gasLimitWiping;
  final int gasLimitEsdtNftCreate;
  final int gasLimitEsdtNftUpdateAttributes;
  final int gasLimitEsdtNftAddQuantity;
  final int gasLimitEsdtNftBurn;
  final int gasLimitStorePerByte;
  final int gasLimitEsdtModifyRoyalties;
  final int gasLimitEsdtModifyCreator;
  final int gasLimitEsdtMetadataUpdate;
  final int gasLimitSetNewUris;
  final int gasLimitNftMetadataRecreate;
  final int gasLimitNftChangeToDynamic;
  final int gasLimitUpdateTokenId;
  final int gasLimitRegisterDynamic;

  /// Issuance cost, in atomic units (attoEGLD).
  final String issueCost;
}

/// Token properties for issuance.
///
/// Defines capabilities and restrictions for newly issued tokens.
/// Properties cannot be changed after issuance (except through upgrade if enabled).
class TokenProperties {
  const TokenProperties({
    this.canFreeze = false,
    this.canWipe = false,
    this.canPause = false,
    this.canTransferNFTCreateRole = false,
    this.canChangeOwner = false,
    this.canUpgrade = true,
    this.canAddSpecialRoles = false,
  });

  final bool canFreeze;
  final bool canWipe;
  final bool canPause;
  final bool canTransferNFTCreateRole;
  final bool canChangeOwner;
  final bool canUpgrade;
  final bool canAddSpecialRoles;
}

/// Factory for creating token management transactions.
///
/// Low-level factory for building unsigned token transactions.
class TokenManagementTransactionsFactory {
  /// Creates token management transactions factory.
  TokenManagementTransactionsFactory({required this.config})
    : _argSerializer = ArgSerializer(),
      _esdtContractAddress = Address.fromHex(esdtContractAddressHex);

  final TokenManagementConfig config;

  final ArgSerializer _argSerializer;
  final Address _esdtContractAddress;

  /// Creates transaction for issuing fungible ESDT token.
  ///
  /// Builds transaction calling `issue` on ESDT system contract. Creates a new
  /// fungible token with specified supply and decimals. Requires payment of 0.05 EGLD.
  ///
  /// #### Parameters
  /// - `sender` - Address that will own and manage the token
  /// - `tokenName` - Full token name
  /// - `tokenTicker` - Token ticker symbol
  /// - `initialSupply` - Total supply in atomic units
  /// - `decimals` - Number of decimal places
  /// - `properties` - Token capabilities
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with 0.05 EGLD payment
  Transaction createTransactionForIssuingFungible({
    required Address sender,
    required String tokenName,
    required String tokenTicker,
    required BigInt initialSupply,
    required int decimals,
    TokenProperties properties = const TokenProperties(),
  }) {
    _validateTokenName(tokenName);
    _validateTokenTicker(tokenTicker);

    final List<TypedValue> args = <TypedValue>[
      StringValue(tokenName),
      StringValue(tokenTicker),
      BigUIntValue(initialSupply),
      BigUIntValue(BigInt.from(decimals)),
      ..._propertiesAsArgs(properties, includeTransferNftCreateRole: false),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'issue',
      args: args,
      value: Balance.fromString(config.issueCost),
      executionGasLimit: config.gasLimitIssue,
    );
  }

  /// Creates transaction for issuing semi-fungible ESDT token.
  ///
  /// Builds transaction calling `issueSemiFungible` on ESDT system contract. Creates
  /// a new semi-fungible token collection that can have multiple instances with quantities.
  /// Requires payment of 0.05 EGLD.
  ///
  /// #### Parameters
  /// - `sender` - Address that will own and manage the collection
  /// - `tokenName` - Full collection name
  /// - `tokenTicker` - Collection ticker symbol
  /// - `properties` - Collection capabilities
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with 0.05 EGLD payment
  Transaction createTransactionForIssuingSemiFungible({
    required Address sender,
    required String tokenName,
    required String tokenTicker,
    TokenProperties properties = const TokenProperties(),
  }) {
    _validateTokenName(tokenName);
    _validateTokenTicker(tokenTicker);

    final List<TypedValue> args = <TypedValue>[
      StringValue(tokenName),
      StringValue(tokenTicker),
      ..._propertiesAsArgs(properties, includeTransferNftCreateRole: true),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'issueSemiFungible',
      args: args,
      value: Balance.fromString(config.issueCost),
      executionGasLimit: config.gasLimitIssue,
    );
  }

  /// Creates transaction for issuing non-fungible ESDT token.
  Transaction createTransactionForIssuingNonFungible({
    required Address sender,
    required String tokenName,
    required String tokenTicker,
    TokenProperties properties = const TokenProperties(),
  }) {
    _validateTokenName(tokenName);
    _validateTokenTicker(tokenTicker);

    final List<TypedValue> args = <TypedValue>[
      StringValue(tokenName),
      StringValue(tokenTicker),
      ..._propertiesAsArgs(properties, includeTransferNftCreateRole: true),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'issueNonFungible',
      args: args,
      value: Balance.fromString(config.issueCost),
      executionGasLimit: config.gasLimitIssue,
    );
  }

  /// Creates transaction for registering Meta-ESDT token.
  Transaction createTransactionForRegisteringMetaEsdt({
    required Address sender,
    required String tokenName,
    required String tokenTicker,
    required int decimals,
    TokenProperties properties = const TokenProperties(),
  }) {
    _validateTokenName(tokenName);
    _validateTokenTicker(tokenTicker);

    final List<TypedValue> args = <TypedValue>[
      StringValue(tokenName),
      StringValue(tokenTicker),
      BigUIntValue(BigInt.from(decimals)),
      ..._propertiesAsArgs(properties, includeTransferNftCreateRole: true),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'registerMetaESDT',
      args: args,
      value: Balance.fromString(config.issueCost),
      executionGasLimit: config.gasLimitIssue,
    );
  }

  /// Creates transaction for registering and setting all roles.
  ///
  /// The ESDT system contract accepts exactly four arguments for this endpoint —
  /// token name, ticker, token type and number of decimals — and rejects any
  /// other argument count. Token properties are therefore not emitted here.
  ///
  /// #### Parameters
  /// - `sender` - Address that will own and manage the token
  /// - `tokenName` - Full token name
  /// - `tokenTicker` - Token ticker symbol
  /// - `tokenType` - One of `NFT`, `SFT`, `META`, `FNG`
  /// - `decimals` - Number of decimal places
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with 0.05 EGLD payment
  ///
  /// #### Throws
  /// - `ArgumentError` - When `tokenType` is not a recognised token type
  Transaction createTransactionForRegisteringAndSettingRoles({
    required Address sender,
    required String tokenName,
    required String tokenTicker,
    required String tokenType,
    required int decimals,
  }) {
    _validateTokenName(tokenName);
    _validateTokenTicker(tokenTicker);
    _validateTokenType(tokenType);

    final List<TypedValue> args = <TypedValue>[
      StringValue(tokenName),
      StringValue(tokenTicker),
      StringValue(tokenType),
      BigUIntValue(BigInt.from(decimals)),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'registerAndSetAllRoles',
      args: args,
      value: Balance.fromString(config.issueCost),
      executionGasLimit: config.gasLimitIssue,
    );
  }

  /// Sets burn role globally for a token.
  Transaction createTransactionForSettingBurnRoleGlobally({
    required Address sender,
    required String tokenIdentifier,
  }) {
    return _buildTransaction(
      sender: sender,
      functionName: 'setBurnRoleGlobally',
      args: <TypedValue>[TokenIdentifierValue(tokenIdentifier)],
      executionGasLimit: config.gasLimitToggleBurnRoleGlobally,
    );
  }

  /// Unsets burn role globally for a token.
  Transaction createTransactionForUnsettingBurnRoleGlobally({
    required Address sender,
    required String tokenIdentifier,
  }) {
    return _buildTransaction(
      sender: sender,
      functionName: 'unsetBurnRoleGlobally',
      args: <TypedValue>[TokenIdentifierValue(tokenIdentifier)],
      executionGasLimit: config.gasLimitToggleBurnRoleGlobally,
    );
  }

  /// Sets special roles on fungible token for specific address.
  Transaction createTransactionForSettingSpecialRoleOnFungibleToken({
    required Address sender,
    required Address user,
    required String tokenIdentifier,
    required List<String> roles,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      AddressValue(user.bytes),
      ...roles.map((String role) => StringValue(role)),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'setSpecialRole',
      args: args,
      executionGasLimit: config.gasLimitSetSpecialRole,
    );
  }

  /// Unsets special roles on fungible token for specific address.
  Transaction createTransactionForUnsettingSpecialRoleOnFungibleToken({
    required Address sender,
    required Address user,
    required String tokenIdentifier,
    required List<String> roles,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      AddressValue(user.bytes),
      ...roles.map((String role) => StringValue(role)),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'unSetSpecialRole',
      args: args,
      executionGasLimit: config.gasLimitSetSpecialRole,
    );
  }

  /// Sets special roles on NFT for specific address.
  Transaction createTransactionForSettingSpecialRoleOnNonFungibleToken({
    required Address sender,
    required Address user,
    required String tokenIdentifier,
    required List<String> roles,
  }) {
    return createTransactionForSettingSpecialRoleOnFungibleToken(
      sender: sender,
      user: user,
      tokenIdentifier: tokenIdentifier,
      roles: roles,
    );
  }

  /// Unsets special roles on NFT for specific address.
  Transaction createTransactionForUnsettingSpecialRoleOnNonFungibleToken({
    required Address sender,
    required Address user,
    required String tokenIdentifier,
    required List<String> roles,
  }) {
    return createTransactionForUnsettingSpecialRoleOnFungibleToken(
      sender: sender,
      user: user,
      tokenIdentifier: tokenIdentifier,
      roles: roles,
    );
  }

  /// Creates NFT.
  Transaction createTransactionForCreatingNft({
    required Address sender,
    required String tokenIdentifier,
    required BigInt initialQuantity,
    required String name,
    required int royalties,
    String? hash,
    Uint8List? attributes,
    List<String>? uris,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      BigUIntValue(initialQuantity),
      StringValue(name),
      BigUIntValue(BigInt.from(royalties)),
      BytesValue(hash != null ? utf8.encode(hash) : Uint8List(0)),
      BytesValue(attributes ?? Uint8List(0)),
      ...?uris?.map((String uri) => StringValue(uri)),
    ];

    final int attributesLength = attributes?.length ?? 0;
    final int urisLength =
        uris?.fold<int>(0, (int sum, String uri) => sum + uri.length) ?? 0;
    final int extraGas =
        (attributesLength + urisLength) * config.gasLimitStorePerByte;

    return _buildTransaction(
      sender: sender,
      functionName: 'ESDTNFTCreate',
      args: args,
      executionGasLimit: config.gasLimitEsdtNftCreate + extraGas,
      receiverIsSender: true,
    );
  }

  /// Local mint for fungible or semi-fungible tokens.
  Transaction createTransactionForLocalMint({
    required Address sender,
    required String tokenIdentifier,
    required BigInt supplyToMint,
    int nonce = 0,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      if (nonce > 0) U64Value(BigInt.from(nonce)),
      BigUIntValue(supplyToMint),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'ESDTLocalMint',
      args: args,
      executionGasLimit: config.gasLimitEsdtLocalMint,
      receiverIsSender: true,
    );
  }

  /// Local burn for fungible or semi-fungible tokens.
  Transaction createTransactionForLocalBurn({
    required Address sender,
    required String tokenIdentifier,
    required BigInt supplyToBurn,
    int nonce = 0,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      if (nonce > 0) U64Value(BigInt.from(nonce)),
      BigUIntValue(supplyToBurn),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'ESDTLocalBurn',
      args: args,
      executionGasLimit: config.gasLimitEsdtLocalBurn,
      receiverIsSender: true,
    );
  }

  /// Updates NFT attributes.
  Transaction createTransactionForUpdatingAttributes({
    required Address sender,
    required String tokenIdentifier,
    required int nonce,
    required Uint8List attributes,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      U64Value(BigInt.from(nonce)),
      BytesValue(attributes),
    ];

    final int extraGas = attributes.length * config.gasLimitStorePerByte;

    return _buildTransaction(
      sender: sender,
      functionName: 'ESDTNFTUpdateAttributes',
      args: args,
      executionGasLimit: config.gasLimitEsdtNftUpdateAttributes + extraGas,
      receiverIsSender: true,
    );
  }

  /// Adds quantity to NFT/SFT.
  Transaction createTransactionForAddingQuantity({
    required Address sender,
    required String tokenIdentifier,
    required int nonce,
    required BigInt quantityToAdd,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      U64Value(BigInt.from(nonce)),
      BigUIntValue(quantityToAdd),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'ESDTNFTAddQuantity',
      args: args,
      executionGasLimit: config.gasLimitEsdtNftAddQuantity,
      receiverIsSender: true,
    );
  }

  /// Burns an NFT/SFT.
  ///
  /// Requires ESDTRoleNFTBurn role.
  Transaction createTransactionForBurningQuantity({
    required Address sender,
    required String tokenIdentifier,
    required int nonce,
    required BigInt quantityToBurn,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      U64Value(BigInt.from(nonce)),
      BigUIntValue(quantityToBurn),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'ESDTNFTBurn',
      args: args,
      executionGasLimit: config.gasLimitEsdtNftBurn,
      receiverIsSender: true,
    );
  }

  /// Pauses all transactions for token.
  Transaction createTransactionForPausing({
    required Address sender,
    required String tokenIdentifier,
  }) {
    return _buildTransaction(
      sender: sender,
      functionName: 'pause',
      args: <TypedValue>[TokenIdentifierValue(tokenIdentifier)],
      executionGasLimit: config.gasLimitPausing,
    );
  }

  /// Unpauses token.
  Transaction createTransactionForUnpausing({
    required Address sender,
    required String tokenIdentifier,
  }) {
    return _buildTransaction(
      sender: sender,
      functionName: 'unPause',
      args: <TypedValue>[TokenIdentifierValue(tokenIdentifier)],
      executionGasLimit: config.gasLimitPausing,
    );
  }

  /// Freezes token for specific account.
  Transaction createTransactionForFreezing({
    required Address sender,
    required String tokenIdentifier,
    required Address addressToFreeze,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      AddressValue(addressToFreeze.bytes),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'freeze',
      args: args,
      executionGasLimit: config.gasLimitFreezing,
    );
  }

  /// Unfreezes token for specific account.
  Transaction createTransactionForUnfreezing({
    required Address sender,
    required String tokenIdentifier,
    required Address addressToUnfreeze,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      AddressValue(addressToUnfreeze.bytes),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'unFreeze',
      args: args,
      executionGasLimit: config.gasLimitFreezing,
    );
  }

  /// Wipes token from frozen account.
  Transaction createTransactionForWiping({
    required Address sender,
    required String tokenIdentifier,
    required Address addressToWipe,
    int nonce = 0,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      if (nonce > 0) U64Value(BigInt.from(nonce)),
      AddressValue(addressToWipe.bytes),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'wipe',
      args: args,
      executionGasLimit: config.gasLimitWiping,
    );
  }

  /// Modifies NFT royalties.
  Transaction createTransactionForModifyingRoyalties({
    required Address sender,
    required String tokenIdentifier,
    required int nonce,
    required int newRoyalties,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      U64Value(BigInt.from(nonce)),
      BigUIntValue(BigInt.from(newRoyalties)),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'ESDTModifyRoyalties',
      args: args,
      executionGasLimit: config.gasLimitEsdtModifyRoyalties,
      receiverIsSender: true,
    );
  }

  /// Sets new URIs for NFT.
  Transaction createTransactionForSettingNewUris({
    required Address sender,
    required String tokenIdentifier,
    required int nonce,
    required List<String> newUris,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      U64Value(BigInt.from(nonce)),
      ...newUris.map((String uri) => StringValue(uri)),
    ];

    final int extraGas =
        newUris.fold<int>(0, (int sum, String uri) => sum + uri.length) *
        config.gasLimitStorePerByte;

    return _buildTransaction(
      sender: sender,
      functionName: 'ESDTSetNewURIs',
      args: args,
      executionGasLimit: config.gasLimitSetNewUris + extraGas,
      receiverIsSender: true,
    );
  }

  /// Modifies creator address of NFT.
  Transaction createTransactionForModifyingCreator({
    required Address sender,
    required String tokenIdentifier,
    required int nonce,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      U64Value(BigInt.from(nonce)),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'ESDTModifyCreator',
      args: args,
      executionGasLimit: config.gasLimitEsdtModifyCreator,
      receiverIsSender: true,
    );
  }

  /// Updates NFT metadata via the new `ESDTNFTUpdate` endpoint
  /// (supernova). Differs from `createTransactionForUpdatingMetadata`
  /// (`ESDTMetaDataUpdate`) in that it targets the per-NFT update flow
  /// gated by `ESDTRoleNFTUpdate`. Data layout:
  /// `ESDTNFTUpdate@tokenId@nonce@name@royalties@hash@attributes@uris...`.
  Transaction createTransactionForNftUpdate({
    required Address sender,
    required String tokenIdentifier,
    required int nonce,
    required String newName,
    required int newRoyalties,
    String? newHash,
    Uint8List? newAttributes,
    List<String>? newUris,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      U64Value(BigInt.from(nonce)),
      StringValue(newName),
      BigUIntValue(BigInt.from(newRoyalties)),
      BytesValue(newHash != null ? utf8.encode(newHash) : Uint8List(0)),
      BytesValue(newAttributes ?? Uint8List(0)),
      ...?newUris?.map((String uri) => StringValue(uri)),
    ];

    final int attributesLength = newAttributes?.length ?? 0;
    final int urisLength =
        newUris?.fold<int>(0, (int sum, String uri) => sum + uri.length) ?? 0;
    final int extraGas =
        (attributesLength + urisLength) * config.gasLimitStorePerByte;

    return _buildTransaction(
      sender: sender,
      functionName: 'ESDTNFTUpdate',
      args: args,
      executionGasLimit: config.gasLimitEsdtMetadataUpdate + extraGas,
      receiverIsSender: true,
    );
  }

  /// Recreates an NFT instance via the new `ESDTNFTRecreate` endpoint
  /// (supernova). Same payload shape as `createTransactionForNftUpdate`
  /// but gated by `ESDTRoleNFTRecreate`.
  Transaction createTransactionForNftRecreate({
    required Address sender,
    required String tokenIdentifier,
    required int nonce,
    required String newName,
    required int newRoyalties,
    String? newHash,
    Uint8List? newAttributes,
    List<String>? newUris,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      U64Value(BigInt.from(nonce)),
      StringValue(newName),
      BigUIntValue(BigInt.from(newRoyalties)),
      BytesValue(newHash != null ? utf8.encode(newHash) : Uint8List(0)),
      BytesValue(newAttributes ?? Uint8List(0)),
      ...?newUris?.map((String uri) => StringValue(uri)),
    ];

    final int attributesLength = newAttributes?.length ?? 0;
    final int urisLength =
        newUris?.fold<int>(0, (int sum, String uri) => sum + uri.length) ?? 0;
    final int extraGas =
        (attributesLength + urisLength) * config.gasLimitStorePerByte;

    return _buildTransaction(
      sender: sender,
      functionName: 'ESDTNFTRecreate',
      args: args,
      executionGasLimit: config.gasLimitNftMetadataRecreate + extraGas,
      receiverIsSender: true,
    );
  }

  /// Updates all NFT metadata at once.
  Transaction createTransactionForUpdatingMetadata({
    required Address sender,
    required String tokenIdentifier,
    required int nonce,
    required String newName,
    required int newRoyalties,
    String? newHash,
    Uint8List? newAttributes,
    List<String>? newUris,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      U64Value(BigInt.from(nonce)),
      StringValue(newName),
      BigUIntValue(BigInt.from(newRoyalties)),
      BytesValue(newHash != null ? utf8.encode(newHash) : Uint8List(0)),
      BytesValue(newAttributes ?? Uint8List(0)),
      ...?newUris?.map((String uri) => StringValue(uri)),
    ];

    final int attributesLength = newAttributes?.length ?? 0;
    final int urisLength =
        newUris?.fold<int>(0, (int sum, String uri) => sum + uri.length) ?? 0;
    final int extraGas =
        (attributesLength + urisLength) * config.gasLimitStorePerByte;

    return _buildTransaction(
      sender: sender,
      functionName: 'ESDTMetaDataUpdate',
      args: args,
      executionGasLimit: config.gasLimitEsdtMetadataUpdate + extraGas,
      receiverIsSender: true,
    );
  }

  /// Recreates NFT metadata for dynamic NFTs.
  Transaction createTransactionForRecreatingMetadata({
    required Address sender,
    required String tokenIdentifier,
    required int nonce,
    required String newName,
    required int newRoyalties,
    String? newHash,
    Uint8List? newAttributes,
    List<String>? newUris,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      U64Value(BigInt.from(nonce)),
      StringValue(newName),
      BigUIntValue(BigInt.from(newRoyalties)),
      BytesValue(newHash != null ? utf8.encode(newHash) : Uint8List(0)),
      BytesValue(newAttributes ?? Uint8List(0)),
      ...?newUris?.map((String uri) => StringValue(uri)),
    ];

    final int attributesLength = newAttributes?.length ?? 0;
    final int urisLength =
        newUris?.fold<int>(0, (int sum, String uri) => sum + uri.length) ?? 0;
    final int extraGas =
        (attributesLength + urisLength) * config.gasLimitStorePerByte;

    return _buildTransaction(
      sender: sender,
      functionName: 'ESDTMetaDataRecreate',
      args: args,
      executionGasLimit: config.gasLimitNftMetadataRecreate + extraGas,
      receiverIsSender: true,
    );
  }

  /// Changes NFT to dynamic type.
  Transaction createTransactionForChangingToDynamic({
    required Address sender,
    required String tokenIdentifier,
  }) {
    return _buildTransaction(
      sender: sender,
      functionName: 'changeToDynamic',
      args: <TypedValue>[TokenIdentifierValue(tokenIdentifier)],
      executionGasLimit: config.gasLimitNftChangeToDynamic,
    );
  }

  /// Registers a dynamic NFT, SFT or MetaESDT token.
  ///
  /// The token type is mandatory and must occupy the third argument slot.
  /// Only `META` carries a decimal precision; the ESDT system contract reads
  /// every argument past the token type as a property pair, so no other type
  /// may append one.
  ///
  /// #### Parameters
  /// - `sender` - Address that will own and manage the token
  /// - `tokenName` - Full token name
  /// - `tokenTicker` - Token ticker symbol
  /// - `tokenType` - One of `NFT`, `SFT`, `META`
  /// - `numDecimals` - Decimal precision, emitted only for `META`
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with 0.05 EGLD payment
  ///
  /// #### Throws
  /// - `ArgumentError` - When `tokenType` is `FNG`, which cannot be dynamic, or
  ///   is not a recognised token type
  Transaction createTransactionForRegisteringDynamic({
    required Address sender,
    required String tokenName,
    required String tokenTicker,
    required String tokenType,
    int? numDecimals,
  }) {
    _validateTokenName(tokenName);
    _validateTokenTicker(tokenTicker);
    _validateDynamicTokenType(tokenType);

    final List<TypedValue> args = <TypedValue>[
      StringValue(tokenName),
      StringValue(tokenTicker),
      StringValue(tokenType),
      if (tokenType == tokenTypeMeta && numDecimals != null)
        BigUIntValue(BigInt.from(numDecimals)),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'registerDynamic',
      args: args,
      value: Balance.fromString(config.issueCost),
      executionGasLimit: config.gasLimitRegisterDynamic,
    );
  }

  /// Transfers the token manager role on an ESDT / NFT / SFT / MetaESDT
  /// token to [newOwner]. Must be sent by the current token manager.
  Transaction createTransactionForTransferringOwnership({
    required Address sender,
    required String tokenIdentifier,
    required Address newOwner,
  }) {
    return _buildTransaction(
      sender: sender,
      functionName: 'transferOwnership',
      args: <TypedValue>[
        TokenIdentifierValue(tokenIdentifier),
        AddressValue(newOwner.bytes),
      ],
      executionGasLimit: config.gasLimitSetSpecialRole,
    );
  }

  /// Toggles token property flags post-issuance.
  ///
  /// Pass a [TokenProperties] describing the complete desired end state, not
  /// just the properties to enable: every flag is written, so a property can
  /// be switched off as well as on.
  Transaction createTransactionForControllingProperties({
    required Address sender,
    required String tokenIdentifier,
    required TokenProperties properties,
  }) {
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      ..._propertiesAsArgs(properties, includeTransferNftCreateRole: true),
    ];
    return _buildTransaction(
      sender: sender,
      functionName: 'controlChanges',
      args: args,
      executionGasLimit: config.gasLimitSetSpecialRole,
    );
  }

  /// Appends a new URI to an existing NFT / SFT / MetaESDT instance.
  /// Complements `createTransactionForSettingNewUris` which fully replaces
  /// the URI list.
  Transaction createTransactionForAddingNftUri({
    required Address sender,
    required String tokenIdentifier,
    required int nonce,
    required List<String> uris,
  }) {
    if (uris.isEmpty) {
      throw ArgumentError('At least one URI is required');
    }
    final List<TypedValue> args = <TypedValue>[
      TokenIdentifierValue(tokenIdentifier),
      U64Value(BigInt.from(nonce)),
      for (final String uri in uris) StringValue(uri),
    ];
    return _buildTransaction(
      sender: sender,
      functionName: 'ESDTNFTAddURI',
      args: args,
      executionGasLimit: config.gasLimitSetNewUris,
      receiverIsSender: true,
    );
  }

  /// Permanently stops NFT creation for [tokenIdentifier]. Irreversible.
  Transaction createTransactionForStoppingNftCreate({
    required Address sender,
    required String tokenIdentifier,
  }) {
    return _buildTransaction(
      sender: sender,
      functionName: 'stopNFTCreate',
      args: <TypedValue>[TokenIdentifierValue(tokenIdentifier)],
      executionGasLimit: config.gasLimitSetSpecialRole,
    );
  }

  /// Transfers the NFT-create role for [tokenIdentifier] from [oldCreator]
  /// to [newCreator]. Only valid when `canTransferNFTCreateRole` was set
  /// at issuance.
  Transaction createTransactionForTransferringNftCreateRole({
    required Address sender,
    required String tokenIdentifier,
    required Address oldCreator,
    required Address newCreator,
  }) {
    return _buildTransaction(
      sender: sender,
      functionName: 'transferNFTCreateRole',
      args: <TypedValue>[
        TokenIdentifierValue(tokenIdentifier),
        AddressValue(oldCreator.bytes),
        AddressValue(newCreator.bytes),
      ],
      executionGasLimit: config.gasLimitSetSpecialRole,
    );
  }

  /// Registers a token and sets all roles for the caller in a single tx
  /// with a dynamic variant (distinct from the non-dynamic helper).
  ///
  /// Only `META` carries a decimal precision. For dynamic `NFT` and `SFT` the
  /// ESDT system contract treats everything past the token type as property
  /// pairs, so appending a lone decimals argument makes the call fail on an
  /// odd argument count.
  ///
  /// #### Parameters
  /// - `sender` - Address that will own and manage the token
  /// - `tokenName` - Full token name
  /// - `tokenTicker` - Token ticker symbol
  /// - `tokenType` - One of `NFT`, `SFT`, `META`
  /// - `numDecimals` - Decimal precision, emitted only for `META`
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction with 0.05 EGLD payment
  ///
  /// #### Throws
  /// - `ArgumentError` - When `tokenType` is `FNG`, which cannot be dynamic, or
  ///   is not a recognised token type
  Transaction createTransactionForRegisteringAndSettingAllRolesDynamic({
    required Address sender,
    required String tokenName,
    required String tokenTicker,
    required String tokenType,
    int? numDecimals,
  }) {
    _validateTokenName(tokenName);
    _validateTokenTicker(tokenTicker);
    _validateDynamicTokenType(tokenType);

    final List<TypedValue> args = <TypedValue>[
      StringValue(tokenName),
      StringValue(tokenTicker),
      StringValue(tokenType),
      if (tokenType == tokenTypeMeta && numDecimals != null)
        BigUIntValue(BigInt.from(numDecimals)),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'registerAndSetAllRolesDynamic',
      args: args,
      value: Balance.fromString(config.issueCost),
      executionGasLimit: config.gasLimitRegisterDynamic,
    );
  }

  /// Upgrades an SFT collection to MetaESDT. [numDecimals] becomes the
  /// new decimal precision.
  Transaction createTransactionForChangingSftToMetaEsdt({
    required Address sender,
    required String tokenIdentifier,
    required int numDecimals,
  }) {
    return _buildTransaction(
      sender: sender,
      functionName: 'changeSFTToMetaESDT',
      args: <TypedValue>[
        TokenIdentifierValue(tokenIdentifier),
        U32Value(numDecimals),
      ],
      executionGasLimit: config.gasLimitSetSpecialRole,
    );
  }

  /// Refreshes the on-chain metadata for [tokenIdentifier] (post-hoc
  /// migration helper).
  Transaction createTransactionForUpdatingTokenId({
    required Address sender,
    required String tokenIdentifier,
  }) {
    return _buildTransaction(
      sender: sender,
      functionName: 'updateTokenID',
      args: <TypedValue>[TokenIdentifierValue(tokenIdentifier)],
      executionGasLimit: config.gasLimitUpdateTokenId,
    );
  }

  /// Validates token name format (3-20 alphanumeric characters).
  static void _validateTokenName(String tokenName) {
    if (!RegExp(r'^[A-Za-z0-9]{3,20}$').hasMatch(tokenName)) {
      throw ArgumentError.value(
        tokenName,
        'tokenName',
        'Token name must be 3-20 alphanumeric characters',
      );
    }
  }

  /// Validates token ticker format (3-10 uppercase alphanumeric characters).
  static void _validateTokenTicker(String tokenTicker) {
    if (!RegExp(r'^[A-Z0-9]{3,10}$').hasMatch(tokenTicker)) {
      throw ArgumentError.value(
        tokenTicker,
        'tokenTicker',
        'Token ticker must be 3-10 uppercase alphanumeric characters',
      );
    }
  }

  /// Validates a token type accepted by `registerAndSetAllRoles`.
  static void _validateTokenType(String tokenType) {
    if (!tokenTypes.contains(tokenType)) {
      throw ArgumentError.value(
        tokenType,
        'tokenType',
        'Token type must be one of NFT, SFT, META, FNG',
      );
    }
  }

  /// Validates a token type accepted by the dynamic registration endpoints,
  /// which reject fungible tokens outright.
  static void _validateDynamicTokenType(String tokenType) {
    if (tokenType == tokenTypeFungible) {
      throw ArgumentError.value(
        tokenType,
        'tokenType',
        'Cannot register fungible token as dynamic',
      );
    }
    if (!dynamicTokenTypes.contains(tokenType)) {
      throw ArgumentError.value(
        tokenType,
        'tokenType',
        'Token type must be one of NFT, SFT, META',
      );
    }
  }

  /// Encodes [props] as the `name`/`value` argument pairs the ESDT system
  /// contract expects.
  ///
  /// Every supported property is emitted, including the ones set to `false`.
  /// Omitting a pair does not mean "disabled": the contract creates a token
  /// with `canUpgrade` and `canAddSpecialRoles` already enabled and only
  /// overrides the properties actually present in the argument list, so a
  /// missing pair silently keeps the contract's own default. Emitting every
  /// pair is also what lets `controlChanges` switch a property back off.
  ///
  /// #### Parameters
  /// - `props` - Desired end state of every property
  /// - `includeTransferNftCreateRole` - Whether to emit
  ///   `canTransferNFTCreateRole`; it belongs to the collection endpoints and
  ///   is absent from the fungible `issue` argument list
  ///
  /// #### Returns
  /// `List<TypedValue>` - Ordered `name`, `value` pairs.
  List<TypedValue> _propertiesAsArgs(
    TokenProperties props, {
    required bool includeTransferNftCreateRole,
  }) {
    final List<TypedValue> args = <TypedValue>[];
    void emit(String name, bool flag) {
      args
        ..add(StringValue(name))
        ..add(StringValue(flag ? 'true' : 'false'));
    }

    emit('canFreeze', props.canFreeze);
    emit('canWipe', props.canWipe);
    emit('canPause', props.canPause);
    if (includeTransferNftCreateRole) {
      emit('canTransferNFTCreateRole', props.canTransferNFTCreateRole);
    }
    emit('canChangeOwner', props.canChangeOwner);
    emit('canUpgrade', props.canUpgrade);
    emit('canAddSpecialRoles', props.canAddSpecialRoles);
    return args;
  }

  /// Builds an unsigned token-management transaction.
  ///
  /// #### Parameters
  /// - `sender` - Address sending the transaction
  /// - `functionName` - System-contract endpoint or builtin-function name
  /// - `args` - Ordered, already-typed call arguments
  /// - `value` - EGLD attached to the call (defaults to zero)
  /// - `executionGasLimit` - Gas the system contract charges for the call
  ///   itself, excluding the data-movement gas this method adds on top
  /// - `receiverIsSender` - `true` for builtin functions, which execute
  ///   against the caller's own account and must therefore be addressed to
  ///   [sender] rather than to the ESDT system contract
  Transaction _buildTransaction({
    required Address sender,
    required String functionName,
    required List<TypedValue> args,
    Balance? value,
    required int executionGasLimit,
    bool receiverIsSender = false,
  }) {
    final ValuesToStringResult argsResult = _argSerializer.valuesToString(args);
    final List<String> dataParts = <String>[
      functionName,
      if (argsResult.count > 0) ...argsResult.argumentsString.split('@'),
    ];
    final Uint8List dataPayload = utf8.encode(dataParts.join('@'));
    final int dataMovementGas =
        config.minGasLimit + config.gasLimitPerByte * dataPayload.length;

    return Transaction(
      sender: sender,
      receiver: receiverIsSender ? sender : _esdtContractAddress,
      value: value ?? Balance.zero(),
      nonce: const Nonce(0),
      gasLimit: GasLimit(dataMovementGas + executionGasLimit),
      gasPrice: const GasPrice(defaultMinGasPrice),
      data: dataPayload,
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }
}
