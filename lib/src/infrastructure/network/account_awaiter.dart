import 'dart:async';

import '../../core/account/account_on_network.dart';
import '../../core/address.dart';
import '../../core/balance.dart';
import '../../core/nonce.dart';
import '../../utils/sdk_exceptions.dart';
import 'network_provider.dart';

/// Configuration options for account polling and waiting.
///
/// Defaults are derived from the chain's round timing: one poll per 600 ms
/// round, a 9-second hard timeout (15 rounds) and no patience delay. Prior to
/// Supernova a round lasted 6 seconds, which is why older defaults were an
/// order of magnitude larger (6 s polling, 90 s timeout).
class AccountAwaitingOptions {
  /// Creates awaiting options with timeout and polling interval.
  ///
  /// #### Parameters
  /// - `timeout` - Maximum wait time before throwing timeout exception (default 9 seconds)
  /// - `pollingInterval` - Time between state checks (default 600 milliseconds)
  /// - `patience` - Extra delay applied AFTER the condition is satisfied, before returning (default 0)
  /// - `maxConsecutiveErrors` - Maximum consecutive errors before giving up (default 5)
  const AccountAwaitingOptions({
    this.timeout = const Duration(seconds: 9),
    this.pollingInterval = const Duration(milliseconds: 600),
    this.patience = Duration.zero,
    this.maxConsecutiveErrors = 5,
  });

  /// Max wait time.
  final Duration timeout;

  /// Polling interval.
  final Duration pollingInterval;

  /// Optional grace delay applied after the condition becomes true, before returning.
  final Duration patience;

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
          if (opts.patience > Duration.zero) {
            await Future<void>.delayed(opts.patience);
          }
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

        final int exponent = consecutiveErrors - 1 > 10
            ? 10
            : consecutiveErrors - 1;
        final Duration rawBackoff = opts.pollingInterval * (1 << exponent);
        final Duration remaining = endTime.difference(DateTime.now());
        if (remaining <= Duration.zero) break;
        final Duration backoff = rawBackoff > remaining
            ? remaining
            : rawBackoff;
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
