/// Validator PEM parsing helpers.
///
/// The on-disk format follows the same shape as the user PEM format:
/// ```
/// -----BEGIN PRIVATE KEY for <hex-bls-public-key>-----
/// <base64(hex(32-byte-bls-secret-key))>
/// -----END PRIVATE KEY for <hex-bls-public-key>-----
/// ```
/// Multiple validator entries can be concatenated.
library;

import 'validator_keys.dart';

/// Parses every `ValidatorSecretKey` from a validator PEM file.
///
/// Thin wrapper over `parseValidatorKeys` in `validator_keys.dart`, named
/// after the file format it reads.
///
/// #### Parameters
/// - `text` - Validator PEM file contents
///
/// #### Returns
/// `List<ValidatorSecretKey>` - All validator keys, in file order
List<ValidatorSecretKey> parseValidatorPem(String text) {
  return parseValidatorKeys(text);
}

/// Parses a single `ValidatorSecretKey` from a validator PEM file.
///
/// #### Parameters
/// - `text` - Validator PEM file contents
/// - `index` - Entry index when multiple validators are concatenated
///   (default 0)
///
/// #### Returns
/// `ValidatorSecretKey` - Parsed validator key at the requested index
ValidatorSecretKey parseValidatorKey(String text, {int index = 0}) {
  return ValidatorSecretKey.fromPem(text, index: index);
}
