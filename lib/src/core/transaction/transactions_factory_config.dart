import 'package:meta/meta.dart';

import 'chain_id.dart';

/// Aggregate configuration consumed by every transactions factory.
///
/// Every gas field defaults to the value the corresponding system-contract
/// call costs on the public networks, so passing only [chainId] and
/// [addressHrp] yields transactions the chain accepts.
///
/// This type is additive: existing per-factory configs continue to work and
/// remain canonical for the moment. Use [TransactionsFactoryConfig] when you
/// want one shared bag of gas constants for all factories spun up by
/// `NetworkEntrypoint`.
///
/// #### Example
/// ```dart
/// const config = TransactionsFactoryConfig(
///   chainId: ChainId('D'),
///   addressHrp: 'erd',
/// );
/// print(config.gasLimitEsdtTransfer); // 200000
/// ```
@immutable
class TransactionsFactoryConfig {
  /// Creates a transactions factory configuration with network defaults.
  ///
  /// #### Parameters
  /// - `chainId` - Target chain id (e.g. `ChainId.mainnet()`).
  /// - `addressHrp` - Human-readable part used for bech32 addresses.
  const TransactionsFactoryConfig({
    required this.chainId,
    this.addressHrp = 'erd',
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
    this.gasLimitStorePerByte = 50000,
    this.gasLimitEsdtModifyRoyalties = 60000000,
    this.gasLimitEsdtModifyCreator = 60000000,
    this.gasLimitEsdtMetadataUpdate = 60000000,
    this.gasLimitSetNewUris = 60000000,
    this.gasLimitNftMetadataRecreate = 60000000,
    this.gasLimitNftChangeToDynamic = 60000000,
    this.gasLimitUpdateTokenId = 60000000,
    this.gasLimitRegisterDynamic = 60000000,
    this.gasLimitTransferOwnership = 60000000,
    this.gasLimitFreezeSingleNft = 60000000,
    this.gasLimitWipeSingleNft = 60000000,
    this.gasLimitEsdtTransfer = 200000,
    this.gasLimitEsdtNftTransfer = 200000,
    this.gasLimitMultiEsdtNftTransfer = 200000,
    this.gasLimitSetGuardian = 250000,
    this.gasLimitGuardAccount = 250000,
    this.gasLimitUnguardAccount = 250000,
    this.gasLimitStake = 5000000,
    this.gasLimitUnstake = 5000000,
    this.gasLimitUnbond = 5000000,
    this.gasLimitCreateDelegationContract = 50000000,
    this.gasLimitDelegationOperations = 1000000,
    this.gasLimitProposal = 50000000,
    this.gasLimitVote = 5000000,
    this.gasLimitClearEndedProposals = 50000000,
    this.gasLimitClaimAccumulatedFees = 1000000,
    this.gasLimitChangeConfig = 50000000,
    this.gasLimitClaimDeveloperRewards = 6000000,
    this.gasLimitChangeOwnerAddress = 6000000,
    this.gasLimitUnstakeTokens = 5000000,
    this.gasLimitUnbondTokens = 5000000,
    this.gasLimitCleanRegisteredData = 5000000,
    this.gasLimitRestakeUnstakedNodes = 5000000,
    this.gasLimitGenericAction = 1000000,
    this.additionalGasLimitPerValidatorNode = 6000000,
    this.additionalGasLimitForDelegationOperations = 10000000,
    this.extraGasLimitForGuardedTransactions = 50000,
    this.extraGasLimitForRelayedTransactions = 50000,
    this.gasLimitForMultisigOperations = 1000000,
    this.gasLimitForCreatePosting = 50000000,
    this.gasLimitForCreatePostingSetCodeMetadata = 50000000,
  });

  /// Target chain id forwarded to every per-factory config.
  final ChainId chainId;

  /// HRP used for bech32 encoding of contract / owner addresses.
  final String addressHrp;

  /// Floor for transaction gas-limit.
  final int minGasLimit;

  /// Gas cost per byte of the `data` field.
  final int gasLimitPerByte;

  /// Gas for the `issue` family of system-SC calls.
  final int gasLimitIssue;

  /// Gas for `setBurnRoleGlobally` / `unsetBurnRoleGlobally`.
  final int gasLimitToggleBurnRoleGlobally;

  /// Gas for `ESDTLocalMint`.
  final int gasLimitEsdtLocalMint;

  /// Gas for `ESDTLocalBurn`.
  final int gasLimitEsdtLocalBurn;

  /// Gas for `setSpecialRole`.
  final int gasLimitSetSpecialRole;

  /// Gas for `pause` / `unPause`.
  final int gasLimitPausing;

