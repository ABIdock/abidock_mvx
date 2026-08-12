@Tags(<String>['integration'])
library;

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  const aliceAddress =
      'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8';
  late ApiNetworkProvider provider;

  setUp(() {
    provider = ApiNetworkProvider.devnet();
  });

  group('Token Integration', () {
    test('should fetch and parse fungible tokens', () async {
      final address = Address.fromBech32(aliceAddress);
      final tokens = await provider.getFungibleTokensOfAccount(address);

      expect(tokens, isNotEmpty);
      final token = tokens.first;
      expect(token.identifier, isNotEmpty);
      expect(token.balance, isNotEmpty);
      expect(token.decimals, greaterThanOrEqualTo(0));
      expect(token.type, isNotNull);
      expect(token.isFungible, isTrue);
      expect(token.isNft, isFalse);
    });

    test('should format token balance and display properties', () async {
      final address = Address.fromBech32(aliceAddress);
      final tokens = await provider.getFungibleTokensOfAccount(address);

      expect(tokens, isNotEmpty);
      final token = tokens.first;
      final formatted = token.formatBalance(decimalPlaces: 2);
      final denominated = token.denominatedBalance;
      final balanceBigInt = token.balanceAsBigInt;
      final display = token.displayString;

      expect(formatted, isNotEmpty);
      expect(denominated, greaterThanOrEqualTo(0));
      expect(balanceBigInt, greaterThan(BigInt.zero));
      expect(display, contains(token.ticker ?? token.identifier));
    });

    test('should query NFTs and handle metadata safely', () async {
      final address = Address.fromBech32(aliceAddress);

      final nfts = await provider.getNonFungibleTokensOfAccount(address);
      expect(nfts, isA<List<TokenOnNetwork>>());

      final tokens = await provider.getFungibleTokensOfAccount(address);
      if (tokens.isNotEmpty) {
        final token = tokens.first;
        final raw = token.raw;
        expect(raw, isA<Map<String, dynamic>>());
        expect(() => token.name, returnsNormally);
        expect(() => token.owner, returnsNormally);
        expect(() => token.assets, returnsNormally);
      }
    });
  });
}
