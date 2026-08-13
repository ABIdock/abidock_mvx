---
name: wallets-and-signing
title: Wallets and Signing
summary: Load or create an account from a mnemonic, secret key, keystore or PEM, derive and validate addresses, and produce the exact signature bytes the chain accepts for transactions, guarded transactions and off-chain messages.
reads: [00-quickstart.md, 01-public-api.md, 03-transactions.md]
verified_against: abidock_mvx 3.1.0 (Dart 3.13)
---

## When to use this

Use this when you need a signing identity (`Account` / `UserSigner`), an `Address`, a signed
`Transaction`, a signed off-chain `Message`, or signature verification.

Single import for everything on this page:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
```

---

## 1. Account construction

`Account` has **no public constructor** — the generative constructor is private
(`Account._`, `lib/src/core/account/account.dart:56`). You must use one of the four static
factories. **All four are `async`.**

| Call | Exact signature | Source |
|---|---|---|
| Mnemonic | `static Future<Account> fromMnemonic(String mnemonic, {int addressIndex = 0})` | `lib/src/core/account/account.dart:93` |
| Secret key | `static Future<Account> fromSecretKey(UserSecretKey secretKey)` | `lib/src/core/account/account.dart:71` |
| Keystore JSON | `static Future<Account> fromKeystore(String keystoreJson, String password, {int? addressIndex})` | `lib/src/core/account/account.dart:126` |
| PEM | `static Future<Account> fromPem(String pemContent, {int index = 0})` | `lib/src/core/account/account.dart:51` |

Note the parameter names differ: mnemonic/keystore use **`addressIndex`**, PEM uses **`index`**.

```dart
import 'dart:io';

import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  final Account fromMnemonic = await Account.fromMnemonic(
    '${'abandon ' * 23}art',
    addressIndex: 0,
  );

  final UserSecretKey secretKey = UserSecretKey.fromString(
    '413f42575f7f26fad3317a778771212fdb80245850981e48b58a4f25e344e8f9',
  );
  final Account fromSecretKey = await Account.fromSecretKey(secretKey);

  final String pemText = File('wallet.pem').readAsStringSync();
  final Account fromPem = await Account.fromPem(pemText, index: 0);

  final String keystoreJson = File('keystore.json').readAsStringSync();
  final Account fromKeystore = await Account.fromKeystore(
    keystoreJson,
    'password123',
  );

  print(fromMnemonic.address.bech32);
  print(fromSecretKey.address.bech32);
  print(fromPem.address.bech32);
  print(fromKeystore.address.bech32);
}
```

### Account members

| Member | Type / signature | Source |
|---|---|---|
| `secretKey` | `final UserSecretKey` | `account.dart:144` |
| `publicKey` | `final UserPublicKey` | `account.dart:147` |
| `address` | `final Address` | `account.dart:150` |
| `nonce` | `Nonce nonce` (mutable, starts `const Nonce.zero()`) | `account.dart:153` |
| `incrementNonce()` | `void` | `account.dart:163` |
| `getNonceThenIncrement()` | `Nonce` — returns the value **before** incrementing | `account.dart:179` |
| `sign(...)` | `Future<Uint8List> sign(Uint8List data)` | `account.dart:186` |
| `signTransaction(...)` | `Future<Uint8List> signTransaction(Transaction transaction)` | `account.dart:191` |
| `signTransactions(...)` | `Future<List<Uint8List>> signTransactions(List<Transaction> transactions)` | `account.dart:196` |
| `verifyTransactionSignature(...)` | `Future<bool> verifyTransactionSignature(Transaction, Uint8List)` | `account.dart:208` |
| `signMessage(...)` | `Future<Uint8List> signMessage(Message message)` | `account.dart:237` |
| `verifyMessageSignature(...)` | `Future<bool> verifyMessageSignature(Message, Uint8List)` | `account.dart:243` |
| `verify(...)` | `Future<bool> verify(Uint8List data, Uint8List signature)` | `account.dart:255` |
| `signAsGuardian(...)` | `Future<Uint8List> signAsGuardian(Transaction)` — delegates to `signTransaction` | `account.dart:219` |
| `signAsRelayer(...)` | `Future<Uint8List> signAsRelayer(Transaction outerTransaction)` — delegates to `signTransaction` | `account.dart:223` |
| `prefersHashSigning` | `bool get` — **always `false`** for `Account` | `account.dart:216` |

`Account` implements `IAccount` (`lib/src/core/account/account_interface.dart:26`).

### `UserSigner` — the stateless alternative

Extension methods on `Transaction` take a `UserSigner`, not an `Account`. Convert with
`account.toSigner()` (`lib/src/wallet/account_signer_extensions.dart:38`).

| Call | Exact signature | Source |
|---|---|---|
| `const UserSigner(UserSecretKey secretKey)` | const constructor | `lib/src/wallet/user_signer.dart:48` |
| `UserSigner.fromSecretKey(UserSecretKey)` | `factory` — **sync** | `user_signer.dart:96` |
| `UserSigner.fromPem(String text, {int index = 0})` | `factory` — **sync** | `user_signer.dart:75` |
| `UserSigner.fromMnemonic(String mnemonic, {int addressIndex = 0})` | `static Future<UserSigner>` | `user_signer.dart:116` |
| `UserSigner.fromKeystore(String keystoreJson, String password, {int? addressIndex})` | `static Future<UserSigner>` | `user_signer.dart:149` |
| `sign(Uint8List data)` | `Future<Uint8List>` — wraps failures in `SignerException` | `user_signer.dart:195` |
| `getAddress({String? hrp})` | `Future<Address>` | `user_signer.dart:224` |

### `UserSecretKey` / `UserPublicKey`

| Call | Exact signature | Source |
|---|---|---|
| `UserSecretKey(Uint8List buffer)` | 32-byte Ed25519 seed; length-checked | `lib/src/wallet/user_keys.dart:68` |
| `UserSecretKey.fromString(String value)` | `factory`, exactly 64 hex chars | `user_keys.dart:89` |
| `UserSecretKey.fromPem(String text, {int index = 0})` | `factory` | `user_keys.dart:95` |
| `UserSecretKey.generate()` | `static UserSecretKey` — `Random.secure()` | `user_keys.dart:132` |
| `generatePublicKey()` | `Future<UserPublicKey>` | `user_keys.dart:111` |
| `sign(Uint8List message)` | `Future<Uint8List>` — 64-byte signature | `user_keys.dart:165` |
| `hex` / `bytes` / `dispose()` | `String` / `Uint8List` / `void` | `user_keys.dart:170,173,181` |
| `UserPublicKey(Uint8List buffer)` | 32 bytes | `user_keys.dart:227` |
| `UserPublicKey.verify(Uint8List data, Uint8List signature)` | `Future<bool>` | `user_keys.dart:260` |
| `UserPublicKey.toAddress({String? hrp})` | `Address` — `hrp` defaults to `'erd'` | `user_keys.dart:271` |

Constants: `userSeedLength = 32`, `userPubkeyLength = 32` (`user_keys.dart:15-16`).

`secretKey.dispose()` zeroes the buffer (`user_keys.dart:181`). Do not call it while an `Account`
built from that key is still in use — signing after disposal signs with a zeroed key.

---

## 2. Mnemonic

| Call | Exact signature | Source |
|---|---|---|
| `Mnemonic.generate()` | `factory` — **always 24 words** (`mnemonicStrength = 256`) | `lib/src/wallet/mnemonic.dart:69`, `:14` |
| `Mnemonic.fromString(String text)` | `factory` — validates, throws `MnemonicException` | `mnemonic.dart:97` |
| `Mnemonic.fromEntropy(Uint8List entropy)` | `factory` | `mnemonic.dart:104` |
| `Mnemonic.isValid(String text)` | `static bool` — never throws | `mnemonic.dart:128` |
| `Mnemonic.assertTextIsValid(String text)` | `static void` — throws `MnemonicException` | `mnemonic.dart:142` |
| `deriveKey({int addressIndex = 0, String password = ''})` | `Future<UserSecretKey>` | `mnemonic.dart:184` |
| `getWords()` | `List<String>` | `mnemonic.dart:219` |
| `getEntropy()` | `Uint8List` | `mnemonic.dart:222` |
| `dispose()` | `void` — zeroes the phrase buffer | `mnemonic.dart:229` |

**Word counts accepted by `fromString` / `assertTextIsValid`: 12, 15, 18, 21, 24 only**
(`mnemonic.dart:144`). Any other count throws
`MnemonicException('Invalid word count: N. Must be one of: 12, 15, 18, 21, 24')`.

**Derivation path** is `m/44'/508'/0'/0'/<addressIndex>'` — `bip44DerivationPrefix` is
`"m/44'/508'/0'/0'"` (`mnemonic.dart:15`) and the index segment is appended hardened at
`mnemonic.dart:195`. `addressIndex` is the **last** path segment; there is no account/change knob.

