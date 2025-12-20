/// Factory for creating token management transactions.
/// Provides low-level builders for ESDT token operations including issuance, roles, NFTs, and control.
import 'dart:convert';
import 'dart:typed_data';

import '../../../abi/abi.dart';
import '../../core.dart';

/// ESDT system smart contract address
const String esdtContractAddressHex =
    '000000000000000000010000000000000000000000000000000000000002ffff';

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
  final String issueCost; // In atomic units
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
    final List<TypedValue> args = <TypedValue>[
      StringValue(tokenName),
      StringValue(tokenTicker),
      BigUIntValue(initialSupply),
      BigUIntValue(BigInt.from(decimals)),
      ..._propertiesAsArgs(properties),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'issue',
      args: args,
      value: Balance.fromString(config.issueCost),
      gasLimit: config.gasLimitIssue,
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
    final List<TypedValue> args = <TypedValue>[
      StringValue(tokenName),
      StringValue(tokenTicker),
      ..._propertiesAsArgs(properties),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'issueSemiFungible',
      args: args,
      value: Balance.fromString(config.issueCost),
      gasLimit: config.gasLimitIssue,
    );
  }

  /// Creates transaction for issuing non-fungible ESDT token.
  Transaction createTransactionForIssuingNonFungible({
    required Address sender,
    required String tokenName,
    required String tokenTicker,
    TokenProperties properties = const TokenProperties(),
  }) {
    final List<TypedValue> args = <TypedValue>[
      StringValue(tokenName),
      StringValue(tokenTicker),
      ..._propertiesAsArgs(properties),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'issueNonFungible',
      args: args,
      value: Balance.fromString(config.issueCost),
      gasLimit: config.gasLimitIssue,
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
    final List<TypedValue> args = <TypedValue>[
      StringValue(tokenName),
      StringValue(tokenTicker),
      BigUIntValue(BigInt.from(decimals)),
      ..._propertiesAsArgs(properties),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'registerMetaESDT',
      args: args,
      value: Balance.fromString(config.issueCost),
      gasLimit: config.gasLimitIssue,
    );
  }

  /// Creates transaction for registering and setting all roles.
  Transaction createTransactionForRegisteringAndSettingRoles({
    required Address sender,
    required String tokenName,
    required String tokenTicker,
    required int decimals,
    TokenProperties properties = const TokenProperties(),
  }) {
    final List<TypedValue> args = <TypedValue>[
      StringValue(tokenName),
      StringValue(tokenTicker),
      BigUIntValue(BigInt.from(decimals)),
      ..._propertiesAsArgs(properties),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'registerAndSetAllRoles',
      args: args,
      value: Balance.fromString(config.issueCost),
      gasLimit: config.gasLimitIssue,
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
      gasLimit: config.gasLimitToggleBurnRoleGlobally,
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
      gasLimit: config.gasLimitToggleBurnRoleGlobally,
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
      gasLimit: config.gasLimitSetSpecialRole,
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
      gasLimit: config.gasLimitSetSpecialRole,
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
      gasLimit: config.gasLimitEsdtNftCreate + extraGas,
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
      gasLimit: config.gasLimitEsdtLocalMint,
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
      gasLimit: config.gasLimitEsdtLocalBurn,
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
      gasLimit: config.gasLimitEsdtNftUpdateAttributes + extraGas,
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
      gasLimit: config.gasLimitEsdtNftAddQuantity,
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
      gasLimit: config.gasLimitEsdtNftBurn,
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
      gasLimit: config.gasLimitPausing,
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
      gasLimit: config.gasLimitPausing,
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
      gasLimit: config.gasLimitFreezing,
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
      gasLimit: config.gasLimitFreezing,
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
      functionName: nonce > 0 ? 'wipeNFT' : 'wipe',
      args: args,
      gasLimit: config.gasLimitWiping,
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
      gasLimit: config.gasLimitEsdtModifyRoyalties,
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
      gasLimit: config.gasLimitSetNewUris + extraGas,
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
      gasLimit: config.gasLimitEsdtModifyCreator,
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
      gasLimit: config.gasLimitEsdtMetadataUpdate + extraGas,
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
      gasLimit: config.gasLimitNftMetadataRecreate + extraGas,
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
      gasLimit: config.gasLimitNftChangeToDynamic,
    );
  }

  /// Registers dynamic NFT.
  Transaction createTransactionForRegisteringDynamic({
    required Address sender,
    required String tokenName,
    required String tokenTicker,
    TokenProperties properties = const TokenProperties(),
  }) {
    final List<TypedValue> args = <TypedValue>[
      StringValue(tokenName),
      StringValue(tokenTicker),
      ..._propertiesAsArgs(properties),
    ];

    return _buildTransaction(
      sender: sender,
      functionName: 'registerDynamic',
      args: args,
      value: Balance.fromString(config.issueCost),
      gasLimit: config.gasLimitRegisterDynamic,
    );
  }

  List<TypedValue> _propertiesAsArgs(TokenProperties props) {
    return <TypedValue>[
      StringValue('canFreeze'),
      StringValue(props.canFreeze.toString()),
      StringValue('canWipe'),
      StringValue(props.canWipe.toString()),
      StringValue('canPause'),
      StringValue(props.canPause.toString()),
      if (props.canTransferNFTCreateRole) ...<TypedValue>[
        StringValue('canTransferNFTCreateRole'),
        StringValue('true'),
      ],
      StringValue('canChangeOwner'),
      StringValue(props.canChangeOwner.toString()),
      StringValue('canUpgrade'),
      StringValue(props.canUpgrade.toString()),
      StringValue('canAddSpecialRoles'),
      StringValue(props.canAddSpecialRoles.toString()),
    ];
  }

  Transaction _buildTransaction({
    required Address sender,
    required String functionName,
    required List<TypedValue> args,
    Balance? value,
    required int gasLimit,
  }) {
    final ValuesToStringResult argsResult = _argSerializer.valuesToString(args);
    final List<String> dataParts = <String>[
      functionName,
      if (argsResult.count > 0) ...argsResult.argumentsString.split('@'),
    ];
    final Uint8List dataPayload = utf8.encode(dataParts.join('@'));

    return Transaction(
      sender: sender,
      receiver: _esdtContractAddress,
      value: value ?? Balance.zero(),
      nonce: const Nonce(0),
      gasLimit: GasLimit(gasLimit),
      gasPrice: const GasPrice(defaultMinGasPrice),
      data: dataPayload,
      chainId: config.chainId,
      version: const TransactionVersion(1),
      signature: const Signature.empty(),
    );
  }
}
