---
id: keystore-wallets
title: Keystore Wallets
sidebar_position: 4
description: Create and decrypt password-protected MultiversX keystore wallet files following Web3 Secret Storage standard.
---

# Keystore Wallets

Keystore files are password-encrypted wallet files that provide secure storage for private keys. They follow the Web3 Secret Storage standard.

## What is a Keystore File?

A keystore is a JSON file containing:
- Encrypted private key
- Encryption parameters (cipher, KDF)
- Public address for verification

Example structure:
```json
{
  "version": 4,
  "id": "uuid...",
  "address": "erd1...",
  "bech32": "erd1...",
  "crypto": {
    "cipher": "aes-128-ctr",
    "cipherparams": { "iv": "..." },
    "ciphertext": "...",
    "kdf": "scrypt",
    "kdfparams": { ... },
    "mac": "..."
  }
}
```

## Load Account from Keystore

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:io';
import 'dart:convert';

void main() async {
  // Read keystore file
  final keystoreJson = await File('wallet.json').readAsString();
  final keystoreMap = jsonDecode(keystoreJson) as Map<String, dynamic>;
  
  // Decrypt with password to get secret key
  final secretKey = await UserWallet.decrypt(
    keystoreMap,
    'your-secure-password',
  );
  
  // Create account from secret key
  final account = await Account.fromSecretKey(secretKey);
  
  print('Address: ${account.address.bech32}');
}
```

Or use `Account.fromKeystore()` directly:

```dart
void main() async {
  final keystoreJson = await File('wallet.json').readAsString();
  
  final account = await Account.fromKeystore(
    keystoreJson,
    'your-secure-password',
  );
  
  print('Address: ${account.address.bech32}');
}
```

## Create a Keystore File

```dart
void main() async {
  // Generate a new secret key
  final secretKey = UserSecretKey.generate();
  
  // Create encrypted wallet
  final wallet = await UserWallet.fromSecretKey(
    secretKey: secretKey,
    password: 'your-secure-password',
  );
  
  // Save to file
  wallet.save('wallet.json', addressHrp: 'erd');
}
```

### Create Keystore from Mnemonic

You can also store the mnemonic itself encrypted:

```dart
void main() async {
  final mnemonic = Mnemonic.generate();
  final words = mnemonic.getWords().join(' ');
  
  // Create encrypted mnemonic wallet
  final wallet = UserWallet.fromMnemonic(
    mnemonic: words,
    password: 'your-secure-password',
  );
  
  // Save to file
  wallet.save('mnemonic-wallet.json');
  print('Mnemonic keystore saved');
  
  mnemonic.dispose();
}
```

## Password Requirements

:::tip Strong Passwords
For production keystores:
- Minimum 12 characters
- Mix of uppercase, lowercase, numbers, symbols
- Avoid dictionary words
- Consider using a password manager
:::

```dart
// Example: validate password strength
bool isStrongPassword(String password) {
  if (password.length < 12) return false;
  if (!password.contains(RegExp(r'[A-Z]'))) return false;
  if (!password.contains(RegExp(r'[a-z]'))) return false;
  if (!password.contains(RegExp(r'[0-9]'))) return false;
  if (!password.contains(RegExp(r'[!@#$%^&*]'))) return false;
  return true;
}
```

## Keystore Encryption Parameters

The keystore uses scrypt KDF with AES-128-CTR encryption:

| Parameter | Default | Description |
|-----------|---------|-------------|
| Cipher | AES-128-CTR | Symmetric encryption |
| KDF | scrypt | Key derivation function |
| N | 8192 | CPU/memory cost |
| r | 8 | Block size |
| p | 1 | Parallelization |
| dkLen | 32 | Derived key length |

## Web Wallet Compatibility

Keystore files are compatible with:
- MultiversX Web Wallet
- xPortal Mobile Wallet
- Ledger (via Web Wallet)

```dart
void main() async {
  // Load keystore downloaded from Web Wallet
  final account = await Account.fromKeystore(
    webWalletKeystoreJson,
    'wallet-password',
  );
  
  // Use in your app
  print('Loaded: ${account.address.bech32}');
}
```

## Load Secret Key Directly

Use `UserWallet.loadSecretKey()` to load directly from a file path:

```dart
void main() async {
  // Load from secretKey keystore
  final secretKey = await UserWallet.loadSecretKey(
    'wallet.json',
    'password',
  );
  
  // Load from mnemonic keystore (specify address index)
  final secretKey0 = await UserWallet.loadSecretKey(
    'mnemonic-wallet.json',
    'password',
    addressIndex: 0,
  );
  
  final secretKey1 = await UserWallet.loadSecretKey(
    'mnemonic-wallet.json',
    'password',
    addressIndex: 1,
  );
  
  // Create accounts
  final account0 = await Account.fromSecretKey(secretKey0);
  final account1 = await Account.fromSecretKey(secretKey1);
  
  print('Account 0: ${account0.address.bech32}');
  print('Account 1: ${account1.address.bech32}');
}
```

## Handling Errors

```dart
void main() async {
  try {
    final account = await Account.fromKeystore(
      keystoreJson,
      'password',
    );
    print('Success: ${account.address.bech32}');
  } on DecryptorException catch (e) {
    print('Decryption failed: ${e.message}');
    // Wrong password or corrupted keystore
  } on WalletException catch (e) {
    print('Wallet error: ${e.message}');
    // Invalid keystore format
  }
}
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:io';

void main() async {
  print('=== Keystore Wallet Demo ===\n');
  
  // 1. Generate new secret key
  final secretKey = UserSecretKey.generate();
  final publicKey = await secretKey.generatePublicKey();
  print('Created wallet: ${publicKey.toAddress().bech32}');
  
  // 2. Create encrypted keystore with password
  const password = 'MySecurePassword123!';
  final wallet = await UserWallet.fromSecretKey(
    secretKey: secretKey,
    password: password,
  );
  
  // 3. Save keystore
  const filePath = 'secure_wallet.json';
  wallet.save(filePath, addressHrp: 'erd');
  print('Saved keystore to: $filePath');
  
  // 4. Load from keystore
  final loadedKey = await UserWallet.loadSecretKey(filePath, password);
  final loadedPublicKey = await loadedKey.generatePublicKey();
  print('Loaded wallet: ${loadedPublicKey.toAddress().bech32}');
  
  // 5. Verify match
  assert(publicKey.hex == loadedPublicKey.hex);

  
  // 6. Test wrong password
  try {
    await UserWallet.loadSecretKey(filePath, 'wrong-password');
  } catch (e) {
    print('Expected error: $e');
  }
  
  // Cleanup
  await File(filePath).delete();
}
```

## Next Steps

- [Signing Transactions](/docs/wallet/signing-transactions) - Use your wallet
- [Transactions](/docs/transactions/overview) - Send transactions
- [Smart Contracts](/docs/smart-contracts/overview) - Interact with contracts
