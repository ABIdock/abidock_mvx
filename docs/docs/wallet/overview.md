---
id: overview
title: Wallet Overview
sidebar_position: 1
description: Overview of MultiversX wallet types including mnemonic, PEM, and keystore with security considerations.
---

# Wallet Management

abidock_mvx supports mnemonic, PEM, and keystore wallets.

## Wallet Types

| Type | Use Case | Security |
|------|----------|----------|
| **Mnemonic** | User wallets, HD derivation | High - 24 words |
| **PEM** | Development, testing | Medium - file-based |
| **Keystore** | Encrypted storage | High - password protected |

## Quick Comparison

```dart
// From Mnemonic (recommended for users)
final account = await Account.fromMnemonic('word1 word2 ... word24');

// From PEM file (development)
final account = await Account.fromPem(pemContent);

// From Keystore (encrypted)
final account = await Account.fromKeystore(keystoreJson, 'password');
```

## Account Properties

Every account provides:

```dart
// The public address
final address = account.address;
print(address.bech32); // erd1...

// The secret key for signing
final secretKey = account.secretKey;

// The public key
final publicKey = account.publicKey;
```

## Signing Transactions

All account types can sign transactions directly:

```dart
// Sign a transaction
final signature = await account.signTransaction(transaction);
final signed = transaction.copyWith(
  newSignature: Signature.fromUint8List(signature),
);

// The signature is now attached to the transaction
print(signed.signature);

// Or use UserSigner for more control
final signer = UserSigner(account.secretKey);
```

## HD Wallet Derivation

For mnemonic wallets, you can derive multiple accounts:

```dart
final mnemonic = Mnemonic.generate();

// Default account (index 0)
final account0 = await Account.fromMnemonic(mnemonic.getWords().join(' '));

// Second account (index 1)
final account1 = await Account.fromMnemonic(
  mnemonic.getWords().join(' '),
  addressIndex: 1,
);

// Third account (index 2)
final account2 = await Account.fromMnemonic(
  mnemonic.getWords().join(' '),
  addressIndex: 2,
);
```

## Security Best Practices

:::caution Never Expose Keys
- Never log secret keys or mnemonics
- Never commit keys to source control
- Never transmit keys over unencrypted channels
:::

:::tip Secure Storage
- Use encrypted storage for production apps
- Consider using platform-specific secure storage
- For Flutter: use `flutter_secure_storage` package
:::

## Next Steps

- [Mnemonic Wallets](/docs/wallet/mnemonic-wallets) - Create wallets from seed phrases
- [PEM Wallets](/docs/wallet/pem-wallets) - Development and testing
- [Keystore Wallets](/docs/wallet/keystore-wallets) - Encrypted wallet storage
- [Signing Transactions](/docs/wallet/signing-transactions) - Sign and verify
