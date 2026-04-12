import 'dart:async';

import '../../core/account/account_on_network.dart';
import '../../core/address.dart';
import '../../core/balance.dart';
import '../../core/nonce.dart';
import '../../utils/sdk_exceptions.dart';
import 'network_provider.dart';

/// Configuration options for account polling and waiting.
class AccountAwaitingOptions {
  /// Creates awaiting options with timeout and polling interval.
  ///
  /// #### Parameters
  /// - `timeout` - Maximum wait time before throwing timeout exception (default 60s)
  /// - `pollingInterval` - Time between state checks (default 500ms)
  /// - `maxConsecutiveErrors` - Maximum consecutive errors before giving up (default 5)
  const AccountAwaitingOptions({
    this.timeout = const Duration(seconds: 60),
    this.pollingInterval = const Duration(milliseconds: 500),
    this.maxConsecutiveErrors = 5,
  });

  /// Max wait time.
  final Duration timeout;

  /// Polling interval.
  final Duration pollingInterval;

  /// Maximum consecutive errors before throwing.
  final int maxConsecutiveErrors;
}

/// Waits for account state changes on the blockchain with polling.
/// Provides async waiting for nonce increments, balance changes, and custom conditions.
class AccountAwaiter {
  /// Creates account awaiter.
  AccountAwaiter({required this.networkProvider});

  /// Network provider for fetching account state.
  final NetworkProvider networkProvider;

  /// Awaits until account meets custom condition with polling.
  ///
  /// #### Parameters
  /// - `address` - Account address to monitor
  /// - `condition` - Predicate function returning true when satisfied
  /// - `options` - Optional timeout and polling configuration
  ///
  /// #### Returns
  /// `AccountOnNetwork` - Account state when condition is met
  ///
  /// #### Throws
  /// - `AccountAwaiterTimeoutException` - Timeout reached before condition met
  /// - `AccountAwaiterException` - Network error during polling
  Future<AccountOnNetwork> awaitOnCondition(
    Address address,
    bool Function(AccountOnNetwork) condition, {
    AccountAwaitingOptions? options,
  }) async {
    final opts = options ?? const AccountAwaitingOptions();
    final startTime = DateTime.now();
    final endTime = startTime.add(opts.timeout);
    int consecutiveErrors = 0;

    while (DateTime.now().isBefore(endTime)) {
      try {
        final account = await networkProvider.getAccount(address);
        consecutiveErrors = 0;

        if (condition(account)) {
          return account;
        }

        await Future<void>.delayed(opts.pollingInterval);
      } catch (e) {
        consecutiveErrors++;
        if (consecutiveErrors >= opts.maxConsecutiveErrors) {
          throw AccountAwaiterException(
            'Error while polling account state for ${address.bech32} '
            '($consecutiveErrors consecutive errors)',
            cause: e,
          );
        }

        // Exponential backoff on errors: pollingInterval * 2^(errors-1)
        final backoff = opts.pollingInterval * (1 << (consecutiveErrors - 1));
        await Future<void>.delayed(backoff);
      }
    }

    throw AccountAwaiterTimeoutException(
      'Timeout waiting for account condition (${opts.timeout.inSeconds}s)',
      address: address.bech32,
      timeout: opts.timeout,
    );
  }

  /// Waits for account nonce to increment (transaction confirmation).
  ///
  /// #### Parameters
  /// - `address` - Account address to monitor
  /// - `currentNonce` - Current nonce value before transaction
  /// - `options` - Optional timeout and polling configuration
  ///
  /// #### Returns
  /// `AccountOnNetwork` - Updated account with incremented nonce
  ///
  /// #### Throws
  /// - `AccountAwaiterTimeoutException` - Nonce didn't increment within timeout
  /// - `AccountAwaiterException` - Network error during polling
  Future<AccountOnNetwork> awaitNonceIncrement(
    Address address,
    Nonce currentNonce, {
    AccountAwaitingOptions? options,
  }) {
    return awaitOnCondition(
      address,
      (account) => account.nonce > currentNonce,
      options: options,
    );
  }

  /// Waits for balance to reach or exceed target amount.
  ///
  /// #### Parameters
  /// - `address` - Account address to monitor
  /// - `targetBalance` - Minimum balance to wait for (inclusive)
  /// - `options` - Optional timeout and polling configuration
  ///
  /// #### Returns
  /// `AccountOnNetwork` - Account when balance >= targetBalance
  ///
  /// #### Throws
  /// - `AccountAwaiterTimeoutException` - Balance didn't reach target within timeout
  /// - `AccountAwaiterException` - Network error during polling
  Future<AccountOnNetwork> awaitMinimumBalance(
    Address address,
    Balance targetBalance, {
    AccountAwaitingOptions? options,
  }) {
    return awaitOnCondition(
      address,
      (account) => account.balance >= targetBalance,
      options: options,
    );
  }

  /// Waits for balance to change from current value.
  ///
  /// #### Parameters
  /// - `address` - Account address to monitor
  /// - `currentBalance` - Current balance value to compare against
  /// - `options` - Optional timeout and polling configuration
  ///
  /// #### Returns
  /// `AccountOnNetwork` - Account when balance differs from currentBalance
  ///
  /// #### Throws
  /// - `AccountAwaiterTimeoutException` - Balance didn't change within timeout
  /// - `AccountAwaiterException` - Network error during polling
  Future<AccountOnNetwork> awaitBalanceChange(
    Address address,
    Balance currentBalance, {
    AccountAwaitingOptions? options,
  }) {
    return awaitOnCondition(
      address,
      (account) => account.balance != currentBalance,
      options: options,
    );
  }
}
