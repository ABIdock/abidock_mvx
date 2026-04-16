---
id: installation
title: Installation
sidebar_position: 1
description: Install abidock_mvx in your Dart or Flutter project via pub.dev or Git to start building MultiversX blockchain applications.
---

# Installation

Add abidock_mvx to your Dart or Flutter project.

## Using pub.dev

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  abidock_mvx: ^1.1.0
```

Then run:

```bash
dart pub get
# or for Flutter
flutter pub get
```

## From Git

For the latest development version:

```yaml
dependencies:
  abidock_mvx:
    git:
      url: https://github.com/ABIdock/abidock_mvx.git
      ref: main
```

## Verify Installation

Create a simple test file:

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() {
  // Create a simple address
  final address = Address.fromBech32(
    'erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu'
  );
  
  print('Address: ${address.bech32}');
  print('Hex: ${address.hex}');
  
  // Create a BigUInt value
  final amount = BigUIntType.create(BigInt.from(1000000000000000000));
  print('Amount: ${amount.nativeValue}');
}
```

Run it:

```bash
dart run test_install.dart
```

Expected output:
```
Address: erd1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6gq4hu
Hex: 0000000000000000000000000000000000000000000000000000000000000000
Amount: 1000000000000000000
```

## Platform Support

| Platform | Support |
|----------|---------|
| Dart VM | Full |
| Flutter (iOS) | Full |
| Flutter (Android) | Full |
| Flutter (Web) | Full |
| Flutter (Desktop) | Full |

## Dependencies

abidock_mvx has minimal dependencies:

- `convert` - Encoding utilities
- `pointycastle` - Cryptographic operations
- `bip39_plus` - Mnemonic generation
- `ed25519_hd_key` - EdDSA signing

All dependencies are pure Dart and work across all platforms.

## Next Steps

- [Quick Start Guide](/docs/getting-started/quick-start) - Create your first transaction
- [Configuration](/docs/getting-started/configuration) - Configure network and providers
