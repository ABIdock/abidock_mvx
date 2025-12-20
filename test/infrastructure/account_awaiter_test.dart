import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

class MockNetworkProvider implements NetworkProvider {
  int _callCount = 0;
  AccountOnNetwork? _fixedAccount;
  List<AccountOnNetwork>? _accountSequence;

  void setAccount(AccountOnNetwork account) {
    _fixedAccount = account;
    _accountSequence = null;
  }

  void setAccountSequence(List<AccountOnNetwork> sequence) {
    _accountSequence = sequence;
    _fixedAccount = null;
    _callCount = 0;
  }

  @override
  Future<AccountOnNetwork> getAccount(Address address) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (_accountSequence != null) {
      if (_callCount >= _accountSequence!.length) {
        return _accountSequence!.last;
      }
      return _accountSequence![_callCount++];
    }
    if (_fixedAccount != null) {
      return _fixedAccount!;
    }
    throw Exception('MockNetworkProvider: No account configured');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName} not implemented');
  }
}

void main() {
  late MockNetworkProvider mockProvider;
  late AccountAwaiter awaiter;
  late Address testAddress;

  setUp(() {
    mockProvider = MockNetworkProvider();
    awaiter = AccountAwaiter(networkProvider: mockProvider);
    testAddress = Address.fromBech32(
      'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
    );
  });

  group('Configuration & Options', () {
    test('handles configuration options', () {
      const defaultOptions = AccountAwaitingOptions();
      expect(defaultOptions.timeout, equals(const Duration(seconds: 30)));
      expect(
        defaultOptions.pollingInterval,
        equals(const Duration(milliseconds: 500)),
      );

      const customOptions = AccountAwaitingOptions(
        timeout: Duration(minutes: 5),
        pollingInterval: Duration(seconds: 1),
      );
      expect(customOptions.timeout, equals(const Duration(minutes: 5)));
      expect(customOptions.pollingInterval, equals(const Duration(seconds: 1)));
    });
  });

  group('Account State Monitoring', () {
    test('handles nonce increment waiting', () async {
      mockProvider.setAccountSequence([
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(5),
          balance: Balance.zero(),
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(5),
          balance: Balance.zero(),
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(6),
          balance: Balance.zero(),
        ),
      ]);

      final result = await awaiter.awaitNonceIncrement(
        testAddress,
        const Nonce(5),
        options: const AccountAwaitingOptions(
          timeout: Duration(seconds: 2),
          pollingInterval: Duration(milliseconds: 50),
        ),
      );
      expect(result.nonce.value, equals(6));

      mockProvider.setAccount(
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(10),
          balance: Balance.zero(),
        ),
      );
      final immediateResult = await awaiter.awaitNonceIncrement(
        testAddress,
        const Nonce(5),
      );
      expect(immediateResult.nonce.value, equals(10));
    });

    test('handles balance monitoring', () async {
      final targetBalance = Balance.fromEgld(5.0);
      mockProvider.setAccountSequence([
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(1),
          balance: Balance.fromEgld(1.0),
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(1),
          balance: Balance.fromEgld(3.0),
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(1),
          balance: Balance.fromEgld(5.0),
        ),
      ]);

      final result = await awaiter.awaitMinimumBalance(
        testAddress,
        targetBalance,
        options: const AccountAwaitingOptions(
          timeout: Duration(seconds: 2),
          pollingInterval: Duration(milliseconds: 50),
        ),
      );
      expect(result.balance, greaterThanOrEqualTo(targetBalance));

      final initialBalance = Balance.fromEgld(10.0);
      mockProvider.setAccountSequence([
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(1),
          balance: initialBalance,
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(1),
          balance: initialBalance,
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(1),
          balance: Balance.fromEgld(8.0),
        ),
      ]);

      final changeResult = await awaiter.awaitBalanceChange(
        testAddress,
        initialBalance,
        options: const AccountAwaitingOptions(
          timeout: Duration(seconds: 2),
          pollingInterval: Duration(milliseconds: 50),
        ),
      );
      expect(changeResult.balance, isNot(equals(initialBalance)));
    });
  });

  group('Custom Conditions & Error Handling', () {
    test('handles custom condition waiting', () async {
      mockProvider.setAccountSequence([
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(1),
          balance: Balance.fromEgld(5.0),
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(2),
          balance: Balance.fromEgld(5.0),
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(3),
          balance: Balance.fromEgld(5.0),
        ),
      ]);

      final result = await awaiter.awaitOnCondition(
        testAddress,
        (account) => account.nonce.value == 3,
        options: const AccountAwaitingOptions(
          timeout: Duration(seconds: 2),
          pollingInterval: Duration(milliseconds: 50),
        ),
      );
      expect(result.nonce.value, equals(3));

      mockProvider.setAccountSequence([
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(10),
          balance: Balance.fromEgld(50.0),
        ),
      ]);

      final complexResult = await awaiter.awaitOnCondition(
        testAddress,
        (account) =>
            account.nonce >= const Nonce(10) &&
            account.balance >= Balance.fromEgld(50.0),
        options: const AccountAwaitingOptions(
          timeout: Duration(seconds: 1),
          pollingInterval: Duration(milliseconds: 50),
        ),
      );
      expect(complexResult.nonce.value, equals(10));
      expect(
        complexResult.balance,
        greaterThanOrEqualTo(Balance.fromEgld(50.0)),
      );
    });

    test('handles timeout and error scenarios', () async {
      mockProvider.setAccount(
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(5),
          balance: Balance.zero(),
        ),
      );

      expect(
        () => awaiter.awaitNonceIncrement(
          testAddress,
          const Nonce(5),
          options: const AccountAwaitingOptions(
            timeout: Duration(milliseconds: 100),
            pollingInterval: Duration(milliseconds: 50),
          ),
        ),
        throwsA(isA<AccountAwaiterTimeoutException>()),
      );

      expect(
        () => awaiter.awaitOnCondition(
          testAddress,
          (account) => false,
          options: const AccountAwaitingOptions(
            timeout: Duration(milliseconds: 100),
            pollingInterval: Duration(milliseconds: 50),
          ),
        ),
        throwsA(isA<AccountAwaiterTimeoutException>()),
      );
    });
  });

  group('Integration Scenarios', () {
    test('handles transaction confirmation workflow', () async {
      const initialNonce = 42;
      final initialBalance = Balance.fromEgld(100.0);
      final txCost = Balance.fromEgld(0.5);

      mockProvider.setAccountSequence([
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(initialNonce),
          balance: initialBalance,
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(initialNonce),
          balance: initialBalance,
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(initialNonce + 1),
          balance: initialBalance - txCost,
        ),
      ]);

      final confirmedAccount = await awaiter.awaitNonceIncrement(
        testAddress,
        const Nonce(initialNonce),
        options: const AccountAwaitingOptions(
          timeout: Duration(seconds: 2),
          pollingInterval: Duration(milliseconds: 50),
        ),
      );

      expect(confirmedAccount.nonce.value, equals(initialNonce + 1));
      expect(confirmedAccount.balance.value, lessThan(initialBalance.value));
    });

    test('handles deposit and rapid state changes', () async {
      final depositAmount = Balance.fromEgld(25.0);
      mockProvider.setAccountSequence([
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(1),
          balance: Balance.fromEgld(10.0),
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(1),
          balance: Balance.fromEgld(35.0),
        ),
      ]);

      final result = await awaiter.awaitMinimumBalance(
        testAddress,
        depositAmount,
        options: const AccountAwaitingOptions(
          timeout: Duration(seconds: 2),
          pollingInterval: Duration(milliseconds: 50),
        ),
      );
      expect(result.balance, greaterThanOrEqualTo(depositAmount));

      mockProvider.setAccountSequence([
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(1),
          balance: Balance.fromEgld(1.0),
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(2),
          balance: Balance.fromEgld(2.0),
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(3),
          balance: Balance.fromEgld(3.0),
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(4),
          balance: Balance.fromEgld(4.0),
        ),
        AccountOnNetwork(
          address: testAddress,
          nonce: const Nonce(5),
          balance: Balance.fromEgld(5.0),
        ),
      ]);

      final rapidChangeResult = await awaiter.awaitOnCondition(
        testAddress,
        (account) => account.nonce.value >= 5,
        options: const AccountAwaitingOptions(
          timeout: Duration(seconds: 2),
          pollingInterval: Duration(milliseconds: 20),
        ),
      );
      expect(rapidChangeResult.nonce.value, equals(5));
      expect(
        rapidChangeResult.balance.value,
        equals(Balance.fromEgld(5.0).value),
      );
    });
  });
}