  /// Gas for `freeze` / `unFreeze`.
  final int gasLimitFreezing;

  /// Gas for `wipe`.
  final int gasLimitWiping;

  /// Gas for `ESDTNFTCreate`.
  final int gasLimitEsdtNftCreate;

  /// Gas for `ESDTNFTUpdateAttributes`.
  final int gasLimitEsdtNftUpdateAttributes;

  /// Gas for `ESDTNFTAddQuantity`.
  final int gasLimitEsdtNftAddQuantity;

  /// Gas for `ESDTNFTBurn`.
  final int gasLimitEsdtNftBurn;

  /// Per-byte cost when persisting NFT metadata in storage.
  final int gasLimitStorePerByte;

  /// Gas for `ESDTModifyRoyalties`.
  final int gasLimitEsdtModifyRoyalties;

  /// Gas for `ESDTModifyCreator`.
  final int gasLimitEsdtModifyCreator;

  /// Gas for `ESDTMetaDataUpdate`.
  final int gasLimitEsdtMetadataUpdate;

  /// Gas for `ESDTSetNewURIs`.
  final int gasLimitSetNewUris;

  /// Gas for `ESDTMetaDataRecreate`.
  final int gasLimitNftMetadataRecreate;

  /// Gas for `changeToDynamic`.
  final int gasLimitNftChangeToDynamic;

  /// Gas for `updateTokenID`.
  final int gasLimitUpdateTokenId;

  /// Gas for `registerDynamic`.
  final int gasLimitRegisterDynamic;

  /// Gas for `transferOwnership` on issued ESDTs.
  final int gasLimitTransferOwnership;

  /// Gas for `freezeSingleNFT`.
  final int gasLimitFreezeSingleNft;

  /// Gas for `wipeSingleNFT`.
  final int gasLimitWipeSingleNft;

  /// Gas for `ESDTTransfer`.
  final int gasLimitEsdtTransfer;

  /// Gas for `ESDTNFTTransfer`.
  final int gasLimitEsdtNftTransfer;

  /// Gas for `MultiESDTNFTTransfer`.
  final int gasLimitMultiEsdtNftTransfer;

  /// Gas for `SetGuardian`.
  final int gasLimitSetGuardian;

  /// Gas for `GuardAccount`.
  final int gasLimitGuardAccount;

  /// Gas for `UnGuardAccount`.
  final int gasLimitUnguardAccount;

  /// Gas for `stake`.
  final int gasLimitStake;

  /// Gas for `unStake`.
  final int gasLimitUnstake;

  /// Gas for `unBond`.
  final int gasLimitUnbond;

  /// Gas for `createNewDelegationContract`.
  final int gasLimitCreateDelegationContract;

  /// Gas for generic delegation operations.
  final int gasLimitDelegationOperations;

  /// Gas for governance `proposal`.
  final int gasLimitProposal;

  /// Gas for governance `vote`.
  final int gasLimitVote;

  /// Gas for governance `clearEndedProposals`.
  final int gasLimitClearEndedProposals;

  /// Gas for governance `claimAccumulatedFees`.
  final int gasLimitClaimAccumulatedFees;

  /// Gas for governance `changeConfig`.
  final int gasLimitChangeConfig;

  /// Gas for `ClaimDeveloperRewards`.
  final int gasLimitClaimDeveloperRewards;

  /// Gas for `ChangeOwnerAddress`.
  final int gasLimitChangeOwnerAddress;

  /// Gas for `unStakeTokens` (validators).
  final int gasLimitUnstakeTokens;

  /// Gas for `unBondTokens` (validators).
  final int gasLimitUnbondTokens;

  /// Gas for `cleanRegisteredData` (validators).
  final int gasLimitCleanRegisteredData;

  /// Gas for `reStakeUnStakedNodes` (validators).
  final int gasLimitRestakeUnstakedNodes;

  /// Gas for generic builder-shaped actions (used by multisig propose / sign).
  final int gasLimitGenericAction;

  /// Additional gas added per validator node when staking/unstaking.
  final int additionalGasLimitPerValidatorNode;

  /// Additional gas added for delegation operations.
  final int additionalGasLimitForDelegationOperations;

  /// Extra gas required when a transaction is guarded.
  final int extraGasLimitForGuardedTransactions;

  /// Extra gas required when a transaction is relayed.
  final int extraGasLimitForRelayedTransactions;

  /// Default gas for multisig contract calls.
  final int gasLimitForMultisigOperations;

  /// Gas used by community-contributed "create posting" demos.
  final int gasLimitForCreatePosting;

  /// Gas for create-posting `setCodeMetadata`.
  final int gasLimitForCreatePostingSetCodeMetadata;
}
