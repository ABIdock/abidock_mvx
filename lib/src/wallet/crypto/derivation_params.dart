/// Scrypt key derivation function parameters for password-based encryption.
/// Memory-hard KDF designed to resist GPU and ASIC brute-force attacks.
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// Scrypt key derivation function parameters per RFC 7914.
/// Configures CPU/memory cost, block size, parallelization, and output length.
class ScryptKeyDerivationParams {
  /// Creates Scrypt parameters with optional custom values.
  ///
  /// #### Parameters
  /// - `n` - CPU/memory cost parameter (default 16384)
  /// - `r` - Block size parameter (default 8)
  /// - `p` - Parallelization parameter (default 1)
  /// - `dklen` - Derived key length in bytes (default 32)
  ScryptKeyDerivationParams({
    this.n = 16384,
    this.r = 8,
    this.p = 1,
    this.dklen = 32,
  }) {
    if (n < 16384 || (n & (n - 1)) != 0) {
      throw ArgumentError.value(n, 'n', 'must be power of 2 and >= 16384');
    }
    if (r < 8) {
      throw ArgumentError.value(r, 'r', 'must be >= 8');
    }
    if (p < 1) {
      throw ArgumentError.value(p, 'p', 'must be >= 1');
    }
    if (dklen != 32) {
      throw ArgumentError.value(dklen, 'dklen', 'must be 32');
    }
  }

  ScryptKeyDerivationParams.permissive({
    this.n = 16384,
    this.r = 8,
    this.p = 1,
    this.dklen = 32,
  }) {
    if (n < 1024 || (n & (n - 1)) != 0) {
      throw ArgumentError.value(n, 'n', 'must be a power of 2 and >= 1024');
    }
    if (r < 1) {
      throw ArgumentError.value(r, 'r', 'must be >= 1');
    }
    if (p < 1) {
      throw ArgumentError.value(p, 'p', 'must be >= 1');
    }
    if (dklen != 32) {
      throw ArgumentError.value(dklen, 'dklen', 'must be 32');
    }
  }

  /// CPU/memory cost parameter.
  final int n;

  /// Block size parameter.
  final int r;

  /// Parallelization parameter.
  final int p;

  /// Derived key length in bytes.
  final int dklen;

  /// Generates derived key using Scrypt KDF.
  ///
  /// #### Parameters
  /// - `password` - Password bytes
  /// - `salt` - Random salt bytes
  ///
  /// #### Returns
  /// `Uint8List` - Derived key of length dklen bytes
  Uint8List generateDerivedKey(Uint8List password, Uint8List salt) {
    final Scrypt scrypt = Scrypt()
      ..init(ScryptParameters(n, r, p, dklen, salt));

    return scrypt.process(password);
  }
}
