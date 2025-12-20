import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  late ArgSerializer serializer;
  late TokenTransfersDataBuilder builder;
  late Address testDestination;
  setUp(() {
    serializer = ArgSerializer();
    builder = TokenTransfersDataBuilder(serializer: serializer);
    testDestination = Address.fromBech32(
      'erd1qqqqqqqqqqqqqpgqp699jngundfqw07d8jzkepucvpzush6k3wvqyc44rx',
    );
  });
  group('TokenTransfersDataBuilder - ESDTTransfer (Fungible)', () {
    test('builds data parts for fungible token transfer', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'MYTOKEN-abcdef',
        amount: BigInt.from(1000),
      );
      final parts = builder.buildDataPartsForESDTTransfer(transfer);
      expect(parts.length, 3);
      expect(parts[0], 'ESDTTransfer');
      expect(parts[1], isNotEmpty);
      expect(parts[2], isNotEmpty);
    });
    test('builds data parts for EGLD-like fungible transfer', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'WEGLD-abcdef',
        amount: BigInt.parse('1000000000000000000'),
      );
      final parts = builder.buildDataPartsForESDTTransfer(transfer);
      expect(parts[0], 'ESDTTransfer');
      expect(parts.length, 3);
    });
    test('builds data parts with small amount', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'TOKEN-123456',
        amount: BigInt.one,
      );
      final parts = builder.buildDataPartsForESDTTransfer(transfer);
      expect(parts[0], 'ESDTTransfer');
      expect(parts.length, 3);
    });
    test('builds data parts with large amount', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'TOKEN-123456',
        amount: BigInt.parse('999999999999999999999999'),
      );
      final parts = builder.buildDataPartsForESDTTransfer(transfer);
      expect(parts[0], 'ESDTTransfer');
      expect(parts.length, 3);
    });
    test('throws when NFT token has nonce', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'MYNFT-abcdef',
        amount: BigInt.one,
        nonce: BigInt.from(42),
      );
      expect(
        () => builder.buildDataPartsForESDTTransfer(transfer),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('requires fungible token (no nonce)'),
          ),
        ),
      );
    });
    test('throws when SFT token has nonce', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'MYSFT-123456',
        amount: BigInt.from(10),
        nonce: BigInt.from(5),
      );
      expect(
        () => builder.buildDataPartsForESDTTransfer(transfer),
        throwsArgumentError,
      );
    });
  });
  group('TokenTransfersDataBuilder - ESDTNFTTransfer (Single NFT)', () {
    test('builds data parts for NFT transfer', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'MYNFT-abcdef',
        amount: BigInt.one,
        nonce: BigInt.from(42),
      );
      final parts = builder.buildDataPartsForSingleESDTNFTTransfer(
        transfer,
        testDestination,
      );
      expect(parts.length, 5);
      expect(parts[0], 'ESDTNFTTransfer');
      expect(parts[1], isNotEmpty);
      expect(parts[2], isNotEmpty);
      expect(parts[3], isNotEmpty);
      expect(parts[4], isNotEmpty);
    });
    test('builds data parts for SFT transfer', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'MYSFT-123456',
        amount: BigInt.from(10),
        nonce: BigInt.from(7),
      );
      final parts = builder.buildDataPartsForSingleESDTNFTTransfer(
        transfer,
        testDestination,
      );
      expect(parts[0], 'ESDTNFTTransfer');
      expect(parts.length, 5);
    });
    test('builds data parts with nonce 1', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'NFT-aabbcc',
        amount: BigInt.one,
        nonce: BigInt.one,
      );
      final parts = builder.buildDataPartsForSingleESDTNFTTransfer(
        transfer,
        testDestination,
      );
      expect(parts[0], 'ESDTNFTTransfer');
      expect(parts.length, 5);
    });
    test('builds data parts with large nonce', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'NFT-aabbcc',
        amount: BigInt.one,
        nonce: BigInt.parse('999999999'),
      );
      final parts = builder.buildDataPartsForSingleESDTNFTTransfer(
        transfer,
        testDestination,
      );
      expect(parts[0], 'ESDTNFTTransfer');
      expect(parts.length, 5);
    });
    test('builds data parts with multiple amount', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'SFT-123456',
        amount: BigInt.from(100),
        nonce: BigInt.from(3),
      );
      final parts = builder.buildDataPartsForSingleESDTNFTTransfer(
        transfer,
        testDestination,
      );
      expect(parts[0], 'ESDTNFTTransfer');
      expect(parts.length, 5);
    });
    test('throws when fungible token has no nonce', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'MYTOKEN-abcdef',
        amount: BigInt.from(1000),
      );
      expect(
        () => builder.buildDataPartsForSingleESDTNFTTransfer(
          transfer,
          testDestination,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('requires NFT/SFT token (with nonce)'),
          ),
        ),
      );
    });
  });
  group(
    'TokenTransfersDataBuilder - MultiESDTNFTTransfer (Multiple Tokens)',
    () {
      test('builds data parts for multiple fungible tokens', () {
        final transfers = [
          TokenTransferValue.fromPrimitives(
            tokenIdentifier: 'TOKEN1-abcdef',
            amount: BigInt.from(100),
          ),
          TokenTransferValue.fromPrimitives(
            tokenIdentifier: 'TOKEN2-123456',
            amount: BigInt.from(200),
          ),
        ];
        final parts = builder.buildDataPartsForMultiESDTNFTTransfer(
          testDestination,
          transfers,
        );
        expect(parts[0], 'MultiESDTNFTTransfer');
        expect(parts.length, greaterThan(3));
        expect(parts[1], isNotEmpty);
        expect(parts[2], isNotEmpty);
      });
      test('builds data parts for multiple NFTs', () {
        final transfers = [
          TokenTransferValue.fromPrimitives(
            tokenIdentifier: 'NFT1-abcdef',
            amount: BigInt.one,
            nonce: BigInt.from(5),
          ),
          TokenTransferValue.fromPrimitives(
            tokenIdentifier: 'NFT2-123456',
            amount: BigInt.one,
            nonce: BigInt.from(10),
          ),
        ];
        final parts = builder.buildDataPartsForMultiESDTNFTTransfer(
          testDestination,
          transfers,
        );
        expect(parts[0], 'MultiESDTNFTTransfer');
        expect(parts.length, greaterThan(3));
      });
      test('builds data parts for mixed fungible and NFT', () {
        final transfers = [
          TokenTransferValue.fromPrimitives(
            tokenIdentifier: 'FUNGIBLE-abcdef',
            amount: BigInt.from(1000),
          ),
          TokenTransferValue.fromPrimitives(
            tokenIdentifier: 'NFT-abcdef',
            amount: BigInt.one,
            nonce: BigInt.from(42),
          ),
          TokenTransferValue.fromPrimitives(
            tokenIdentifier: 'SFT-abcdef',
            amount: BigInt.from(5),
            nonce: BigInt.from(7),
          ),
        ];
        final parts = builder.buildDataPartsForMultiESDTNFTTransfer(
          testDestination,
          transfers,
        );
        expect(parts[0], 'MultiESDTNFTTransfer');
        expect(parts.length, greaterThan(3));
      });
      test('builds data parts for single transfer (edge case)', () {
        final transfers = [
          TokenTransferValue.fromPrimitives(
            tokenIdentifier: 'TOKEN-abcdef',
            amount: BigInt.from(500),
          ),
        ];
        final parts = builder.buildDataPartsForMultiESDTNFTTransfer(
          testDestination,
          transfers,
        );
        expect(parts[0], 'MultiESDTNFTTransfer');
        expect(parts.length, greaterThan(3));
      });
      test('builds data parts with many transfers', () {
        final transfers = List.generate(
          10,
          (i) => TokenTransferValue.fromPrimitives(
            tokenIdentifier: 'TOKEN$i-abcdef',
            amount: BigInt.from(i + 1),
          ),
        );
        final parts = builder.buildDataPartsForMultiESDTNFTTransfer(
          testDestination,
          transfers,
        );
        expect(parts[0], 'MultiESDTNFTTransfer');
        expect(parts.length, greaterThan(3));
      });
      test('encodes fungible tokens with nonce zero', () {
        final transfers = [
          TokenTransferValue.fromPrimitives(
            tokenIdentifier: 'FUNGIBLE-abc',
            amount: BigInt.from(1000),
          ),
        ];
        final parts = builder.buildDataPartsForMultiESDTNFTTransfer(
          testDestination,
          transfers,
        );
        expect(parts[0], 'MultiESDTNFTTransfer');
        expect(parts.length, greaterThan(3));
      });
      test('throws when transfers list is empty', () {
        expect(
          () => builder.buildDataPartsForMultiESDTNFTTransfer(
            testDestination,
            [],
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('requires at least one transfer'),
            ),
          ),
        );
      });
    },
  );
  group('TokenTransfersDataBuilder - Real-World Scenarios', () {
    test('builds standard ESDT transfer for DEX swap', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'USDC-a1b2c3',
        amount: BigInt.parse('1000000'),
      );
      final parts = builder.buildDataPartsForESDTTransfer(transfer);
      expect(parts[0], 'ESDTTransfer');
      expect(parts.length, 3);
    });
    test('builds NFT transfer for marketplace purchase', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'COLLECTION-a1b2c3',
        amount: BigInt.one,
        nonce: BigInt.from(12345),
      );
      final parts = builder.buildDataPartsForSingleESDTNFTTransfer(
        transfer,
        testDestination,
      );
      expect(parts[0], 'ESDTNFTTransfer');
      expect(parts.length, 5);
    });
    test('builds multi-token transfer for batch payment', () {
      final transfers = [
        TokenTransferValue.fromPrimitives(
          tokenIdentifier: 'USDC-a1b2c3',
          amount: BigInt.parse('50000000'),
        ),
        TokenTransferValue.fromPrimitives(
          tokenIdentifier: 'USDT-d4e5f6',
          amount: BigInt.parse('50000000'),
        ),
      ];
      final parts = builder.buildDataPartsForMultiESDTNFTTransfer(
        testDestination,
        transfers,
      );
      expect(parts[0], 'MultiESDTNFTTransfer');
      expect(parts.length, greaterThan(3));
    });
    test('builds transfer with custom token identifier', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'MYPROJECT-123abc',
        amount: BigInt.parse('999999999999999999'),
      );
      final parts = builder.buildDataPartsForESDTTransfer(transfer);
      expect(parts[0], 'ESDTTransfer');
      expect(parts.length, 3);
    });
  });
  group('TokenTransfersDataBuilder - Integration with ArgSerializer', () {
    test('encoded parts are valid hex strings', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'TOKEN-abcdef',
        amount: BigInt.from(1000),
      );
      final parts = builder.buildDataPartsForESDTTransfer(transfer);
      for (var i = 1; i < parts.length; i++) {
        expect(parts[i], matches(RegExp(r'^[0-9a-fA-F]*$')));
      }
    });
    test('encoded NFT parts are valid hex strings', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'NFT-abcdef',
        amount: BigInt.one,
        nonce: BigInt.from(42),
      );
      final parts = builder.buildDataPartsForSingleESDTNFTTransfer(
        transfer,
        testDestination,
      );
      for (var i = 1; i < parts.length; i++) {
        expect(parts[i], matches(RegExp(r'^[0-9a-fA-F]*$')));
      }
    });
    test('encoded multi-transfer parts are valid hex strings', () {
      final transfers = [
        TokenTransferValue.fromPrimitives(
          tokenIdentifier: 'TOKEN1-abc',
          amount: BigInt.from(100),
        ),
        TokenTransferValue.fromPrimitives(
          tokenIdentifier: 'TOKEN2-def',
          amount: BigInt.from(200),
        ),
      ];
      final parts = builder.buildDataPartsForMultiESDTNFTTransfer(
        testDestination,
        transfers,
      );
      for (var i = 1; i < parts.length; i++) {
        expect(parts[i], matches(RegExp(r'^[0-9a-fA-F]*$')));
      }
    });
  });
  group('TokenTransfersDataBuilder - Edge Cases', () {
    test('handles token identifier with special characters', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'TOKEN-a1b2c3',
        amount: BigInt.from(100),
      );
      final parts = builder.buildDataPartsForESDTTransfer(transfer);
      expect(parts[0], 'ESDTTransfer');
      expect(parts.length, 3);
    });
    test('handles very long token identifier', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'VERYLONGTOKENNAME-a1b2c3d4e5f6',
        amount: BigInt.from(100),
      );
      final parts = builder.buildDataPartsForESDTTransfer(transfer);
      expect(parts[0], 'ESDTTransfer');
      expect(parts.length, 3);
    });
    test('handles different destination addresses', () {
      final altDestination = Address.fromBech32(
        'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx',
      );
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'NFT-abc',
        amount: BigInt.one,
        nonce: BigInt.from(1),
      );
      final parts = builder.buildDataPartsForSingleESDTNFTTransfer(
        transfer,
        altDestination,
      );
      expect(parts[0], 'ESDTNFTTransfer');
      expect(parts.length, 5);
    });
    test('handles zero amount for NFT (valid)', () {
      final transfer = TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'NFT-abc',
        amount: BigInt.zero,
        nonce: BigInt.from(1),
      );
      final parts = builder.buildDataPartsForSingleESDTNFTTransfer(
        transfer,
        testDestination,
      );
      expect(parts[0], 'ESDTNFTTransfer');
      expect(parts.length, 5);
    });
  });
  group('TokenTransfersDataBuilder - Constructor', () {
    test('creates builder with serializer', () {
      final customSerializer = ArgSerializer();
      final customBuilder = TokenTransfersDataBuilder(
        serializer: customSerializer,
      );
      expect(customBuilder.serializer, same(customSerializer));
    });
  });
}
