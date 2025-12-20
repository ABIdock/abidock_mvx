---
id: delegation-staking
title: Delegation & Staking
sidebar_position: 8
description: Manage delegation contracts, validator nodes, staking operations, and rewards claiming on MultiversX.
---

# Delegation & Staking

Manage delegation contracts, validator nodes, and staking operations on MultiversX.

## Overview

The `DelegationController` provides an API for:

- **Validator Operations** - Create delegation contracts, manage validator nodes
- **Delegator Operations** - Stake, unstake, claim rewards
- **Contract Management** - Configure fees, caps, and metadata

## DelegationController

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

final controller = DelegationController(
  chainId: const ChainId.mainnet(),
  gasLimitEstimator: GasEstimator(networkProvider: provider),
);
```

## Validator Operations

### Create Delegation Contract

Create a new staking provider contract:

```dart
final account = await Account.fromPem('validator.pem');
final accountInfo = await provider.getAccount(account.address);

final input = NewDelegationContractInput(
  totalDelegationCap: BigInt.from(10000000) * BigInt.from(10).pow(18), // 10M EGLD cap
  serviceFee: BigInt.from(1000), // 10% fee (10000 = 100%)
  amount: Balance.fromEgld(1250), // 1250 EGLD initial stake
);

final tx = await controller.createTransactionForNewDelegationContract(
  account,
  accountInfo.nonce,
  input,
);

final hash = await provider.sendTransaction(tx);
print('Delegation contract created: $hash');
```

:::info Minimum Requirements
- Minimum 1250 EGLD to create a delegation contract
- Service fee is in basis points (1000 = 10%, 10000 = 100%)
:::

### Add Validator Nodes

Add BLS keys to your delegation contract:

```dart
// Load validator keys
final validatorKey = ValidatorSecretKey.fromPem('validator_key.pem');

// Sign the delegation contract address
final signedMessage = validatorKey.sign(delegationContract.publicKeyBytes);

final input = AddNodesInput(
  delegationContract: delegationContract,
  publicKeys: [validatorKey.publicKey],
  signedMessages: [signedMessage],
);

final tx = await controller.createTransactionForAddingNodes(
  account,
  accountInfo.nonce,
  input,
);
```

### Stake Nodes

Activate validator nodes for consensus:

```dart
final input = ManageNodesInput(
  delegationContract: delegationContract,
  publicKeys: [validatorPublicKey1, validatorPublicKey2],
);

final tx = await controller.createTransactionForStakingNodes(
  account,
  accountInfo.nonce,
  input,
);
```

### Unstake Nodes

Remove nodes from active validation:

```dart
final input = ManageNodesInput(
  delegationContract: delegationContract,
  publicKeys: [validatorPublicKey],
);

final tx = await controller.createTransactionForUnstakingNodes(
  account,
  accountInfo.nonce,
  input,
);
```

### Unbond Nodes

Complete unbonding after unstaking period:

```dart
final input = ManageNodesInput(
  delegationContract: delegationContract,
  publicKeys: [validatorPublicKey],
);

final tx = await controller.createTransactionForUnbondingNodes(
  account,
  accountInfo.nonce,
  input,
);
```

### Remove Nodes

Remove validator keys from contract:

```dart
final input = ManageNodesInput(
  delegationContract: delegationContract,
  publicKeys: [validatorPublicKey],
);

final tx = await controller.createTransactionForRemovingNodes(
  account,
  accountInfo.nonce,
  input,
);
```

### Unjail Nodes

Unjail slashed validator nodes:

```dart
final input = UnjailingNodesInput(
  delegationContract: delegationContract,
  publicKeys: [jailedValidatorKey],
  amount: Balance.fromEgld(2.5), // Unjail fee
);

final tx = await controller.createTransactionForUnjailingNodes(
  account,
  accountInfo.nonce,
  input,
);
```

## Contract Configuration

### Change Service Fee

```dart
final input = ChangeServiceFeeInput(
  delegationContract: delegationContract,
  serviceFee: BigInt.from(1500), // Change to 15%
);

final tx = await controller.createTransactionForChangingServiceFee(
  account,
  accountInfo.nonce,
  input,
);
```

### Modify Delegation Cap

```dart
final input = ModifyDelegationCapInput(
  delegationContract: delegationContract,
  delegationCap: BigInt.from(5000000) * BigInt.from(10).pow(18), // 5M EGLD
);

final tx = await controller.createTransactionForModifyingDelegationCap(
  account,
  accountInfo.nonce,
  input,
);
```

### Set Metadata

```dart
final input = SetMetadataInput(
  delegationContract: delegationContract,
  name: 'My Staking Provider',
  website: 'https://mystaking.com',
  identifier: 'mystaking',
);