`deriveKey`'s `password` is the BIP39 passphrase (the "25th word"), **not** a keystore password.
A different `password` yields a completely different key.

```dart
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  final Mnemonic generated = Mnemonic.generate();
  final List<String> words = generated.getWords();
  print(words.length);

  final Mnemonic restored = Mnemonic.fromString(words.join(' '));
  final UserSecretKey key0 = await restored.deriveKey(addressIndex: 0);
  final UserSecretKey key1 = await restored.deriveKey(
    addressIndex: 1,
    password: 'bip39-passphrase',
  );

  final Uint8List entropy = restored.getEntropy();
  final Mnemonic rebuilt = Mnemonic.fromEntropy(entropy);

  print(Mnemonic.isValid('not a mnemonic'));
  print(bip44DerivationPrefix);
  print((await key0.generatePublicKey()).toAddress().bech32);
  print((await key1.generatePublicKey()).toAddress(hrp: 'erd').bech32);

  generated.dispose();
  restored.dispose();
  rebuilt.dispose();
  key0.dispose();
  key1.dispose();

  try {
    Mnemonic.assertTextIsValid('one two three');
  } on MnemonicException catch (e) {
    print(e.message);
  }
}
```

---

## 3. Keystore JSON

`UserWalletKind` has exactly **two** values (`lib/src/wallet/user_wallet.dart:20-33`):

| `kind` value in JSON | Enum | Meaning |
|---|---|---|
| `"secretKey"` | `UserWalletKind.secretKey` | Ciphertext is `seed ‖ pubkey` (or bare 32-byte seed) |
| `"mnemonic"` | `UserWalletKind.mnemonic` | Ciphertext is the UTF-8 mnemonic phrase |

A keystore with **no** `kind` key is treated as `"secretKey"` (`user_wallet.dart:344-345`).
Any other string throws `ArgumentError('Unknown wallet kind: …')` (`user_wallet.dart:30`).

