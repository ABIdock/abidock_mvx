/// Tests for [Guardian] / [GuardianData] DTO parsing.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('Guardian.fromHttpResponse', () {
    test('parses canonical API/Gateway shape', () {
      final Guardian g = Guardian.fromHttpResponse(<String, dynamic>{
        'address':
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
        'activationEpoch': 42,
        'serviceUID': 'TCS',
      });
      expect(g.address.bech32, startsWith('erd1qyu'));
      expect(g.activationEpoch, equals(42));
      expect(g.serviceUid, equals('TCS'));
    });

    test('accepts string activationEpoch (Gateway sometimes serialises ints '
        'as strings)', () {
      final Guardian g = Guardian.fromHttpResponse(<String, dynamic>{
        'address':
            'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
        'activationEpoch': '100',
        'serviceUID': 'TCS',
      });
      expect(g.activationEpoch, equals(100));
    });
  });

  group('GuardianData.fromHttpResponse', () {
    test('parses an unguarded account', () {
      final GuardianData data = GuardianData.fromHttpResponse(<String, dynamic>{
        'guarded': false,
      });
      expect(data.guarded, isFalse);
      expect(data.activeGuardian, isNull);
      expect(data.pendingGuardian, isNull);
    });

    test('parses a guarded account with an active guardian', () {
      final GuardianData data = GuardianData.fromHttpResponse(<String, dynamic>{
        'guarded': true,
        'activeGuardian': <String, dynamic>{
          'address':
              'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
          'activationEpoch': 7,
          'serviceUID': 'TCS',
        },
      });
      expect(data.guarded, isTrue);
      expect(data.activeGuardian, isNotNull);
      expect(data.activeGuardian!.activationEpoch, equals(7));
      expect(data.pendingGuardian, isNull);
    });

    test('parses both active and pending guardians', () {
      final GuardianData data = GuardianData.fromHttpResponse(<String, dynamic>{
        'guarded': true,
        'activeGuardian': <String, dynamic>{
          'address':
              'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
          'activationEpoch': 7,
          'serviceUID': 'TCS',
        },
        'pendingGuardian': <String, dynamic>{
          'address':
              'erd150sh7scpm4q7tdtntte975kt0cgg3r4exf8mtwurfradguzxzuqsahzma8',
          'activationEpoch': 12,
          'serviceUID': 'TCS',
        },
      });
      expect(data.activeGuardian, isNotNull);
      expect(data.pendingGuardian, isNotNull);
      expect(data.pendingGuardian!.activationEpoch, equals(12));
    });
  });
}