final tx = await controller.createTransactionForSettingMetadata(
  account,
  accountInfo.nonce,
  input,
);
```

### Automatic Activation

Enable/disable automatic node activation:

```dart
final input = ManageDelegationContractInput(
  delegationContract: delegationContract,
);

// Enable
final enableTx = await controller.createTransactionForSettingAutomaticActivation(
  account,
  accountInfo.nonce,
  input,
);

// Disable
final disableTx = await controller.createTransactionForUnsettingAutomaticActivation(
  account,
  accountInfo.nonce,
  input,
);
```

### Cap Check on Redelegate

Control whether delegation cap applies to reward redelegation:

```dart
final input = ManageDelegationContractInput(
  delegationContract: delegationContract,
);

// Enable cap check
final enableTx = await controller.createTransactionForSettingCapCheckOnRedelegateRewards(
  account,
  accountInfo.nonce,
  input,
);

// Disable cap check
final disableTx = await controller.createTransactionForUnsettingCapCheckOnRedelegateRewards(
  account,
  accountInfo.nonce,
  input,
);
```

## Delegator Operations

### Delegate EGLD

Stake EGLD with a staking provider:

```dart
final input = DelegateInput(
  delegationContract: Address.fromBech32('erd1qqqqqqqqqqqqqpgq...'),
  amount: Balance.fromEgld(100), // Delegate 100 EGLD
);

final tx = await controller.createTransactionForDelegating(
  account,
  accountInfo.nonce,
  input,
);

final hash = await provider.sendTransaction(tx);
print('Delegated: $hash');
```

### Undelegate EGLD

Initiate unstaking (10-day unbonding period):

```dart
final input = UndelegateInput(
  delegationContract: delegationContract,
  amount: Balance.fromEgld(50), // Undelegate 50 EGLD
);

final tx = await controller.createTransactionForUndelegating(
  account,
  accountInfo.nonce,
  input,
);
```

### Withdraw Funds

Claim unbonded EGLD after unbonding period:

```dart
final input = WithdrawInput(
  delegationContract: delegationContract,
);

final tx = await controller.createTransactionForWithdrawing(
  account,
  accountInfo.nonce,
  input,
);
```

### Claim Rewards

Claim accumulated staking rewards:

```dart
final input = WithdrawInput(
  delegationContract: delegationContract,
);

final tx = await controller.createTransactionForClaimingRewards(
  account,
  accountInfo.nonce,
  input,
);
```

### Redelegate Rewards

Automatically restake rewards:

```dart
final input = WithdrawInput(
  delegationContract: delegationContract,
);

final tx = await controller.createTransactionForRedelegatingRewards(
  account,
  accountInfo.nonce,
  input,
);
```

## Parsing Outcomes

Use `DelegationOutcomeParser` to extract results:

```dart
final parser = DelegationOutcomeParser();

// Parse delegation contract creation
final tx = await provider.getTransaction(hash);
final results = parser.parseCreateNewDelegationContract(tx);

for (final result in results) {
  print('Contract address: ${result.contractAddress}');
}
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final provider = GatewayNetworkProvider.mainnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  
  final controller = DelegationController(
    chainId: const ChainId.mainnet(),
    gasLimitEstimator: GasEstimator(networkProvider: provider),
  );
  
  // Get account info
  final accountInfo = await provider.getAccount(account.address);
  
  // Choose a staking provider
  final stakingProvider = Address.fromBech32('erd1qqqqqqqqqqqqqpgq...');
  
  // Delegate 100 EGLD
  final delegateTx = await controller.createTransactionForDelegating(
    account,
    accountInfo.nonce,
    DelegateInput(
      delegationContract: stakingProvider,
      amount: Balance.fromEgld(100),
    ),
  );
  
  final hash = await provider.sendTransaction(delegateTx);
  print('Delegated: $hash');
  
  // Wait for rewards to accumulate...
  
  // Claim rewards
  final claimTx = await controller.createTransactionForClaimingRewards(
    account,
    accountInfo.nonce.increment(),
    WithdrawInput(delegationContract: stakingProvider),
  );
  
  await provider.sendTransaction(claimTx);
  print('Rewards claimed!');
}
```

## Service Fee Reference

| Fee (basis points) | Percentage |
|-------------------|------------|
| 500 | 5% |
| 1000 | 10% |
| 1500 | 15% |
| 2000 | 20% |
| 10000 | 100% |

## Important Notes

1. **Unbonding Period** - Undelegated funds have a 10-day unbonding period
2. **Minimum Stake** - Check provider's minimum delegation requirement
3. **Rewards** - Rewards accumulate continuously and can be claimed anytime
4. **Validator Keys** - Keep validator secret keys secure and backed up
5. **Slashing** - Jailed nodes require unjail fee and may lose rewards