| Call | Exact signature | Sync/async | Source |
|---|---|---|---|
| `UserWallet.fromSecretKey({required UserSecretKey secretKey, required String password, Randomness? randomness})` | `static Future<UserWallet>` | async | `user_wallet.dart:98` |
| `UserWallet.fromSecretKeyWithBytes({required UserSecretKey secretKey, required Uint8List passwordBytes, Randomness? randomness})` | `static Future<UserWallet>` | async | `user_wallet.dart:135` |
| `UserWallet.fromMnemonic({required String mnemonic, required String password, Randomness? randomness})` | `factory UserWallet` | **sync** | `user_wallet.dart:203` |
| `UserWallet.fromMnemonicWithBytes({required String mnemonic, required Uint8List passwordBytes, Randomness? randomness})` | `factory UserWallet` | **sync** | `user_wallet.dart:232` |
| `UserWallet.loadSecretKey(String filePath, String password, {int? addressIndex})` | `static Future<UserSecretKey>` | async | `user_wallet.dart:292` |
| `UserWallet.decrypt(Map<String, dynamic> keyFileObject, String password, {int? addressIndex})` | `static Future<UserSecretKey>` | async | `user_wallet.dart:314` |
| `UserWallet.decryptWithBytes(Map<String, dynamic>, Uint8List passwordBytes, {int? addressIndex})` | `static Future<UserSecretKey>` | async | `user_wallet.dart:338` |
| `UserWallet.loadMnemonic(String filePath, String password)` | `static Future<Mnemonic>` | async | `user_wallet.dart:402` |
| `UserWallet.decryptMnemonic(Map<String, dynamic>, String password)` | `static Mnemonic` | **sync** | `user_wallet.dart:420` |
| `UserWallet.decryptMnemonicBytes(Map<String, dynamic>, String password)` | `static Uint8List` | **sync** | `user_wallet.dart:442` |
| `toJson({String? addressHrp})` | `Map<String, dynamic>` | sync | `user_wallet.dart:479` |
| `save(String filePath, {String? addressHrp})` | `void` | sync | `user_wallet.dart:532` |

**The `addressIndex` rules are asymmetric and throw, so get them right:**

- `kind == "secretKey"` and `addressIndex != null` → `ArgumentError('addressIndex must not be
  provided when kind == "secretKey"')` (`user_wallet.dart:349-353`). Pass nothing.
- `kind == "mnemonic"` → `addressIndex ?? 0` is used as the BIP44 index
  (`user_wallet.dart:362`). Omitting it silently means account 0.
- `decryptMnemonic` / `decryptMnemonicBytes` / `loadMnemonic` throw `ArgumentError` when `kind`
  is not `"mnemonic"` (`user_wallet.dart:446-451`).

Emitted JSON keys, verified by round-trip: `secretKey` kind →
`version, kind, id, address, bech32, crypto` (`user_wallet.dart:493-500`); `mnemonic` kind →
`version, id, kind, crypto` (`user_wallet.dart:506-511`). `crypto` carries `ciphertext`,
`cipherparams.iv`, `cipher`, `kdf`, `kdfparams{dklen,salt,n,r,p}`, `mac`
(`user_wallet.dart:514-529`).

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  final UserSecretKey secretKey = UserSecretKey.generate();

  final UserWallet secretKeyWallet = await UserWallet.fromSecretKey(
    secretKey: secretKey,
    password: 'MyStrongPassword123!',
  );
  secretKeyWallet.save('keystore-secretkey.json', addressHrp: 'erd');

  final Mnemonic mnemonic = Mnemonic.generate();
  final UserWallet mnemonicWallet = UserWallet.fromMnemonic(
    mnemonic: mnemonic.getWords().join(' '),
    password: 'MyStrongPassword123!',
  );
  mnemonicWallet.save('keystore-mnemonic.json');
  mnemonic.dispose();

  /// secretKey kind: no addressIndex.
  final UserSecretKey fromSecretKeyKind = await UserWallet.loadSecretKey(
    'keystore-secretkey.json',
    'MyStrongPassword123!',
  );

  /// mnemonic kind: addressIndex selects the BIP44 account.
  final UserSecretKey fromMnemonicKind = await UserWallet.loadSecretKey(
    'keystore-mnemonic.json',
    'MyStrongPassword123!',
    addressIndex: 1,
  );

  final Map<String, dynamic> keyFileObject =
      jsonDecode(File('keystore-mnemonic.json').readAsStringSync())
          as Map<String, dynamic>;

  final Uint8List passwordBytes = Uint8List.fromList(
    utf8.encode('MyStrongPassword123!'),
  );
  final UserSecretKey decrypted = await UserWallet.decryptWithBytes(
    keyFileObject,
    passwordBytes,
    addressIndex: 0,
  );
  passwordBytes.fillRange(0, passwordBytes.length, 0);

  final Mnemonic recovered = await UserWallet.loadMnemonic(
    'keystore-mnemonic.json',
    'MyStrongPassword123!',
  );
  recovered.dispose();

  print(fromSecretKeyKind.hex.length);
  print(fromMnemonicKind.hex.length);
  print(decrypted.hex.length);
  print(UserWalletKind.fromString('mnemonic').value);
}
```

Dart `String`s cannot be wiped from memory. When that matters, use the `…WithBytes` overloads and
zero your own `Uint8List` afterwards, as above (`user_wallet.dart:115-127`).

---

## 4. PEM

### User PEM

Block body is base64 of the **ASCII hex** of `seed ‖ pubkey` (64 bytes total)
(`lib/src/wallet/pem.dart:156-185`), and the `-----BEGIN PRIVATE KEY for <label>-----` label must be
the bech32 address of that pubkey: the parser re-derives an address from the embedded 32 pubkey
bytes and compares it to the label (`pem.dart:67-84`). A mismatched label throws — the parser will
not silently accept a relabelled file.

| Call | Exact signature | Source |
|---|---|---|
| `parseUserKey(String text, {int index = 0})` | `UserSecretKey` | `lib/src/wallet/pem.dart:30` |
| `parseUserKeys(String text)` | `List<UserSecretKey>` | `pem.dart:54` |
| `UserSecretKey.fromPem(String text, {int index = 0})` | `factory` — same parser | `lib/src/wallet/user_keys.dart:95` |
| `UserSigner.fromPem(String text, {int index = 0})` | `factory UserSigner` | `lib/src/wallet/user_signer.dart:75` |
| `Account.fromPem(String pemContent, {int index = 0})` | `static Future<Account>` | `lib/src/core/account/account.dart:51` |
| `PemEntry.fromTextAll(String pemText)` | `static List<PemEntry>` (low-level label+bytes pairs) | `lib/src/wallet/pem_entry.dart:70` |

Every failure path throws `PemException` (extends `WalletException` extends `AbidockException`,
`lib/src/utils/sdk_exceptions.dart:107`, `:87`, `:47`): empty text, file over 1 MB, nested/unclosed
`BEGIN`, disagreeing `BEGIN`/`END` labels, bad base64, non-hex body, odd hex length, wrong key
length, all-zero/all-ones key material, index out of bounds.

### Validator PEM (separate helpers — do not mix them up)

Validator keys are BLS12-381: 32-byte secret, 96-byte public. The label is **192 lowercase hex
chars** (the BLS public key), *not* a bech32 address (`lib/src/wallet/validator_keys.dart:293`,
`:307-312`).

| Call | Exact signature | Source |
|---|---|---|
| `parseValidatorPem(String text)` | `List<ValidatorSecretKey>` | `lib/src/wallet/validator_pem.dart:24` |
| `parseValidatorKey(String text, {int index = 0})` | `ValidatorSecretKey` | `validator_pem.dart:37` |
| `parseValidatorKeys(String pemText)` | `List<ValidatorSecretKey>` | `lib/src/wallet/validator_keys.dart:273` |
| `ValidatorSecretKey.fromPem(String pemText, {int index = 0})` | `static ValidatorSecretKey` | `validator_keys.dart:193` |
| `ValidatorSecretKey.fromHex(String hex)` | `factory` — 64 hex chars | `validator_keys.dart:149` |
| `ValidatorSecretKey.toPem(ValidatorPublicKey publicKey)` | `String` | `validator_keys.dart:220` |
| `ValidatorPublicKey.fromHex(String hex)` | `factory` — 192 hex chars | `validator_keys.dart:75` |

Constants: `validatorSecretKeyLength = 32`, `validatorPublicKeyLength = 96`
(`validator_keys.dart:10-11`).

> **`ValidatorSecretKey.sign(Uint8List data)` always throws `UnimplementedError`**
> (`validator_keys.dart:249-254`) — no pure-Dart BLS12-381 backend ships here. See §8.

```dart
import 'dart:io';

