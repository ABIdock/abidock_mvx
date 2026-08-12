import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  final TokenManagementTransactionsFactory factory =
      TokenManagementTransactionsFactory(
        config: const TokenManagementConfig(chainId: ChainId('D')),
      );
  final Address sender = Address.fromBech32(
    'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
  );
  final Address user = Address.fromBech32(
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  );

  String dataOf(Transaction tx) => utf8.decode(tx.data);

  group('H-6 ESDT supernova roles wired into setSpecialRole', () {
    test('emits ESDTRoleNFTUpdate when role string passed', () {
      final Transaction tx = factory
          .createTransactionForSettingSpecialRoleOnNonFungibleToken(
            sender: sender,
            user: user,
            tokenIdentifier: 'COLL-abc123',
            roles: const <String>['ESDTRoleNFTUpdate'],
          );
      expect(dataOf(tx), startsWith('setSpecialRole@'));
      expect(dataOf(tx), contains('@${_hex('ESDTRoleNFTUpdate')}'));
    });

    test('emits ESDTRoleNFTRecreate when role string passed', () {
      final Transaction tx = factory
          .createTransactionForSettingSpecialRoleOnNonFungibleToken(
            sender: sender,
            user: user,
            tokenIdentifier: 'COLL-abc123',
            roles: const <String>['ESDTRoleNFTRecreate'],
          );
      expect(dataOf(tx), contains('@${_hex('ESDTRoleNFTRecreate')}'));
    });

    test('emits ESDTRoleSetNewURI when role string passed', () {
      final Transaction tx = factory
          .createTransactionForSettingSpecialRoleOnNonFungibleToken(
            sender: sender,
            user: user,
            tokenIdentifier: 'COLL-abc123',
            roles: const <String>['ESDTRoleSetNewURI'],
          );
      expect(dataOf(tx), contains('@${_hex('ESDTRoleSetNewURI')}'));
    });

    test('emits ESDTRoleModifyCreator when role string passed', () {
      final Transaction tx = factory
          .createTransactionForSettingSpecialRoleOnNonFungibleToken(
            sender: sender,
            user: user,
            tokenIdentifier: 'COLL-abc123',
            roles: const <String>['ESDTRoleModifyCreator'],
          );
      expect(dataOf(tx), contains('@${_hex('ESDTRoleModifyCreator')}'));
    });

    test('emits ESDTRoleModifyRoyalties when role string passed', () {
      final Transaction tx = factory
          .createTransactionForSettingSpecialRoleOnNonFungibleToken(
            sender: sender,
            user: user,
            tokenIdentifier: 'COLL-abc123',
            roles: const <String>['ESDTRoleModifyRoyalties'],
          );
      expect(dataOf(tx), contains('@${_hex('ESDTRoleModifyRoyalties')}'));
    });

    test('TokenManagementController emits ESDTRoleNFTUpdate via flag', () {
      final TokenManagementController controller = TokenManagementController(
        chainId: const ChainId('D'),
      );
      final Transaction tx = controller.factory
          .createTransactionForSettingSpecialRoleOnNonFungibleToken(
            sender: sender,
            user: user,
            tokenIdentifier: 'COLL-abc123',
            roles: const <String>[
              'ESDTRoleNFTUpdate',
              'ESDTRoleNFTRecreate',
              'ESDTRoleSetNewURI',
              'ESDTRoleModifyCreator',
              'ESDTRoleModifyRoyalties',
            ],
          );
      final String data = dataOf(tx);
      expect(data, contains(_hex('ESDTRoleNFTUpdate')));
      expect(data, contains(_hex('ESDTRoleNFTRecreate')));
      expect(data, contains(_hex('ESDTRoleSetNewURI')));
      expect(data, contains(_hex('ESDTRoleModifyCreator')));
      expect(data, contains(_hex('ESDTRoleModifyRoyalties')));
    });
  });

  group('H-7 new ESDT function-name endpoints', () {
    test('createTransactionForNftUpdate emits ESDTNFTUpdate payload', () {
      final Transaction tx = factory.createTransactionForNftUpdate(
        sender: sender,
        tokenIdentifier: 'COLL-abc123',
        nonce: 1,
        newName: 'NewName',
        newRoyalties: 500,
        newHash: 'h',
        newAttributes: Uint8List.fromList(<int>[0xAA, 0xBB]),
        newUris: const <String>['https://x'],
      );
      final String data = dataOf(tx);
      expect(data, startsWith('ESDTNFTUpdate@'));
      expect(data, contains(_hex('COLL-abc123')));
      expect(data, contains(_hex('NewName')));
    });

    test('createTransactionForNftRecreate emits ESDTNFTRecreate payload', () {
      final Transaction tx = factory.createTransactionForNftRecreate(
        sender: sender,
        tokenIdentifier: 'COLL-abc123',
        nonce: 1,
        newName: 'NewName',
        newRoyalties: 500,
      );
      expect(dataOf(tx), startsWith('ESDTNFTRecreate@'));
    });

    test('createTransactionForSettingNewUris emits ESDTSetNewURIs payload', () {
      final Transaction tx = factory.createTransactionForSettingNewUris(
        sender: sender,
        tokenIdentifier: 'COLL-abc123',
        nonce: 1,
        newUris: const <String>['https://a', 'https://b'],
      );
      expect(dataOf(tx), startsWith('ESDTSetNewURIs@'));
    });

    test('createTransactionForModifyingCreator emits ESDTModifyCreator', () {
      final Transaction tx = factory.createTransactionForModifyingCreator(
        sender: sender,
        tokenIdentifier: 'COLL-abc123',
        nonce: 1,
      );
      expect(dataOf(tx), startsWith('ESDTModifyCreator@'));
    });

    test(
      'createTransactionForModifyingRoyalties emits ESDTModifyRoyalties',
      () {
        final Transaction tx = factory.createTransactionForModifyingRoyalties(
          sender: sender,
          tokenIdentifier: 'COLL-abc123',
          nonce: 1,
          newRoyalties: 500,
        );
        expect(dataOf(tx), startsWith('ESDTModifyRoyalties@'));
      },
    );
  });
}

String _hex(String s) {
  final StringBuffer sb = StringBuffer();
  for (final int b in utf8.encode(s)) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
