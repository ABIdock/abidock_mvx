import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// Literal EGLD input paired with the exact attoEGLD integer it denotes.
const List<(num, String)> _egldToAtto = <(num, String)>[
  (0.1, '100000000000000000'),
  (0.2, '200000000000000000'),
  (0.3, '300000000000000000'),
  (0.7, '700000000000000000'),
  (0.9, '900000000000000000'),
  (1, '1000000000000000000'),
  (1.0, '1000000000000000000'),
  (1.5, '1500000000000000000'),
  (0.5, '500000000000000000'),
  (0.25, '250000000000000000'),
  (0.01, '10000000000000000'),
  (2.5, '2500000000000000000'),
  (0.001, '1000000000000000'),
  (1.1, '1100000000000000000'),
  (3.7, '3700000000000000000'),
  (100.35, '100350000000000000000'),
  (1250, '1250000000000000000000'),
  (2500, '2500000000000000000000'),
  (0.123456789012345, '123456789012345000'),
  (0.000000000000000001, '1'),
  (0.00000000000000001, '10'),
  (0.000000000000000123, '123'),
];

void main() {
  group('Balance.fromEgld exactness', () {
    for (final (num input, String expected) in _egldToAtto) {
      test('fromEgld($input) is exactly $expected attoEGLD', () {
        expect(Balance.fromEgld(input).value, BigInt.parse(expected));
      });
    }

    test('fromEgld(0.1) does not overshoot by 6 atto', () {
      expect(Balance.fromEgld(0.1).value.toString(), '100000000000000000');
      expect(
        Balance.fromEgld(0.1).value,
        isNot(BigInt.parse('100000000000000006')),
      );
    });

    test('fromEgld(0.3) does not fall 11 atto short', () {
      expect(Balance.fromEgld(0.3).value.toString(), '300000000000000000');
      expect(
        Balance.fromEgld(0.3).value,
        isNot(BigInt.parse('299999999999999989')),
      );
    });

    test('fromEgld agrees with fromEgldString for the same decimal', () {
      const List<(num, String)> pairs = <(num, String)>[
        (0.1, '0.1'),
        (0.3, '0.3'),
        (0.7, '0.7'),
        (1.5, '1.5'),
        (0.01, '0.01'),
        (2500, '2500'),
        (0.123456789012345, '0.123456789012345'),
      ];
      for (final (num value, String text) in pairs) {
        expect(
          Balance.fromEgld(value).value,
          Balance.fromEgldString(text).value,
          reason: 'fromEgld($value) must match fromEgldString(\'$text\')',
        );
      }
    });

    test('summed decimal balances land on the exact total', () {
      final Balance total =
          Balance.fromEgld(0.1) + Balance.fromEgld(0.2) + Balance.fromEgld(0.3);
      expect(total.value, BigInt.parse('600000000000000000'));
      expect(total.toDenominatedTrimmed, '0.6');
    });

    test('zero in every spelling is zero', () {
      expect(Balance.fromEgld(0).value, BigInt.zero);
      expect(Balance.fromEgld(0.0).value, BigInt.zero);
      expect(Balance.fromEgld(-0.0).value, BigInt.zero);
    });
  });

  group('Balance.fromEgld reports the double it was given', () {
    test('float arithmetic converts to the double it produced', () {
      expect(
        Balance.fromEgld(0.1 + 0.2).value,
        BigInt.parse('300000000000000040'),
      );
      expect(
        Balance.fromEgld(0.30000000000000004).value,
        BigInt.parse('300000000000000040'),
      );
    });

    test('int input is scaled exactly beyond double precision', () {
      expect(
        Balance.fromEgld(9007199254740993).value,
        BigInt.parse('9007199254740993000000000000000000'),
      );
    });
  });

  group('Balance.fromEgld magnitude handling', () {
    test('values at and beyond 1e21 EGLD convert instead of failing', () {
      expect(
        Balance.fromEgld(1e21).value,
        BigInt.parse('1000000000000000000000000000000000000000'),
      );
      expect(
        Balance.fromEgld(1.5e21).value,
        BigInt.parse('1500000000000000000000000000000000000000'),
      );
    });

    test('the smallest unit is one attoEGLD', () {
      expect(Balance.fromEgld(1e-18).value, BigInt.one);
      expect(Balance.fromEgld(1e-17).value, BigInt.from(10));
    });
  });

  group('Balance.fromEgld rejects unrepresentable input', () {
    test('more than 18 decimals throws instead of truncating', () {
      expect(() => Balance.fromEgld(1e-19), throwsArgumentError);
      expect(() => Balance.fromEgld(1.5e-18), throwsArgumentError);
      expect(() => Balance.fromEgld(1e-30), throwsArgumentError);
    });

    test('non-finite values throw', () {
      expect(() => Balance.fromEgld(double.nan), throwsArgumentError);
      expect(() => Balance.fromEgld(double.infinity), throwsArgumentError);
      expect(
        () => Balance.fromEgld(double.negativeInfinity),
        throwsArgumentError,
      );
    });
  });

  group('Balance.fromEgldString stays exact', () {
    test('decimal strings convert to exact attoEGLD', () {
      expect(
        Balance.fromEgldString('0.1').value,
        BigInt.parse('100000000000000000'),
      );
      expect(
        Balance.fromEgldString('0.3').value,
        BigInt.parse('300000000000000000'),
      );
      expect(
        Balance.fromEgldString('2.5').value,
        BigInt.parse('2500000000000000000'),
      );
      expect(
        Balance.fromEgldString('.5').value,
        BigInt.parse('500000000000000000'),
      );
      expect(Balance.fromEgldString('0.000000000000000001').value, BigInt.one);
      expect(Balance.fromEgldString('0').value, BigInt.zero);
      expect(Balance.fromEgldString('0.0').value, BigInt.zero);
    });

    test('round-trips through the denominated string', () {
      for (final (num input, String expected) in _egldToAtto) {
        final Balance balance = Balance.fromEgld(input);
        expect(
          Balance.fromEgldString(balance.toDenominated).value,
          BigInt.parse(expected),
        );
      }
    });
  });
}