import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  final String pemText = File('wallet.pem').readAsStringSync();

  final UserSecretKey single = parseUserKey(pemText, index: 0);
  final List<UserSecretKey> all = parseUserKeys(pemText);
  final UserSigner signer = UserSigner.fromPem(pemText, index: 0);

  print(all.length);
  print(single.hex.length);
  print((await signer.getAddress()).bech32);

  try {
    parseUserKey('not a pem');
  } on PemException catch (e) {
    print(e.message);
  }

  final String validatorPemText = File('validator.pem').readAsStringSync();
  final ValidatorSecretKey validatorKey = parseValidatorKey(
    validatorPemText,
    index: 0,
  );
  final List<ValidatorSecretKey> validatorKeys = parseValidatorPem(
    validatorPemText,
  );

  print(validatorKeys.length);
  print(validatorKey.hex.length);
  validatorKey.dispose();
}
```

---

## 5. Address

| Call | Exact signature | Source |
|---|---|---|
| `Address(List<int> bytes, {String hrp = 'erd'})` | generative; throws if `bytes.length != 32` | `lib/src/core/address.dart:69` |
| `Address.fromBech32(String bech32)` | `factory` — hrp is taken from the input string | `address.dart:93` |
| `Address.fromHex(String hex, {String hrp = 'erd'})` | `factory` — 64 hex chars, **no `0x` prefix** | `address.dart:123` |
| `Address.zero({String hrp = 'erd'})` | generative — 32 zero bytes | `address.dart:175` |
| `Address.empty()` | `static Address` — returns `Address.zero()` | `address.dart:172` |
| `Address.isValid(String bech32)` | `static bool` — never throws | `address.dart:156` |
| `bech32` | `String get` | `address.dart:188` |
| `hex` | `String get` — lowercase, unprefixed | `address.dart:185` |
| `hrp` | `final String` | `address.dart:182` |
| `bytes` | `final List<int>` | `address.dart:179` |
| `isEmpty` / `isZero` | `bool get` — all 32 bytes zero | `address.dart:191`, `:200` |
| `isSmartContract` | `bool get` — **first 8 bytes all zero** | `address.dart:215-221` |
| `Address.getShardOfAddress(Address, {int numberOfShards = 3})` | `static int` | `address.dart:270` |
| `Address.isPubkeyOfMetachain(Address)` | `static bool` | `address.dart:302` |

**Bad input throws `AddressException`, not `FormatException` or `ArgumentError`.**
`AddressException extends AbidockException` (`address.dart:24`, `lib/src/utils/sdk_exceptions.dart:47`).
It is raised for: a bech32 string with no `1` separator (`address.dart:258-266`), a bad bech32
checksum or character (`address.dart:98-104`), non-hex input (`address.dart:126-133`), and any
payload that is not exactly 32 bytes (`address.dart:70-76`, `:134-139`).

Catch `AddressException` for a single format, or `AbidockException` to trap every SDK error.

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() {
  final Address user = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final Address contract = Address.fromHex(
    '000000000000000005000ed0714b2ff7c6c1b0177b5a8e83e4f9f0eb1b6f1f1f',
  );
  final Address zero = Address.zero();
  final Address alsoZero = Address.empty();

  print(user.bech32);
  print(user.hex);
  print(user.hrp);
  print(user.isSmartContract);
  print(contract.isSmartContract);
  print(zero.isEmpty);
  print(alsoZero.isZero);
  print(Address.isValid('nope'));
  print(Address.getShardOfAddress(user, numberOfShards: 3));

  try {
    Address.fromBech32('not-a-bech32');
  } on AddressException catch (e) {
    print(e.message);
  }

  try {
    Address.fromHex('zz');
  } on AddressException catch (e) {
    print(e.message);
  }
}
```

