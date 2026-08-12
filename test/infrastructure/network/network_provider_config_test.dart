/// Tests for [NetworkProviderConfig], [RetryPolicy], and [UserAgent].
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('RetryPolicy', () {
    test('disabled() has enabled=false and null config', () {
      const RetryPolicy p = RetryPolicy.disabled();
      expect(p.enabled, isFalse);
      expect(p.config, isNull);
    });

    test('enabled() defaults to a non-null RetryConfig', () {
      const RetryPolicy p = RetryPolicy.enabled();
      expect(p.enabled, isTrue);
      expect(p.config, isNotNull);
    });
  });

  group('NetworkProviderConfig', () {
    test('default ctor leaves every field null/disabled', () {
      const NetworkProviderConfig c = NetworkProviderConfig();
      expect(c.clientName, isNull);
      expect(c.headers, isNull);
      expect(c.requestTimeout, isNull);
      expect(c.baseUrl, isNull);
      expect(c.retryPolicy.enabled, isFalse);
    });

    test('captures every provided option verbatim', () {
      const NetworkProviderConfig c = NetworkProviderConfig(
        clientName: 'my-dapp',
        headers: <String, String>{'X-Custom': 'value'},
        requestTimeout: Duration(seconds: 10),
        baseUrl: 'https://example.com',
        retryPolicy: RetryPolicy.enabled(),
      );
      expect(c.clientName, equals('my-dapp'));
      expect(c.headers, equals(<String, String>{'X-Custom': 'value'}));
      expect(c.requestTimeout, equals(const Duration(seconds: 10)));
      expect(c.baseUrl, equals('https://example.com'));
      expect(c.retryPolicy.enabled, isTrue);
    });
  });

  group('UserAgent.build', () {
    test('uses the unknown-client placeholder when clientName is null', () {
      expect(UserAgent.build(), 'multiversx-sdk-dart/unknown');
    });

    test('embeds the provided clientName', () {
      expect(
        UserAgent.build(clientName: 'my-dapp'),
        'multiversx-sdk-dart/my-dapp',
      );
    });

    test('uses the unknown-client placeholder when clientName is empty', () {
      expect(UserAgent.build(clientName: ''), 'multiversx-sdk-dart/unknown');
    });
  });
}
