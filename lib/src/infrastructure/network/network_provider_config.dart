import '../caching/cache_manager.dart';
import '../resilience/retry_helper.dart';

/// Policy controlling automatic retry of transient HTTP failures inside
/// `BaseNetworkProvider.doGetGeneric` / `doPostGeneric` (M2-15).
///
/// Pass `RetryPolicy.disabled()` (the default) to keep the previous
/// "fail fast" behaviour, or `RetryPolicy.enabled(config)` to opt-in to
/// the existing `RetryHelper`-based retries.
class RetryPolicy {
  const RetryPolicy._(this.enabled, this.config);

  /// Default: no automatic retries inside the provider. Consumers that
  /// want per-call retries can still wrap their own calls with
  /// `RetryHelper`.
  const RetryPolicy.disabled() : this._(false, null);

  /// Opt-in to provider-level retries using the supplied [config].
  const RetryPolicy.enabled([RetryConfig config = const RetryConfig()])
    : this._(true, config);

  /// Whether automatic retries are enabled.
  final bool enabled;

  /// Retry configuration (only meaningful when [enabled] is true).
  final RetryConfig? config;
}

/// Policy controlling client-side request throttling inside
/// `BaseNetworkProvider`.
///
/// The public MultiversX hosts enforce per-IP request ceilings at the edge:
/// the Gateway hosts allow 50 requests per IP per second on both mainnet and
/// devnet, while the API hosts allow 2 requests per IP per second on mainnet
/// and 5 on devnet. Exceeding a ceiling yields HTTP 429 responses. Nothing is
/// throttled unless a policy is configured here — the default is
/// [ThrottlePolicy.disabled], which leaves request timing entirely to the
/// caller.
///
/// The throttle is a token bucket: [capacity] is the burst that may be spent
/// immediately, [refillPerSecond] the sustained rate the bucket refills at.
/// It is per-provider-instance and therefore only bounds the traffic this
/// provider emits, not the traffic of the whole process.
///
/// #### Example
/// ```dart
/// final provider = GatewayNetworkProvider.mainnet(
///   config: const NetworkProviderConfig(
///     throttlePolicy: ThrottlePolicy.gateway(),
///   ),
/// );
/// ```
class ThrottlePolicy {
  const ThrottlePolicy._(this.enabled, this.capacity, this.refillPerSecond)
    : assert(
        !enabled || (capacity != null && capacity > 0),
        'An enabled throttle needs a positive capacity',
      ),
      assert(
        !enabled || (refillPerSecond != null && refillPerSecond > 0),
        'An enabled throttle needs a positive refill rate',
      );

  /// Default: requests leave as fast as the caller issues them.
  const ThrottlePolicy.disabled() : this._(false, null, null);

  /// Opt-in to a token bucket of [capacity] tokens refilled at
  /// [refillPerSecond] tokens per second.
  ///
  /// #### Parameters
  /// - `capacity` - Burst size, in requests; must be positive
  /// - `refillPerSecond` - Sustained request rate; must be positive
  const ThrottlePolicy.enabled({
    required int capacity,
    required double refillPerSecond,
  }) : this._(true, capacity, refillPerSecond);

  /// Throttle matching the published Gateway ceiling of 50 requests per IP
  /// per second (identical on mainnet and devnet).
  const ThrottlePolicy.gateway() : this._(true, 50, 50);

  /// Throttle matching the published API ceiling of 2 requests per IP per
  /// second on mainnet.
  ///
  /// Devnet allows 5; use [ThrottlePolicy.enabled] with
  /// `capacity: 5, refillPerSecond: 5` there.
  const ThrottlePolicy.api() : this._(true, 2, 2);

  /// Whether outbound requests are throttled.
  final bool enabled;

  /// Burst size in requests (only meaningful when [enabled] is true).
  final int? capacity;

  /// Sustained request rate per second (only meaningful when [enabled] is
  /// true).
  final double? refillPerSecond;
}

/// Policy controlling in-process caching of `GET` responses inside
/// `BaseNetworkProvider.doGetGeneric`.
///
/// Disabled by default: chain state changes every round, and a provider that
/// silently served a stale account would hand back a stale nonce. When
/// enabled, only `GET` responses are cached, keyed by the resource path
/// including its query string, and the whole cache is dropped after every
/// successful `POST` so a send or a simulate cannot leave a stale account
/// behind.
///
/// #### Example
/// ```dart
/// final provider = ApiNetworkProvider.mainnet(
///   config: const NetworkProviderConfig(
///     cachePolicy: ResponseCachePolicy.enabled(
///       defaultConfig: CacheConfig.short,
///       endpointConfigs: <String, CacheConfig>{
///         'network/config': CacheConfig.long,
///       },
///     ),
///   ),
/// );
/// ```
class ResponseCachePolicy {
  const ResponseCachePolicy._(
    this.enabled,
    this.defaultConfig,
    this.endpointConfigs,
  );

