---
id: account-management
title: Account Management
sidebar_position: 9
description: Manage MultiversX account storage, guardian 2FA protection, and account-level security operations.
---

# Account Management

Manage account storage, guardians (2FA), and account-level operations.

## Overview

The `AccountController` provides operations for:

- **Storage** - Save key-value pairs to account storage
- **Guardians** - Set up 2FA protection with guardian accounts
- **Account Protection** - Guard and unguard accounts

## AccountController

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

final controller = AccountController(
  chainId: const ChainId.devnet(),
  gasLimitEstimator: GasEstimator(networkProvider: provider),
);
```

## Account Storage

Save arbitrary data to your account's on-chain storage:

```dart
import 'dart:convert';
import 'dart:typed_data';

final account = await Account.fromPem('wallet.pem');
final accountInfo = await provider.getAccount(account.address);

// Prepare key-value pairs
final input = SaveKeyValueInput(
  keyValuePairs: {
    Uint8List.fromList(utf8.encode('username')): 
      Uint8List.fromList(utf8.encode('alice')),
    Uint8List.fromList(utf8.encode('preferences')): 
      Uint8List.fromList(utf8.encode('{"theme":"dark","lang":"en"}')),
  },
);

final tx = await controller.createTransactionForSavingKeyValue(
  account,
  accountInfo.nonce,
  input,
);

final hash = await provider.sendTransaction(tx);
print('Storage updated: $hash');
```

### Storage Use Cases

| Key | Value Example | Use Case |
|-----|---------------|----------|
| `username` | `alice` | Display name |
| `avatar` | `ipfs://Qm...` | Profile picture |
| `preferences` | `{"theme":"dark"}` | User settings |
| `metadata` | JSON object | Application data |

:::info Storage Costs
Each byte stored costs gas. Keep values concise for cost efficiency.
:::

## Guardian (2FA) Protection

Guardians provide two-factor authentication for accounts. When enabled, sensitive transactions require both the account signature and guardian co-signature.

### Set Guardian

Register a guardian for your account:

```dart
final guardianInput = SetGuardianInput(
  guardianAddress: Address.fromBech32('erd1guardian...'),
  serviceId: 'twikey-2fa', // 2FA service provider
);

final tx = await controller.createTransactionForSettingGuardian(
  account,
  accountInfo.nonce,
  guardianInput,
);

final hash = await provider.sendTransaction(tx);
print('Guardian set: $hash');
```

### Guard Account

Activate guardian protection:

```dart
final tx = await controller.createTransactionForGuardingAccount(
  account,
  accountInfo.nonce,
);

final hash = await provider.sendTransaction(tx);
print('Account is now guarded');
```

:::warning Protection Active
After guarding, sensitive transactions will fail without guardian co-signature.
:::

### Unguard Account

Remove guardian protection (requires guardian co-signature):

```dart
final tx = await controller.createTransactionForUnguardingAccount(
  account,
  accountInfo.nonce,
  options: BaseControllerInput(
    guardian: guardianAddress, // Guardian must co-sign
  ),
);

// Transaction needs guardian signature from 2FA service
final hash = await provider.sendTransaction(tx);
print('Account unguarded');
```

## Using Guardian with Controllers

When your account is guarded, pass the guardian in `BaseControllerInput`:

```dart
// Smart contract call with guardian
final scController = SmartContractController(
  contractAddress: contractAddress,
  networkProvider: provider,
  abi: myAbi,
);

final tx = await scController.call(
  account: account,
  nonce: accountInfo.nonce,
  endpointName: 'withdraw',
  arguments: [BigInt.from(1000)],
  options: BaseControllerInput(
    gasLimit: GasLimit(10000000),
    guardian: guardianAddress, // Include guardian for co-signing
  ),
);

// Transaction will be prepared for guardian co-signature
```

### Token Transfer with Guardian

```dart
final transferController = TransfersController(
  chainId: const ChainId.mainnet(),
);

final tx = await transferController.createTransactionForTokenTransfer(
  account,
  accountInfo.nonce,
  TokenTransferInput(
    receiver: recipient,
    transfers: [
      TokenTransfer.fungible(
        tokenIdentifier: 'USDC-c76f1f',
        amount: BigInt.from(1000000), // 1 USDC (6 decimals)
      ),
    ],
  ),
  baseOptions: BaseControllerInput(
    guardian: guardianAddress,
  ),
);
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  
  final controller = AccountController(
    chainId: const ChainId.devnet(),
    gasLimitEstimator: GasEstimator(networkProvider: provider),
  );
  
  var accountInfo = await provider.getAccount(account.address);
  
  // 1. Save profile data
  final storageInput = SaveKeyValueInput(
    keyValuePairs: {
      Uint8List.fromList(utf8.encode('profile')): 
        Uint8List.fromList(utf8.encode('{"name":"Alice","joined":"2024"}')),
    },
  );
  
  var tx = await controller.createTransactionForSavingKeyValue(
    account,
    accountInfo.nonce,
    storageInput,
  );
  await provider.sendTransaction(tx);
  print('Profile saved');
  
  // 2. Set up guardian (optional)
  accountInfo = await provider.getAccount(account.address);
  
  final guardianAddress = Address.fromBech32('erd1guardian...');
  final guardianInput = SetGuardianInput(
    guardianAddress: guardianAddress,
    serviceId: 'my-2fa-service',
  );
  
  tx = await controller.createTransactionForSettingGuardian(
    account,
    accountInfo.nonce,
    guardianInput,
  );
  await provider.sendTransaction(tx);
  print('Guardian configured');
  
  // 3. Activate guardian protection
  accountInfo = await provider.getAccount(account.address);
  
  tx = await controller.createTransactionForGuardingAccount(
    account,
    accountInfo.nonce,
  );
  await provider.sendTransaction(tx);
  print('Account is now protected by 2FA');
}
```

## Guardian Service Providers

Guardian services handle the 2FA authentication:

| Service | Description |
|---------|-------------|
| `twikey-2fa` | Twikey 2FA service |
| Custom | Your own guardian service |

## Best Practices

1. **Backup Guardian** - Ensure you can access guardian service before activating
2. **Test First** - Test guardian flow on devnet before mainnet
3. **Storage Keys** - Use consistent key naming conventions
4. **JSON Values** - Store structured data as JSON for flexibility
5. **Guardian Security** - Guardian address should be highly secure

## Security Considerations

- Guardian protection adds security but also complexity
- Lost guardian access can lock your account
- Consider using hardware wallets for guardian accounts
- Test unguard flow before activating on mainnet
