/// Represents the economics data of the MultiversX network.
///
/// Contains information about token supply, staking, market data, and APR.
/// This endpoint is only available through the API provider (not Gateway).
///
/// #### Example
/// ```dart
/// final economics = await provider.getNetworkEconomics();
/// print('Total Supply: ${economics.totalSupply}');
/// print('Circulating Supply: ${economics.circulatingSupply}');
/// print('Staked: ${economics.staked}');
/// print('Price: \$${economics.price}');
/// print('Market Cap: \$${economics.marketCap}');
/// print('APR: ${(economics.apr * 100).toStringAsFixed(2)}%');
/// ```
final class NetworkEconomics {
  /// Total EGLD supply in the network.
  final int totalSupply;

  /// Circulating EGLD supply (excludes locked/burned tokens).
  final int circulatingSupply;

  /// Total EGLD staked in validators and delegation.
  final int staked;

  /// Current EGLD price in USD.
  final double price;

  /// Total market capitalization in USD.
  final int marketCap;

  /// Total Annual Percentage Rate for staking.
  final double apr;

  /// Top-up APR component (additional rewards for over-staking).
  final double topUpApr;

  /// Base APR component (minimum staking rewards).
  final double baseApr;

  /// Market cap of all tokens on the network in USD.
  final int tokenMarketCap;

  /// Creates a new [NetworkEconomics] instance.
  const NetworkEconomics({
    required this.totalSupply,
    required this.circulatingSupply,
    required this.staked,
    required this.price,
    required this.marketCap,
    required this.apr,
    required this.topUpApr,
    required this.baseApr,
    required this.tokenMarketCap,
  });

  /// Creates a [NetworkEconomics] from JSON response.
  ///
  /// #### Parameters
  /// - `json` - JSON map from API response
  ///
  /// #### Returns
  /// A new [NetworkEconomics] instance
  factory NetworkEconomics.fromJson(Map<String, dynamic> json) {
    return NetworkEconomics(
      totalSupply: (json['totalSupply'] as num?)?.toInt() ?? 0,
      circulatingSupply: (json['circulatingSupply'] as num?)?.toInt() ?? 0,
      staked: (json['staked'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      marketCap: (json['marketCap'] as num?)?.toInt() ?? 0,
      apr: (json['apr'] as num?)?.toDouble() ?? 0.0,
      topUpApr: (json['topUpApr'] as num?)?.toDouble() ?? 0.0,
      baseApr: (json['baseApr'] as num?)?.toDouble() ?? 0.0,
      tokenMarketCap: (json['tokenMarketCap'] as num?)?.toInt() ?? 0,
    );
  }

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => {
    'totalSupply': totalSupply,
    'circulatingSupply': circulatingSupply,
    'staked': staked,
    'price': price,
    'marketCap': marketCap,
    'apr': apr,
    'topUpApr': topUpApr,
    'baseApr': baseApr,
    'tokenMarketCap': tokenMarketCap,
  };

  @override
  String toString() =>
      'NetworkEconomics('
      'totalSupply: $totalSupply, '
      'circulatingSupply: $circulatingSupply, '
      'staked: $staked, '
      'price: $price, '
      'marketCap: $marketCap, '
      'apr: $apr, '
      'topUpApr: $topUpApr, '
      'baseApr: $baseApr, '
      'tokenMarketCap: $tokenMarketCap)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkEconomics &&
        other.totalSupply == totalSupply &&
        other.circulatingSupply == circulatingSupply &&
        other.staked == staked &&
        other.price == price &&
        other.marketCap == marketCap &&
        other.apr == apr &&
        other.topUpApr == topUpApr &&
        other.baseApr == baseApr &&
        other.tokenMarketCap == tokenMarketCap;
  }

  @override
  int get hashCode => Object.hash(
    totalSupply,
    circulatingSupply,
    staked,
    price,
    marketCap,
    apr,
    topUpApr,
    baseApr,
    tokenMarketCap,
  );
}
