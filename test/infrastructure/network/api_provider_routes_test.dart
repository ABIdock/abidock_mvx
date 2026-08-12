/// Route-contract tests for [ApiNetworkProvider].
///
/// Every expectation is a literal URL string rather than a comparison against
/// the provider's own endpoint builders, so a regression in those builders
/// cannot make the assertions agree with themselves.
import 'dart:convert';
import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// Bech32 address reused across the route assertions.
const String alice =
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th';

/// Bech32 address used as the guardian in guardian fixtures.
const String guardian =
    'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8';

/// Contract address used as the receiver in transaction fixtures.
const String contract =
    'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8';

/// Dio adapter that records every request line and replays one canned body.
class RecordingAdapter implements HttpClientAdapter {
  /// Creates an adapter replaying `body` as a JSON response for any request.
  RecordingAdapter(this.body);

  /// JSON-encodable payload returned for every request.
  final Object body;

  /// Absolute request URIs seen, in order.
  final List<String> uris = <String>[];

  /// HTTP methods seen, in order.
  final List<String> methods = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    uris.add(options.uri.toString());
    methods.add(options.method);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: const <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Builds a provider whose HTTP traffic is captured by `adapter`.
ApiNetworkProvider providerWith(RecordingAdapter adapter) {
  final Dio dio = Dio();
  dio.httpClientAdapter = adapter;
  return ApiNetworkProvider(
    baseUrl: 'https://api.example.test',
    chainId: const ChainId('D'),
    client: dio,
  );
}

/// Builds a minimal signed-shaped transaction for POST routes.
Transaction sampleTransaction() {
  return Transaction(
    nonce: const Nonce(7),
    sender: Address.fromBech32(alice),
    receiver: Address.fromBech32(contract),
    value: Balance.fromString('0'),
    gasLimit: const GasLimit(60000000),
    gasPrice: const GasPrice(1000000000),
    chainId: const ChainId('D'),
    version: const TransactionVersion(1),
    data: Uint8List(0),
  );
}

void main() {
  group('ApiNetworkProvider route contract', () {
    test('getAccount sends withGuardianInfo=true', () async {
      final RecordingAdapter adapter = RecordingAdapter(<String, dynamic>{
        'address': alice,
        'nonce': 7,
        'balance': '1000000000000000000',
      });
      final ApiNetworkProvider provider = providerWith(adapter);

      await provider.getAccount(Address.fromBech32(alice));

      expect(
        adapter.uris.single,
        equals(
          'https://api.example.test/accounts/'
          'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'
          '?withGuardianInfo=true',
        ),
      );
      expect(adapter.methods.single, equals('GET'));
    });

    test('getTransaction never sends withResults', () async {
      final RecordingAdapter adapter = RecordingAdapter(<String, dynamic>{
        'txHash': 'aabbcc',
        'status': 'success',
        'sender': alice,
        'receiver': contract,
      });
      final ApiNetworkProvider provider = providerWith(adapter);

      await provider.getTransaction('aabbcc', withProcessStatus: true);
      await provider.getTransaction('aabbcc');

      expect(
        adapter.uris,
        equals(<String>[
          'https://api.example.test/transactions/aabbcc',
          'https://api.example.test/transactions/aabbcc',
        ]),
      );
    });

    test('getTransactionStatus asks only for the status field', () async {
      final RecordingAdapter adapter = RecordingAdapter(<String, dynamic>{
        'status': 'success',
      });
      final ApiNetworkProvider provider = providerWith(adapter);

      final TransactionStatus status = await provider.getTransactionStatus(
        'aabbcc',
      );

      expect(
        adapter.uris.single,
        equals('https://api.example.test/transactions/aabbcc?fields=status'),
      );
      expect(status.status, equals('success'));
    });

    test('simulateTransaction posts to the gateway passthrough', () async {
      final RecordingAdapter adapter = RecordingAdapter(<String, dynamic>{
        'data': <String, dynamic>{
          'result': <String, dynamic>{
            'sender': alice,
            'receiver': contract,
            'status': 'success',
            'value': '1000000000000000000',
            'nonce': 7,
            'gasLimit': 60000000,
            'gasPrice': 1000000000,
          },
        },
        'code': 'successful',
      });
      final ApiNetworkProvider provider = providerWith(adapter);

      final TransactionOnNetwork simulated = await provider.simulateTransaction(
        sampleTransaction(),
      );

      expect(
        adapter.uris.single,
        equals(
          'https://api.example.test/transaction/simulate?checkSignature=false',
        ),
      );
      expect(adapter.methods.single, equals('POST'));
      expect(
        simulated.sender.bech32,
        equals(
          'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
        ),
      );
      expect(
        simulated.receiver.bech32,
        equals(
          'erd1qqqqqqqqqqqqqpgq6wegs2xkypfpync8mn2sa5cmpqjlvrhwz5nqgepyg8',
        ),
      );
      expect(simulated.status.status, equals('success'));
      expect(
        simulated.value.value,
        equals(BigInt.parse('1000000000000000000')),
      );
    });

    test('getGuardianData hits the address passthrough route', () async {
      final RecordingAdapter adapter = RecordingAdapter(<String, dynamic>{
        'data': <String, dynamic>{
          'guardianData': <String, dynamic>{
            'guarded': true,
            'activeGuardian': <String, dynamic>{
              'address': guardian,
              'activationEpoch': 1234,
              'serviceUID': 'TCS',
            },
          },
        },
        'code': 'successful',
      });
      final ApiNetworkProvider provider = providerWith(adapter);

      final GuardianData data = await provider.getGuardianData(
        Address.fromBech32(alice),
      );

      expect(
        adapter.uris.single,
        equals(
          'https://api.example.test/address/'
          'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'
          '/guardian-data',
        ),
      );
      expect(data.guarded, isTrue);
      expect(
        data.activeGuardian!.address.bech32,
        equals(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
      );
      expect(data.activeGuardian!.activationEpoch, equals(1234));
    });

    test('getTokenOfAccount uses the tokens route for fungible ESDT', () async {
      final RecordingAdapter adapter = RecordingAdapter(<String, dynamic>{
        'identifier': 'WEGLD-bd4d79',
        'balance': '500000000000000000',
        'nonce': 0,
      });
      final ApiNetworkProvider provider = providerWith(adapter);

      final TokenOnNetwork token = await provider.getTokenOfAccount(
        Address.fromBech32(alice),
        'WEGLD-bd4d79',
      );

      expect(
        adapter.uris.single,
        equals(
          'https://api.example.test/accounts/'
          'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'
          '/tokens/WEGLD-bd4d79',
        ),
      );
      expect(token.balance, equals('500000000000000000'));
    });

    test('getTokenOfAccount uses the nfts route for extended '
        'identifiers', () async {
      final RecordingAdapter adapter = RecordingAdapter(<String, dynamic>{
        'identifier': 'MEXFARML-28d646-2b3b',
        'balance': '1',
        'nonce': 11067,
      });
      final ApiNetworkProvider provider = providerWith(adapter);

      final TokenOnNetwork token = await provider.getTokenOfAccount(
        Address.fromBech32(alice),
        'MEXFARML-28d646-2b3b',
      );

      expect(
        adapter.uris.single,
        equals(
          'https://api.example.test/accounts/'
          'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th'
          '/nfts/MEXFARML-28d646-2b3b',
        ),
      );
      expect(token.nonce, equals(11067));
      expect(token.balance, equals('1'));
    });

    test('estimateTransactionCost posts to the cost passthrough', () async {
      final RecordingAdapter adapter = RecordingAdapter(<String, dynamic>{
        'data': <String, dynamic>{'txGasUnits': 57500},
        'code': 'successful',
      });
      final ApiNetworkProvider provider = providerWith(adapter);

      final Map<String, dynamic> cost = await provider.estimateTransactionCost(
        sampleTransaction(),
      );

      expect(
        adapter.uris.single,
        equals('https://api.example.test/transaction/cost'),
      );
      expect(adapter.methods.single, equals('POST'));
      expect(cost['gasLimit'], equals(57500));
      expect(cost['status'], equals('success'));
    });

    test('getHyperblock hits the by-nonce passthrough', () async {
      final RecordingAdapter adapter = RecordingAdapter(<String, dynamic>{
        'data': <String, dynamic>{
          'hyperblock': <String, dynamic>{
            'hash':
                '9a1c2f2e2b1a0c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d',
            'nonce': 42,
            'round': 43,
            'epoch': 5,
            'shardBlocks': <dynamic>[],
            'transactions': <dynamic>[],
          },
        },
        'code': 'successful',
      });
      final ApiNetworkProvider provider = providerWith(adapter);

      final HyperblockOnNetwork hyperblock = await provider.getHyperblock(42);

      expect(
        adapter.uris.single,
        equals('https://api.example.test/hyperblock/by-nonce/42'),
      );
      expect(hyperblock.nonce, equals(42));
      expect(
        hyperblock.hash,
        equals(
          '9a1c2f2e2b1a0c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d',
        ),
      );
    });
  });

  group('ApiNetworkProvider account guardian parsing', () {
    test(
      'flat guardian fields populate activeGuardian and isGuarded',
      () async {
        final RecordingAdapter adapter = RecordingAdapter(<String, dynamic>{
          'address': alice,
          'nonce': 7,
          'balance': '1000000000000000000',
          'isGuarded': true,
          'activeGuardianAddress': guardian,
          'activeGuardianActivationEpoch': 42,
          'activeGuardianServiceUid': 'TCS',
        });
        final ApiNetworkProvider provider = providerWith(adapter);

        final AccountOnNetwork account = await provider.getAccount(
          Address.fromBech32(alice),
        );

        expect(account.hasActiveGuardian, isTrue);
        expect(
          account.activeGuardian!.address.bech32,
          equals(
            'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
          ),
        );
        expect(account.activeGuardian!.activationEpoch, equals(42));
        expect(account.activeGuardian!.serviceUID, equals('TCS'));
        expect(account.hasPendingGuardian, isFalse);
        expect(account.isGuarded, isTrue);
      },
    );

    test('flat pending guardian fields populate pendingGuardian', () async {
      final RecordingAdapter adapter = RecordingAdapter(<String, dynamic>{
        'address': alice,
        'nonce': 7,
        'balance': '1000000000000000000',
        'isGuarded': false,
        'pendingGuardianAddress': guardian,
        'pendingGuardianActivationEpoch': 99,
        'pendingGuardianServiceUid': 'TCS',
      });
      final ApiNetworkProvider provider = providerWith(adapter);

      final AccountOnNetwork account = await provider.getAccount(
        Address.fromBech32(alice),
      );

      expect(account.hasActiveGuardian, isFalse);
      expect(account.hasPendingGuardian, isTrue);
      expect(account.pendingGuardian!.activationEpoch, equals(99));
      expect(
        account.pendingGuardian!.address.bech32,
        equals(
          'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
        ),
      );
      expect(account.isGuarded, isTrue);
    });

    test('an unguarded account reports no guardians', () async {
      final RecordingAdapter adapter = RecordingAdapter(<String, dynamic>{
        'address': alice,
        'nonce': 7,
        'balance': '1000000000000000000',
        'isGuarded': false,
      });
      final ApiNetworkProvider provider = providerWith(adapter);

      final AccountOnNetwork account = await provider.getAccount(
        Address.fromBech32(alice),
      );

      expect(account.activeGuardian, isNull);
      expect(account.pendingGuardian, isNull);
      expect(account.isGuarded, isFalse);
    });
  });

  group('AccountOnNetwork.fromApiResponse guardian shapes', () {
    test('reads the flat API scalars', () {
      final AccountOnNetwork account =
          AccountOnNetwork.fromApiResponse(<String, dynamic>{
            'address': alice,
            'nonce': 3,
            'balance': '5',
            'isGuarded': true,
            'activeGuardianAddress': guardian,
            'activeGuardianActivationEpoch': 42,
            'activeGuardianServiceUid': 'TCS',
          });

      expect(account.activeGuardian!.activationEpoch, equals(42));
      expect(account.activeGuardian!.serviceUID, equals('TCS'));
      expect(account.isGuarded, isTrue);
    });

    test('still accepts a nested guardian object as a fallback', () {
      final AccountOnNetwork account = AccountOnNetwork.fromApiResponse(
        <String, dynamic>{
          'address': alice,
          'nonce': 3,
          'balance': '5',
          'activeGuardian': <String, dynamic>{
            'address': guardian,
            'activationEpoch': 8,
            'serviceUID': 'TCS',
          },
        },
      );

      expect(account.activeGuardian!.activationEpoch, equals(8));
      expect(account.isGuarded, isTrue);
    });
  });
}
