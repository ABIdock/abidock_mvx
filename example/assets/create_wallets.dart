import 'dart:io';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';

/// Generates the `alice.pem` and `bob.pem` wallets the examples expect.
///
/// Run from the repository root:
///
/// ```bash
/// dart run example/assets/create_wallets.dart
/// ```
///
/// Both files land in `example/assets/`, which is git-ignored, and both start
/// with a zero balance — fund the printed addresses from the devnet faucet
/// before running the swap and transfer examples.
Future<void> main() async {
  for (final String name in <String>['alice', 'bob']) {
    final File target = File('example/assets/$name.pem');
    if (target.existsSync()) {
      print('$name.pem already exists, leaving it untouched');
      continue;
    }

    final Mnemonic mnemonic = Mnemonic.generate();
    final UserSecretKey secretKey = await mnemonic.deriveKey();
    final UserPublicKey publicKey = await secretKey.generatePublicKey();
    final Address address = publicKey.toAddress();

    final PemEntry entry = PemEntry(
      label: address.bech32,
      message: Uint8List.fromList(<int>[
        ...secretKey.bytes,
        ...publicKey.bytes,
      ]),
    );

    target.writeAsStringSync(entry.toText());
    print('$name.pem -> ${address.bech32}');
    print('  mnemonic: ${mnemonic.getWords().join(' ')}');
    mnemonic.dispose();
  }
}
