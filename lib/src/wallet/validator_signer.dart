/// BLS12-381 signer backed by a caller-provided signing function.
///
/// Validator identities on MultiversX are BLS12-381 keypairs: a 32-byte
/// secret key and a 96-byte public key, producing 96-byte signatures. No
/// pure-Dart BLS12-381 implementation ships with this package, so signing is
/// delegated to a backend supplied through [ValidatorSigner.custom] — a
/// native BLS plugin, an FFI binding, or a remote signing service.
import 'dart:typed_data';

/// Signature for a caller-provided BLS signing closure.
///
/// #### Parameters
/// - `message` - Bytes to sign.
///
/// #### Returns
/// `Uint8List` - 96-byte BLS signature produced by the backend.
typedef ValidatorSignFunction = Uint8List Function(Uint8List message);

/// Signs messages on behalf of a single BLS validator key.
///
/// #### Example
/// ```dart
/// final signer = ValidatorSigner.custom((bytes) => myBlsBackend.sign(bytes));
/// final signature = signer.sign(Uint8List.fromList([1, 2, 3]));
/// ```
class ValidatorSigner {
  /// Builds a `ValidatorSigner` backed by a caller-provided BLS sign function.
  ///
  /// Use this when integrating a native BLS plugin or a remote signer.
  ///
  /// #### Parameters
  /// - `signFn` - Function that produces a 96-byte BLS signature for the
  ///   given message bytes.
  ///
  /// #### Returns
  /// `ValidatorSigner` - Signer that delegates [sign] to `signFn`.
  const ValidatorSigner.custom(ValidatorSignFunction signFn) : _signFn = signFn;

  final ValidatorSignFunction _signFn;

  /// Whether this signer can produce a signature.
  ///
  /// Always `true`: [ValidatorSigner.custom] is the only construction path
  /// and it requires a backend up front.
  bool get canSign => true;

  /// Signs a message with the wired-up BLS backend.
  ///
  /// #### Parameters
  /// - `message` - Bytes to sign
  ///
  /// #### Returns
  /// `Uint8List` - 96-byte BLS signature
  Uint8List sign(Uint8List message) => _signFn(message);
}
