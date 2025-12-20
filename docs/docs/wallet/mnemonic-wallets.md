---
id: mnemonic-wallets
title: Mnemonic Wallets
sidebar_position: 2
description: Generate and recover MultiversX wallets using BIP39 mnemonic seed phrases with HD derivation paths.
---

# Mnemonic Wallets

Mnemonic wallets use BIP39 seed phrases to generate and recover wallets. BIP39 is widely supported by MultiversX wallets.

## Generate a New Mnemonic

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  // Generate a new 24-word mnemonic
  final mnemonic = Mnemonic.generate();
  
  // Get the words as a list
  final words = mnemonic.getWords();
  print('Mnemonic: ${words.join(' ')}');
  // Output: abandon abandon abandon ... (24 words)
  
  // Validate a mnemonic string
  print('Valid: ${Mnemonic.isValid(words.join(' '))}');
  
  // Derive a secret key
  final secretKey = await mnemonic.deriveKey(addressIndex: 0);
  
  // Create signer to get address
  final signer = UserSigner(secretKey);
  final address = await signer.getAddress();
  print('Address: ${address.bech32}');
  
  // Clean up when done
  mnemonic.dispose();
}
```

:::caution Backup Your Mnemonic
The mnemonic is the ONLY way to recover your wallet. Store it securely:
- Write it on paper and store in a safe place
- Never store digitally unless encrypted
- Never share with anyone
:::

## Create Account from Mnemonic

The `Account` class provides a convenient way to work with wallets:

```dart
void main() async {
  // From existing mnemonic phrase
  final account = await Account.fromMnemonic(
    'word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12 word13 word14 word15 word16 word17 word18 word19 word20 word21 word22 word23 word24',
  );
  
  print('Address: ${account.address.bech32}');
}
```

## HD Derivation Path

MultiversX uses the BIP44 derivation path:

```
m/44'/508'/0'/0'/index'
```

Where:
- `44'` = BIP44 purpose
- `508'` = MultiversX coin type
- `0'` = Account
- `0'` = Change
- `index'` = Address index

### Derive Multiple Accounts

```dart
void main() async {
  final mnemonic = Mnemonic.generate();
  final words = mnemonic.getWords().join(' ');
  
  // Derive multiple accounts from the same mnemonic
  for (var i = 0; i < 5; i++) {
    final account = await Account.fromMnemonic(
      words,
      addressIndex: i,
    );
    print('Account $i: ${account.address.bech32}');
  }
  
  mnemonic.dispose();
}
```

Output:
```
Account 0: erd1abc...
Account 1: erd1def...
Account 2: erd1ghi...
Account 3: erd1jkl...
Account 4: erd1mno...
```

## Validate a Mnemonic

```dart
void main() {
  final phrase = 'word1 word2 ... word24';
  
  // Static validation without creating instance
  if (Mnemonic.isValid(phrase)) {
    print('Valid mnemonic');
    final mnemonic = Mnemonic.fromString(phrase);
    // Use mnemonic...
    mnemonic.dispose();
  } else {
    print('Invalid mnemonic');
  }
}
```

## Using Mnemonic Directly

For more control, use the `Mnemonic` class directly:

```dart
void main() async {
  // Generate new mnemonic
  final mnemonic = Mnemonic.generate();
  
  // Get words
  final words = mnemonic.getWords();
  print('Word count: ${words.length}'); // 24
  
  // Derive keys at different indices
  final key0 = await mnemonic.deriveKey(addressIndex: 0);
  final key1 = await mnemonic.deriveKey(addressIndex: 1);
  
  // Create signers
  final signer0 = UserSigner(key0);
  final signer1 = UserSigner(key1);
  
  // Get addresses
  final addr0 = await signer0.getAddress();
  final addr1 = await signer1.getAddress();
  
  print('Address 0: ${addr0.bech32}');
  print('Address 1: ${addr1.bech32}');
  
  // Always dispose when done
  mnemonic.dispose();
}
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  // Generate new mnemonic
  final mnemonic = Mnemonic.generate();
  final words = mnemonic.getWords();
  
  print('Mnemonic:');
  for (var i = 0; i < words.length; i++) {
    print('  ${i + 1}. ${words[i]}');
  }
  print('');
  
  // Create account
  final secretKey = await mnemonic.deriveKey(addressIndex: 0);
  final account = await Account.fromSecretKey(secretKey);
  
  print('Address: ${account.address.bech32}');
  print('Public Key: ${account.publicKey.hex}');
  print('');
  
  // Derive additional accounts
  print('Derived Accounts:');
  for (var i = 0; i < 3; i++) {
    final key = await mnemonic.deriveKey(addressIndex: i);
    final acc = await Account.fromSecretKey(key);
    print('  [$i] ${acc.address.bech32}');
  }
  
  // Cleanup
  mnemonic.dispose();
}
```

## Security Tips

:::tip Best Practices
1. **Generate offline** - Create mnemonics on air-gapped devices when possible
2. **Verify words** - Double-check each word when backing up
3. **Test recovery** - Before funding, test that you can restore from the mnemonic
4. **Use 24 words** - Maximum security for significant funds
5. **Call dispose()** - Always dispose mnemonic to clear from memory
:::

## Next Steps

- [PEM Wallets](/docs/wallet/pem-wallets) - File-based wallets for development
- [Keystore Wallets](/docs/wallet/keystore-wallets) - Password-protected wallets
- [Signing Transactions](/docs/wallet/signing-transactions) - Use your wallet
