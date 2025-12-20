/// Extension to bridge Account and UserSigner.
import '../core/account/account.dart';
import 'user_signer.dart';

/// Extension to convert Account to UserSigner.
///
/// #### Example
/// ```dart
/// // Create account
/// final account = await Account.fromMnemonic('word1 word2 ...');
///
/// // Convert to signer for stateless operations
/// final signer = account.toSigner();
///
/// // Use with signing extensions
/// await transaction.signWith(signer);
/// ```
extension AccountSignerExtensions on Account {
  /// Converts Account to UserSigner.
  ///
  /// Creates a stateless signer from this account's secret key.
  /// Useful when you need to use signing extensions that accept UserSigner.
  ///
  /// #### Returns
  /// `UserSigner` - Stateless signer with same secret key
  ///
  /// #### Example
  /// ```dart
  /// final account = await Account.fromMnemonic('word1 word2 ...');
  /// final signer = account.toSigner();
  ///
  /// // Use in relayed transactions
  /// await innerTx.signAsRelayer(signer);
  ///
  /// // Use in guardian transactions
  /// await tx.signAsGuardian(signer);
  /// ```
  UserSigner toSigner() {
    return UserSigner.fromSecretKey(secretKey);
  }
}
