import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('ChainId', () {
    test('creates mainnet chain', () {
      const chain = ChainId.mainnet();
      expect(chain.value, '1');
      expect(chain.isMainnet, isTrue);
      expect(chain.isDevnet, isFalse);
      expect(chain.isTestnet, isFalse);
    });
    test('creates devnet chain', () {
      const chain = ChainId.devnet();
      expect(chain.value, 'D');
      expect(chain.isMainnet, isFalse);
      expect(chain.isDevnet, isTrue);
      expect(chain.isTestnet, isFalse);
    });
    test('creates testnet chain', () {
      const chain = ChainId.testnet();
      expect(chain.value, 'T');
      expect(chain.isMainnet, isFalse);
      expect(chain.isDevnet, isFalse);
      expect(chain.isTestnet, isTrue);
    });
    test('creates from value', () {
      const mainnet = ChainId('1');
      expect(mainnet.isMainnet, isTrue);
      const devnet = ChainId('D');
      expect(devnet.isDevnet, isTrue);
      const testnet = ChainId('T');
      expect(testnet.isTestnet, isTrue);
    });
    test('rejects invalid chain ID', () {
      expect(() => ChainId('X'), throwsA(isA<AssertionError>()));
      expect(() => ChainId(''), throwsA(isA<AssertionError>()));
      expect(() => ChainId('M'), throwsA(isA<AssertionError>()));
    });
    test('equals same chain ID', () {
      const chain1 = ChainId('1');
      const chain2 = ChainId.mainnet();
      expect(chain1, equals(chain2));
    });
    test('not equals different chain ID', () {
      const mainnet = ChainId.mainnet();
      const devnet = ChainId.devnet();
      expect(mainnet, isNot(equals(devnet)));
    });
    test('has consistent hashCode', () {
      const chain1 = ChainId('D');
      const chain2 = ChainId.devnet();
      expect(chain1.hashCode, equals(chain2.hashCode));
    });
    test('toString includes value', () {
      const chain = ChainId.mainnet();
      expect(chain.toString(), contains('1'));
    });
  });
}