---

## 6. Signing a transaction

### The bytes that get signed

`Transaction.serializeForSigning()` (`lib/src/core/transaction/transaction.dart:287`) returns:

- the **UTF-8 JSON** of `TransactionComputer.toPlainObject(tx)` normally, or
- its **32-byte Keccak-256 digest** when the `hashSign` option bit is set.

`Account.signTransaction` makes the same choice internally
(`lib/src/core/account/account.dart:229-234`), so **do not hash the bytes yourself** — you would
double-hash.

The signing payload emits keys in a fixed order and omits `signature`, `guardianSignature` and
`relayerSignature` (`lib/src/core/transaction/transaction_computer.dart:196-257`). Sender, guardian
and relayer therefore all sign **the same bytes**.

Both branches are pinned by `test/core/transaction/transaction_signing_payload_pinning_test.dart`:
hash signing off returns the raw JSON (`:200-202`), hash signing on returns exactly 32 bytes with a
golden digest (`:204-224`), and the full 14-key order is asserted at `:86-101`.

### Option bits

`lib/src/core/transaction/transaction_constants.dart`:

| Constant | Value | Line |
|---|---|---|
| `transactionOptionsDefault` | `0` | `:4` |
| `transactionOptionsTxHashSign` | `1` | `:5` |
| `transactionOptionsTxGuarded` | `2` | `:6` |
| `minTransactionVersionThatSupportsOptions` | `2` | `:9` |

Options and bits are validated before serialization
(`transaction_computer.dart:261-301`) and throw `ArgumentError` when:

- `chainID` is empty (`:262-264`);
- any option bit is set while `version < 2` (`:266-272`);
- `relayer` is set while `version < 2` (`:273-277`);
- an **unknown** option bit is set — only `1` and `2` are accepted (`:280-287`);
- `guardian` is set but the guarded bit is not (`:289-295`);
- `senderUsername` / `receiverUsername` exceeds 32 bytes (`:297-300`).

### Hash signing

`TransactionComputer.applyOptionsForHashSigning(Transaction)`
(`transaction_computer.dart:165`) returns a copy with `options |= 1` and `version` raised to at
least 2. Verified: a v1 transaction comes back as `version 2, options 1`, and its signing payload
becomes 32 bytes.

`IAccount.prefersHashSigning` (`lib/src/core/account/account_interface.dart:44`) is the signal to
apply that bit before signing; `Account` returns `false` (`account.dart:216`) because a local
Ed25519 key can sign any payload size.

### TransactionComputer surface

| Call | Signature | Source |
|---|---|---|
| `const TransactionComputer()` | const | `transaction_computer.dart:34` |
| `computeBytesForSigning(Transaction)` | `Uint8List` — raw JSON, no hashing | `:47` |
| `computeHashForSigning(Transaction)` | `Uint8List` — Keccak-256 of that JSON | `:75` |
| `computeBytesForVerifying(Transaction)` | `Uint8List` — picks by option bit | `:63` |
| `computeTransactionHash(Transaction)` | `String` — Blake2b-256 over protobuf, lowercase hex | `:94` |
| `hasOptionsSetForHashSigning(Transaction)` | `bool` | `:111` |
| `hasOptionsSetForGuardedTransaction(Transaction)` | `bool` | `:105` |
| `applyOptionsForHashSigning(Transaction)` | `Transaction` | `:165` |
| `applyGuardian(Transaction, Address guardian)` | `Transaction` | `:125` |
| `isRelayedV3Transaction(Transaction)` | `bool` — true when `relayer != null` | `:153` |
| `toPlainObject(Transaction, {bool withSignature = false})` | `Map<String, dynamic>` | `:196` |
| `computeTransactionFee(Transaction, NetworkConfiguration)` | `BigInt` | `:325` |

### Applying the signature

`Signature.fromUint8List(Uint8List)` (`lib/src/core/signature.dart:76`) requires **0 or exactly
64 bytes** and throws `ArgumentError` otherwise. Attach it with
`tx.copyWith(newSignature: …)` — `Transaction` is immutable
(`lib/src/core/transaction/transaction.dart:51,221`).