  /// Default: every call reaches the network.
  const ResponseCachePolicy.disabled()
    : this._(false, null, const <String, CacheConfig>{});

  /// Opt-in to caching `GET` responses.
  ///
  /// #### Parameters
  /// - `defaultConfig` - TTL and size applied to paths with no specific entry
  /// - `endpointConfigs` - Per-path-prefix overrides, keyed by resource path
  ///   as passed to `doGetGeneric` (for example `'network/config'`)
  const ResponseCachePolicy.enabled({
    CacheConfig defaultConfig = CacheConfig.short,
    Map<String, CacheConfig> endpointConfigs = const <String, CacheConfig>{},
  }) : this._(true, defaultConfig, endpointConfigs);

  /// Whether `GET` responses are cached.
  final bool enabled;

  /// Cache configuration for paths without a specific entry.
  final CacheConfig? defaultConfig;

  /// Per-path-prefix cache configuration.
  final Map<String, CacheConfig> endpointConfigs;
}

/// Configuration options forwarded into a `BaseNetworkProvider`.
///
/// Used to inject a client-identifying `User-Agent`, custom HTTP headers, a
/// request timeout, and an optional base URL override.
///
/// #### Example
/// ```dart
/// final config = NetworkProviderConfig(
///   clientName: 'my-dapp',
///   requestTimeout: Duration(seconds: 10),
///   headers: {'X-Custom': 'value'},
///   retryPolicy: RetryPolicy.enabled(),
///   throttlePolicy: ThrottlePolicy.api(),
/// );
/// final provider = ApiNetworkProvider.devnet(config: config);
/// ```
class NetworkProviderConfig {
  /// Creates a new network provider configuration.
  ///
  /// Every resilience knob defaults to off, so a provider built without a
  /// config — or with a config that only sets headers — performs exactly one
  /// unthrottled, uncached, unretried HTTP request per call.
  ///
  /// #### Parameters
  /// - `clientName` - Identifier appended to the User-Agent header.
  /// - `headers` - Additional HTTP headers applied to every request.
  /// - `requestTimeout` - Timeout used for connect/receive/send phases.
  /// - `baseUrl` - Optional override for the network base URL.
  /// - `retryPolicy` - Automatic retry policy for `doGetGeneric` /
  ///   `doPostGeneric`. Defaults to `RetryPolicy.disabled()`. Set to
  ///   `RetryPolicy.enabled(...)` to retry transient errors (5xx, 408,
  ///   429, network / timeout) automatically (M2-15).
  /// - `throttlePolicy` - Client-side rate limit for every outbound request.
  ///   Defaults to `ThrottlePolicy.disabled()`. Set to
  ///   `ThrottlePolicy.gateway()` / `ThrottlePolicy.api()` to stay under the
  ///   published per-IP ceiling of the public hosts.
  /// - `cachePolicy` - In-process cache for `GET` responses. Defaults to
  ///   `ResponseCachePolicy.disabled()`.
  const NetworkProviderConfig({
    this.clientName,
    this.headers,
    this.requestTimeout,
    this.baseUrl,
    this.retryPolicy = const RetryPolicy.disabled(),
    this.throttlePolicy = const ThrottlePolicy.disabled(),
    this.cachePolicy = const ResponseCachePolicy.disabled(),
  });

  /// Client identifier used for the User-Agent suffix.
  final String? clientName;

  /// Additional HTTP headers applied to every request.
  final Map<String, String>? headers;

  /// Per-request timeout. Maps onto Dio connect/receive/send timeouts.
  final Duration? requestTimeout;

  /// Optional override of the network base URL.
  final String? baseUrl;

  /// Automatic retry policy applied to `doGetGeneric` / `doPostGeneric`.
  final RetryPolicy retryPolicy;

  /// Client-side throttle applied to every outbound request.
  final ThrottlePolicy throttlePolicy;

  /// In-process cache applied to `GET` responses.
  final ResponseCachePolicy cachePolicy;
}

/// Builds the `User-Agent` header sent with every network request.
///
/// The header always carries the prefix, so the gateway and API can attribute
/// traffic to this client.
class UserAgent {
  UserAgent._();

  /// Prefix identifying this SDK in the User-Agent header.
  static const String prefix = 'multiversx-sdk-dart';

  /// Fallback suffix when `clientName` is not provided.
  static const String unknownClient = 'unknown';

  /// Computes the User-Agent value for the given `clientName`.
  ///
  /// The result is always `prefix/clientName`; when no client name is
  /// supplied, [unknownClient] is used as the suffix.
  static String build({String? clientName}) {
    final String suffix = (clientName == null || clientName.isEmpty)
        ? unknownClient
        : clientName;
    return '$prefix/$suffix';
  }
}
