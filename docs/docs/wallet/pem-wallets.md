---
id: pem-wallets
title: PEM Wallets
sidebar_position: 3
description: Load MultiversX accounts from PEM files for development, testing, and automated server scripts.
---

# PEM Wallets

PEM (Privacy Enhanced Mail) files are a common format for storing cryptographic keys. They're widely used in MultiversX development and testing.

## What is a PEM File?

A PEM file contains the private key encoded in base64:

```
-----BEGIN PRIVATE KEY for erd1abc...-----
NTYzMjEw...base64 encoded key...MTIzNDU2
-----END PRIVATE KEY for erd1abc...-----
```

:::caution Security Warning
PEM files contain your private key in an easily readable format. They are NOT encrypted. Use only for:
- Development and testing
- Automated scripts on secure servers
- Never for user-facing applications
:::

## Load Account from PEM File

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:io';

void main() async {
  // Read PEM content from file
  final pemContent = await File('path/to/wallet.pem').readAsString();
  
  // Create account from PEM
  final account = await Account.fromPem(pemContent);
  
  print('Address: ${account.address.bech32}');
}
```

## Load from PEM String

```dart
void main() async {
  final pemContent = '''
-----BEGIN PRIVATE KEY for erd1...-----
NTYzMjEw...
-----END PRIVATE KEY for erd1...-----
''';

  final account = await Account.fromPem(pemContent);
  print('Address: ${account.address.bech32}');
}
```

## Parse PEM to Secret Key

For more control, use `UserSecretKey.fromPem()` directly:

```dart
void main() async {
  final pemContent = await File('wallet.pem').readAsString();
  
  // Parse to secret key
  final secretKey = UserSecretKey.fromPem(pemContent);
  
  // Generate public key and address
  final publicKey = await secretKey.generatePublicKey();
  final address = publicKey.toAddress();
  
  print('Address: ${address.bech32}');
  
  // Create signer for transactions
  final signer = UserSigner(secretKey);
}
```

## PEM File Format Details

The MultiversX PEM format includes:

1. **Header**: `-----BEGIN PRIVATE KEY for erd1...-----`
2. **Body**: Base64-encoded secret key (64 bytes = 32 byte seed + 32 byte public key)
3. **Footer**: `-----END PRIVATE KEY for erd1...-----`

```dart
// Parse PEM manually if needed
void parsePem(String pemContent) {
  final lines = pemContent.split('\n');
  
  // Extract address from header
  final header = lines.first;
  final addressMatch = RegExp(r'erd1[a-z0-9]+').firstMatch(header);
  print('Address: ${addressMatch?.group(0)}');
  
  // The body contains the secret key
  final body = lines
      .where((l) => !l.startsWith('-----'))
      .join('');
  print('Key (base64): $body');
}
```

## Multiple Wallets in One File

Some tools generate PEM files with multiple wallets. Load a specific one by index:

```dart
void main() async {
  final pemContent = await File('wallets.pem').readAsString();
  
  // Load specific wallet by index
  final account0 = await Account.fromPem(pemContent, index: 0);
  final account1 = await Account.fromPem(pemContent, index: 1);
  
  print('Wallet 0: ${account0.address.bech32}');
  print('Wallet 1: ${account1.address.bech32}');
}
```

Or parse all keys manually:

```dart
void main() async {
  final pemContent = await File('wallets.pem').readAsString();
  
  // Parse all keys
  final keys = parseUserKeys(pemContent);
  
  for (var i = 0; i < keys.length; i++) {
    final publicKey = await keys[i].generatePublicKey();
    final address = publicKey.toAddress();
    print('Wallet $i: ${address.bech32}');
  }
}
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:io';

void main() async {
  print('=== PEM Wallet Demo ===\n');
  
  // 1. Generate a new secret key
  final secretKey = UserSecretKey.generate();
  final publicKey = await secretKey.generatePublicKey();
  final address = publicKey.toAddress();
  print('Generated wallet: ${address.bech32}');
  
  // 2. Create Account from secret key
  final account = await Account.fromSecretKey(secretKey);
  print('Account address: ${account.address.bech32}');
  
  // 3. If you have an existing PEM file
  // final pemContent = await File('wallet.pem').readAsString();
  // final loadedAccount = await Account.fromPem(pemContent);
  // print('Loaded address: ${loadedAccount.address.bech32}');
  
  // Note: abidock_mvx doesn't currently support exporting to PEM format
  // Use keystores for saving encrypted wallets
}
```

## Next Steps

- [Keystore Wallets](/docs/wallet/keystore-wallets) - Encrypted wallet storage
- [Signing Transactions](/docs/wallet/signing-transactions) - Sign with your wallet
- [Transactions](/docs/transactions/overview) - Send transactions