```dart
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  final Account account = await Account.fromSecretKey(UserSecretKey.generate());

  final Transaction tx = Transaction(
    nonce: const Nonce(7),
    sender: account.address,
    receiver: Address.fromBech32(
      'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
    ),
    value: Balance.fromEgld(0.1),
    gasLimit: const GasLimit(50000),
    gasPrice: const GasPrice(1000000000),
    chainId: const ChainId.devnet(),
    version: const TransactionVersion(2),
    data: Uint8List(0),
  );

  final Uint8List signature = await account.signTransaction(tx);
  final Transaction signed = tx.copyWith(
    newSignature: Signature.fromUint8List(signature),
  );
  print(signed.signature.hex);

  const TransactionComputer computer = TransactionComputer();

  /// Hash signing: apply the option bit BEFORE signing.
  final Transaction hashSigned = computer.applyOptionsForHashSigning(tx);
  final Uint8List hashSignature = await account.signTransaction(hashSigned);
  final Transaction hashSignedFinal = hashSigned.copyWith(
    newSignature: Signature.fromUint8List(hashSignature),
  );

  print(hashSigned.version.value);
  print(hashSigned.options == transactionOptionsTxHashSign);
  print(await account.verifyTransactionSignature(hashSigned, hashSignature));
  print(computer.computeTransactionHash(hashSignedFinal));

  /// Equivalent explicit form.
  final Uint8List manualBytes = tx.serializeForSigning();
  final Uint8List manualSignature = await account.sign(manualBytes);
  print(manualSignature.length);

  /// Extension form, which takes a UserSigner rather than an Account.
  final UserSigner signer = account.toSigner();
  final Transaction viaExtension = await tx.signWith(signer);
  print(viaExtension.isFullySigned);
  print(viaExtension.missingSignatures);
}
```

### Transaction signing extensions

`extension TransactionSigningExtensions on Transaction`
(`lib/src/abi/extensions/transaction_signing_extensions.dart:11`):

| Call | Signature | Line |
|---|---|---|
| `signWith(UserSigner signer)` | `Future<Transaction>` — sets `signature` | `:19` |
| `signAsGuardian(UserSigner guardianSigner)` | `Future<Transaction>` — sets `guardianSignature`; throws `TransactionException` if `guardian` is unset/empty | `:82` |
| `signAsRelayer(UserSigner relayerSigner, {int numberOfShards = 3})` | `Future<Transaction>` — sets `relayerSignature`; throws `TransactionException` if `relayer` is unset or in a different shard than `sender` | `:37` |
| `isGuardedTransaction` | `bool get` | `:107` |
| `isRelayedTransaction` | `bool get` | `:101` |
| `isFullySigned` | `bool get` | `:113` |
| `missingSignatures` | `List<String> get` — subset of `['user','relayer','guardian']` | `:131` |

---

## 7. Signing an arbitrary message

### The envelope the chain expects

```
keccak256( "\x17Elrond Signed Message:\n" + asciiDecimal(data.length) + data )
```

The Ed25519 signature is over that **32-byte digest**, never over the raw message bytes
(`lib/src/core/message/message_computer.dart:52-64`). The leading `0x17` byte is the length (23)
of the ASCII text that follows; the exact spelling — including both spaces — is part of the hashed
bytes and is pinned by `test/core/message/message_prefix_pinning_test.dart`. Verified by
recomputing the digest independently: for `'hello'` the envelope is
`keccak256(prefix + '5' + 'hello')`.

The constant is exported twice with identical values: `messagePrefix`
(`lib/src/core/message/base.dart:18`) and `canonicalMessagePrefix`
(`message_computer.dart:229`).

### API

| Call | Signature | Source |
|---|---|---|
| `Message(List<int> bytes, {Address? address, Uint8List? signature, int version = 1, String? signer})` | positional payload, everything else named | `lib/src/core/message/base.dart:49` |
| `message.bytes` | `List<int> get` — unmodifiable | `base.dart:61` |
| `message.signature` | `final Uint8List` — `Uint8List(0)` when unsigned | `base.dart:68` |
| `const MessageComputer()` | const | `message_computer.dart:39` |
| `computeBytesForSigning(Message)` | `Uint8List` — the 32-byte digest | `message_computer.dart:52` |
| `computeBytesForVerifying(Message)` | `Uint8List` — identical output | `message_computer.dart:78` |
| `packMessage(Message)` | `Map<String, dynamic>` | `message_computer.dart:94` |
| `unpackMessage(Map<String, dynamic> payload, {bool acceptBase64 = false})` | `Message` | `message_computer.dart:137` |

`packMessage` always emits `message` (hex) and `version`. It adds `signature` (hex) when the
signature is non-empty, `address` (bech32) whenever `address` is **non-null**, and `signer` when it
is non-null and non-empty (`message_computer.dart:94-115`). `unpackMessage` decodes `message` as
**hex by default**; a non-hex payload without the flag throws `FormatException`. With
`acceptBase64: true` the decoder tries base64 **first** and only falls back to hex
(`message_computer.dart:176-196`), so an ambiguous string is read as base64.

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  final Account account = await Account.fromSecretKey(UserSecretKey.generate());
  final Message message = Message(utf8.encode('Login to dApp'));

  /// One-shot: Account applies the canonical envelope for you.
  final Uint8List signature = await account.signMessage(message);
  print(signature.length);
  print(await account.verifyMessageSignature(message, signature));

  /// Explicit form, if you hold the key elsewhere.
  const MessageComputer computer = MessageComputer();
  final Uint8List digest = computer.computeBytesForSigning(message);
  final Uint8List manual = await account.sign(digest);
  print(await account.publicKey.verify(digest, manual));

  /// Wire shape for handing the signed message to a backend.
  final Map<String, dynamic> packed = computer.packMessage(
    Message(
      message.bytes,
      address: account.address,
      signature: signature,
      version: 1,
      signer: 'my-wallet',
    ),
  );
  print(packed.keys.toList());

  final Message unpacked = computer.unpackMessage(packed);
  print(utf8.decode(unpacked.bytes));
  print(unpacked.signature.length);
}
```

> `SignableMessage` was **removed in 3.0.0**. There is no such class. Use `Message` +
> `MessageComputer`.

---

## 8. Verifying a signature

| Call | Signature | Source |
|---|---|---|
| `const UserVerifier(UserPublicKey publicKey)` | const | `lib/src/wallet/user_verifier.dart:35` |
| `UserVerifier.fromAddress(Address address)` | `factory` — the address bytes *are* the Ed25519 pubkey | `user_verifier.dart:59` |
| `verify(Uint8List data, Uint8List signature)` | `Future<bool>` | `user_verifier.dart:93` |
| `UserPublicKey.verify(Uint8List data, Uint8List signature)` | `Future<bool>` | `lib/src/wallet/user_keys.dart:260` |

**Verification returns `false` for malformed input — it does not throw.** The `try/catch` at
`user_keys.dart:261-266` awaits inside the `try`, so asynchronous errors are caught too. Pinned by
`test/wallet/user_keys_verify_async_test.dart`: a 3-byte signature returns `false` (`:26-30`), an
empty signature returns `false` (`:32-34`), a correctly-sized wrong signature returns `false`
(`:36-42`), and a genuine signature returns `true` (`:44-51`).

So `if (await verifier.verify(data, sig))` is safe with attacker-controlled bytes — you do not need
a `try/catch` around it.

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  final Address claimed = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );
  final UserVerifier verifier = UserVerifier.fromAddress(claimed);

  const MessageComputer computer = MessageComputer();
  final Message message = Message(utf8.encode('Login to dApp'));
  final Uint8List digest = computer.computeBytesForVerifying(message);

  final Uint8List signatureFromClient = Uint8List(64);
  print(await verifier.verify(digest, signatureFromClient));

  /// Malformed input yields false rather than an exception.
  print(await verifier.verify(digest, Uint8List.fromList(<int>[1, 2, 3])));
  print(await verifier.verify(digest, Uint8List(0)));
}
```

To verify a transaction signature against bytes you rebuild yourself, use
`TransactionComputer.computeBytesForVerifying(tx)` (it applies the hash-signing bit for you),
or call `account.verifyTransactionSignature(tx, signature)`.

---

## 9. ValidatorSigner (BLS12-381)

`ValidatorSigner` has exactly **one** constructor:

```
const ValidatorSigner.custom(ValidatorSignFunction signFn)   lib/src/wallet/validator_signer.dart:37
typedef ValidatorSignFunction = Uint8List Function(Uint8List message)   validator_signer.dart:17
bool get canSign                                             validator_signer.dart:45  (always true)
Uint8List sign(Uint8List message)                            validator_signer.dart:54
```

`ValidatorSigner(secretKey)` and `ValidatorSigner.fromPem(...)` were **removed in 3.0.0**. They
could not actually sign: validator identities are BLS12-381 and no pure-Dart BLS12-381
implementation ships with this package, so those constructors returned an object whose `sign` was
guaranteed to fail. Keeping only `.custom` makes the requirement explicit at construction time.

To sign as a validator you must supply a backend — a native BLS plugin, an FFI binding, or a remote
signing service — that maps message bytes to a **96-byte** signature. `ValidatorSecretKey.sign`
throws `UnimplementedError` (`lib/src/wallet/validator_keys.dart:249-254`); it is not a fallback.

You can still parse, hold and re-serialize validator key material without a backend
(`parseValidatorKey`, `ValidatorSecretKey.fromHex`, `toPem`, `ValidatorPublicKey.fromHex`).

```dart
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';

Uint8List blsSignViaNativeBackend(Uint8List message) {
  throw UnimplementedError('wire up a native BLS12-381 backend here');
}

void main() {
  const ValidatorSigner signer = ValidatorSigner.custom(blsSignViaNativeBackend);
  print(signer.canSign);

  final ValidatorPublicKey publicKey = ValidatorPublicKey.fromHex('a' * 192);
  print(publicKey.bytes.length);
}
```

Behaviour pinned by `test/wallet/validator_signer_test.dart`: `canSign` is `true` (`:8-13`), `sign`
returns exactly what the closure returns (`:15-23`), and the closure receives the message bytes
unchanged (`:25-35`).

---

## 10. Guardians

A guarded transaction carries `guardian` + `guardianSignature` and sets option bit `2`.

**Order matters.** `guardian`, `options` and `version` are all part of the signing payload
(`transaction_computer.dart:226-239`), so the guardian must be applied **before anyone signs**.

1. Build the unsigned transaction.
2. `computer.applyGuardian(tx, guardianAddress)` — sets `guardian`, ORs in
   `transactionOptionsTxGuarded` (`2`), and raises `version` to at least `2`
   (`transaction_computer.dart:125-150`). Verified: a v1/options-0 draft comes back as
   `version 2, options 2`.
3. Sender signs → `copyWith(newSignature: …)`.
4. Guardian signs **the same bytes** → `copyWith(newGuardianSignature: …)`.

`applyGuardian` throws `StateError` if the transaction already carries a *different* non-empty
guardian (`transaction_computer.dart:126-134`). Re-applying the same guardian is fine.

Setting `guardian` by hand via `copyWith` **without** the option bit makes
`serializeForSigning()` throw `ArgumentError` (`transaction_computer.dart:289-295`). Prefer
`applyGuardian`.

```dart
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';

Future<void> main() async {
  final Account owner = await Account.fromSecretKey(UserSecretKey.generate());
  final Account guardian = await Account.fromSecretKey(UserSecretKey.generate());

  final Transaction draft = Transaction(
    nonce: const Nonce(7),
    sender: owner.address,
    receiver: Address.fromBech32(
      'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
    ),
    value: Balance.fromEgld(0.1),
    gasLimit: const GasLimit(100000),
    gasPrice: const GasPrice(1000000000),
    chainId: const ChainId.devnet(),
    version: const TransactionVersion(1),
    data: Uint8List(0),
  );

  const TransactionComputer computer = TransactionComputer();

  /// Step 2 - version becomes 2, options becomes 2.
  final Transaction guarded = computer.applyGuardian(draft, guardian.address);
  print(guarded.version.value);
  print(guarded.options == transactionOptionsTxGuarded);
  print(computer.hasOptionsSetForGuardedTransaction(guarded));

  /// Step 3 - sender.
  final Uint8List ownerSignature = await owner.signTransaction(guarded);
  final Transaction signedByOwner = guarded.copyWith(
    newSignature: Signature.fromUint8List(ownerSignature),
  );

  /// Step 4 - guardian signs the same payload.
  final Uint8List guardianSignature = await guardian.signAsGuardian(guarded);
  final Transaction broadcastable = signedByOwner.copyWith(
    newGuardianSignature: Signature.fromUint8List(guardianSignature),
  );

  print(broadcastable.isGuardedTransaction);
  print(broadcastable.isFullySigned);
  print(broadcastable.missingSignatures);

  /// Extension form produces the identical guardian signature.
  final Transaction viaExtension = await signedByOwner.signAsGuardian(
    guardian.toSigner(),
  );
  print(
    viaExtension.guardianSignature.hex == broadcastable.guardianSignature.hex,
  );
}
```

Hash signing and guarding compose: applying both yields `options == 3` (bit `1` | bit `2`), which
passes the known-bits check at `transaction_computer.dart:280-287`.

---

## 11. Removed in 3.0.0 — never emit these

| Symbol | Replacement |
|---|---|
| `SignableMessage` | `Message` + `MessageComputer` (§7) |
| `ValidatorSigner(secretKey)`, `ValidatorSigner.fromPem` | `ValidatorSigner.custom(signFn)` (§9) |
| `Transaction.innerTransactions` | Does not exist. Relayed v3 is one flat transaction carrying `relayer` + `relayerSignature`. |
| `createRelayedTransaction` | — |
| `TransactionStatus.recalled` / `isRecalled` | — |
| `NetworkConfig.gasPriceModifierString` | — |
| `functionCallHexParts` | — |
| `createTransactionForDelegatingVote` | — |
| `createTransactionForUnsettingBurnRoleForAll` | — |

`relayedVersion` is `String?`.

---

## 12. Signing checklist

1. **Get a signer.** `Account.fromMnemonic` / `fromSecretKey` / `fromKeystore` / `fromPem` — all
   `async`. For extension methods on `Transaction`, convert with `account.toSigner()`.
2. **Set the nonce.** `tx.copyWith(newNonce: account.getNonceThenIncrement())`. A stale nonce is
   rejected by the chain, not by this library.
3. **Set `chainId`.** Empty `chainID` throws `ArgumentError` at serialization time.
4. **Apply the guardian first, if any.** `computer.applyGuardian(tx, guardianAddress)` — before
   any signature. It raises `version` to 2 and sets option bit `2`.
5. **Apply hash signing first, if the signer needs it.** Check `signer.prefersHashSigning`; if
   `true`, `computer.applyOptionsForHashSigning(tx)`. It raises `version` to 2 and sets option
   bit `1`.
6. **Freeze the transaction.** Every field change after this point invalidates the signature.
7. **Sign.** `await account.signTransaction(tx)` — do *not* pre-hash; the hash-signing branch is
   handled internally.
8. **Attach.** `tx.copyWith(newSignature: Signature.fromUint8List(sig))` (0 or 64 bytes only).
9. **Co-sign, in any order, over the same bytes.** Guardian →
   `copyWith(newGuardianSignature: …)`; relayer → `copyWith(newRelayerSignature: …)`.
10. **Assert completeness.** `tx.isFullySigned` must be `true`; otherwise
    `tx.missingSignatures` names what is absent.
11. **Broadcast** `tx.toJson()` — it is `toPlainObject(withSignature: true)`, the canonical
    broadcast shape.

For messages: build `Message(utf8.encode(text))` → `account.signMessage(message)` →
`account.verifyMessageSignature(message, signature)`. Never sign `message.bytes` directly; the
chain verifies against the keccak envelope of §7.

---

## Not verified

- Whether the chain accepts a guarded transaction whose guardian differs from the account's
  on-chain active guardian — that is node-side behaviour and was not exercised here.
- The `Randomness` parameter on `UserWallet.fromSecretKey` / `fromMnemonic`: its type is public
  but its intended production use was not exercised; the defaulted form (`randomness` omitted) is
  what the samples above verify.
- Scrypt KDF parameter values written into new keystores (`n`, `r`, `p`, `dklen`) were not read
  out of `lib/src/wallet/crypto/constants.dart` and are therefore not stated here.
- `PemEntry.fromTextAll` / `PemEntry.toText` were not exercised at runtime; only their
  declarations were read. Prefer `parseUserKeys` / `parseUserKey`, which are exercised above.
- Hardware-wallet and remote-signer implementations of `IAccount` are not part of this package;
  only `Account` was verified against the interface.
