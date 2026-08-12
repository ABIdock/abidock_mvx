/// Token on MultiversX network with balance information.
/// Represents a token with complete metadata including balance, properties, assets, and permissions.
/// Provides convenient getters for common fields and computed properties.
///
/// #### Example
/// ```dart
/// // From API response
/// final token = TokenOnNetwork.fromJson(apiResponse);
///
/// // Access properties
/// print(token.identifier); // TOKEN-a1b2c3
/// print(token.balance); // 1000000000000000000
/// print(token.ticker); // TOKEN
/// print(token.decimals); // 18
///
/// // Formatted balance
/// print(token.denominatedBalance); // 1.0
/// print(token.formatBalance(decimalPlaces: 4)); // 1.0000
/// print(token.displayString); // 1.00 TOKEN
///
/// // Token type checks
/// print(token.isFungible); // true
/// print(token.isNft); // false
///
/// // Price and value
/// print(token.price); // 0.05
/// print(token.valueUsd); // 0.05
/// print(token.marketCap); // 1000000
/// ```

import '../infrastructure/network/network_status.dart';
import '../utils/helpers.dart';

class TokenOnNetwork {
  /// Creates TokenOnNetwork.
  ///
  /// #### Parameters
  /// - `identifier` - Token identifier (e.g., 'TOKEN-a1b2c3')
  /// - `balance` - Balance in atomic units (String)
  /// - `nonce` - Nonce for NFTs/SFTs (0 for fungible)
  /// - `raw` - Raw API response map
  const TokenOnNetwork({
    required this.identifier,
    required this.balance,
    required this.nonce,
    required this.raw,
  });

  /// Creates TokenOnNetwork from JSON (API response).
  ///
  /// #### Parameters
  /// - `json` - API response map
  ///
  /// #### Returns
  /// TokenOnNetwork instance
  ///
  /// #### Example
  /// ```dart
  /// final json = {
  ///   'identifier': 'TOKEN-a1b2c3',
  ///   'balance': '1000000000000000000',
  ///   'nonce': 0,
  ///   'name': 'My Token',
  ///   'ticker': 'TOKEN',
  ///   'decimals': 18,
  /// };
  /// final token = TokenOnNetwork.fromJson(json);
  /// ```
  factory TokenOnNetwork.fromJson(Map<String, dynamic> json) {
    return TokenOnNetwork(
      identifier:
          optionalAs<String>(json['identifier'], 'identifier') ??
          optionalAs<String>(json['tokenIdentifier'], 'tokenIdentifier') ??
          '',
      balance: optionalAs<String>(json['balance'], 'balance') ?? '0',
      nonce: optionalAs<int>(json['nonce'], 'nonce') ?? 0,
      raw: json,
    );
  }

  /// Token identifier.
  final String identifier;

  /// Balance in atomic units.
  final String balance;

  /// Nonce for NFTs/SFTs (0 for fungible).
  final int nonce;

  /// Raw API response.
  final Map<String, dynamic> raw;

  /// Converts to JSON.
  Map<String, dynamic> toJson() => raw;

  /// Token name.
  String? get name => optionalAs<String>(raw['name'], 'name');

  /// Token ticker/symbol.
  String? get ticker => optionalAs<String>(raw['ticker'], 'ticker');

  /// Number of decimals.
  int get decimals => optionalAs<int>(raw['decimals'], 'decimals') ?? 18;

  /// Token type.
  String? get type => optionalAs<String>(raw['type'], 'type');

  /// Token owner/creator address.
  String? get owner =>
      optionalAs<String>(raw['owner'], 'owner') ??
      optionalAs<String>(raw['creator'], 'creator');

  /// Collection identifier.
  String? get collection => optionalAs<String>(raw['collection'], 'collection');

  /// Timestamp in seconds when the token was created, if reported.
  ///
  /// Prefer [createdAt], which does not depend on the reported unit.
  int? get timestamp => optionalAs<int>(raw['timestamp'], 'timestamp');

  /// Timestamp in milliseconds when the token was created, if reported.
  ///
  /// Only the collection route carries this key; the token, NFT and
  /// account-holding routes report [timestamp] alone.
  int? get timestampMs => optionalAs<int>(raw['timestampMs'], 'timestampMs');

  /// Creation instant of the token, normalised to UTC.
  ///
  /// Prefers [timestampMs] and falls back to [timestamp], deciding the unit of
  /// whichever value it uses by magnitude via [ChainTimestamp].
  ///
  /// #### Returns
  /// `DateTime?` - UTC instant, or `null` when neither timestamp was reported
  ///
  /// #### Example
  /// ```dart
  /// final TokenOnNetwork token = await provider.getDefinitionOfTokenCollection(
  ///   'MEDAL-ae4d56',
  /// );
  /// print(token.createdAt);
  /// ```
  DateTime? get createdAt =>
      ChainTimestamp.toDateTime(timestampMs ?? timestamp);

  /// Token attributes.
  String? get attributes => optionalAs<String>(raw['attributes'], 'attributes');

  /// Token URIs.
  List<String>? get uris {
    final urisData = raw['uris'];
    if (urisData is List) {
      return urisData.cast<String>();
    }
    return null;
  }

  /// Royalties percentage for NFTs/SFTs.
  int? get royalties => optionalAs<int>(raw['royalties'], 'royalties');

  /// Token logo/asset URLs.
  Map<String, dynamic>? get assets =>
      optionalAs<Map<String, dynamic>>(raw['assets'], 'assets');

  /// SVG logo URL.
  String? get svgUrl => optionalAs<String>(assets?['svgUrl'], 'svgUrl');

  /// PNG logo URL.
  String? get pngUrl => optionalAs<String>(assets?['pngUrl'], 'pngUrl');

  /// Best available logo URL.
  String? get logoUrl => svgUrl ?? pngUrl;

  /// Token supply.
  String? get supply => optionalAs<String>(raw['supply'], 'supply');

  /// Circulating supply.
  String? get circulatingSupply =>
      optionalAs<String>(raw['circulatingSupply'], 'circulatingSupply');

  /// Whether token can be burned.
  bool get canBurn => optionalAs<bool>(raw['canBurn'], 'canBurn') ?? false;

  /// Whether token can be minted.
  bool get canMint => optionalAs<bool>(raw['canMint'], 'canMint') ?? false;

  /// Whether token can be paused.
  bool get canPause => optionalAs<bool>(raw['canPause'], 'canPause') ?? false;

  /// Whether token can be frozen.
  bool get canFreeze =>
      optionalAs<bool>(raw['canFreeze'], 'canFreeze') ?? false;

  /// Whether token can be wiped.
  bool get canWipe => optionalAs<bool>(raw['canWipe'], 'canWipe') ?? false;

  /// Whether token can be upgraded.
  bool get canUpgrade =>
      optionalAs<bool>(raw['canUpgrade'], 'canUpgrade') ?? false;

  /// Whether token ownership can be changed.
  bool get canChangeOwner =>
      optionalAs<bool>(raw['canChangeOwner'], 'canChangeOwner') ?? false;

  /// Whether token can add special roles.
  bool get canAddSpecialRoles =>
      optionalAs<bool>(raw['canAddSpecialRoles'], 'canAddSpecialRoles') ??
      false;

  /// Whether NFT create role can be transferred.
  bool get canTransferNftCreateRole =>
      optionalAs<bool>(
        raw['canTransferNftCreateRole'],
        'canTransferNftCreateRole',
      ) ??
      false;

  /// Whether NFT creation is stopped.
  bool get nftCreateStopped =>
      optionalAs<bool>(raw['NFTCreateStopped'], 'NFTCreateStopped') ?? false;

  /// Whether token is paused.
  bool get isPaused => optionalAs<bool>(raw['isPaused'], 'isPaused') ?? false;

  /// Token price in USD.
  double? get price => (raw['price'] as num?)?.toDouble();

  /// Token market cap in USD.
  double? get marketCap => (raw['marketCap'] as num?)?.toDouble();

  /// Value in USD (balance * price).
  double? get valueUsd => (raw['valueUsd'] as num?)?.toDouble();

  /// Total minted supply.
  String? get minted => optionalAs<String>(raw['minted'], 'minted');

  /// Total burnt supply.
  String? get burnt => optionalAs<String>(raw['burnt'], 'burnt');

  /// Initial minted supply.
  String? get initialMinted =>
      optionalAs<String>(raw['initialMinted'], 'initialMinted');

  /// Number of accounts holding this token.
  int? get accounts => (raw['accounts'] as num?)?.toInt();

  /// Number of transactions for this token.
  int? get transactions => (raw['transactions'] as num?)?.toInt();

  /// Number of transfers for this token.
  int? get transfers => (raw['transfers'] as num?)?.toInt();

  /// Token sub-type (e.g., for NFTs: NonFungibleESDTv2, DynamicNonFungibleESDT).
  String? get subType => optionalAs<String>(raw['subType'], 'subType');

  /// Token roles.
  List<dynamic>? get roles => optionalAs<List<dynamic>>(raw['roles'], 'roles');

  /// MEX pair type (experimental, core, etc.).
  String? get mexPairType =>
      optionalAs<String>(raw['mexPairType'], 'mexPairType');

  /// Total liquidity in DEX.
  double? get totalLiquidity => (raw['totalLiquidity'] as num?)?.toDouble();

  /// Total 24h trading volume.
  double? get totalVolume24h => (raw['totalVolume24h'] as num?)?.toDouble();

  /// Whether token has low liquidity.
  bool? get isLowLiquidity =>
      optionalAs<bool>(raw['isLowLiquidity'], 'isLowLiquidity');

  /// Low liquidity threshold percentage.
  double? get lowLiquidityThresholdPercent =>
      (raw['lowLiquidityThresholdPercent'] as num?)?.toDouble();

  /// Number of trades.
  int? get tradesCount => (raw['tradesCount'] as num?)?.toInt();

  /// Token owners history.
  List<dynamic>? get ownersHistory =>
      optionalAs<List<dynamic>>(raw['ownersHistory'], 'ownersHistory');

  /// Whether token can be transferred (for some restricted tokens).
  bool? get canTransfer => optionalAs<bool>(raw['canTransfer'], 'canTransfer');

  /// Scam information if token is flagged.
  Map<String, dynamic>? get scamInfo =>
      optionalAs<Map<String, dynamic>>(raw['scamInfo'], 'scamInfo');

  /// Token website from assets.
  String? get website => optionalAs<String>(assets?['website'], 'website');

  /// Token description from assets.
  String? get description =>
      optionalAs<String>(assets?['description'], 'description');

  /// Token social links from assets.
  Map<String, dynamic>? get social =>
      optionalAs<Map<String, dynamic>>(assets?['social'], 'social');

  /// Token status from assets (active, inactive).
  String? get status => optionalAs<String>(assets?['status'], 'status');

  /// Ledger signature for hardware wallet support.
  String? get ledgerSignature =>
      optionalAs<String>(assets?['ledgerSignature'], 'ledgerSignature');

  /// Locked accounts information from assets.
  Map<String, dynamic>? get lockedAccounts => optionalAs<Map<String, dynamic>>(
    assets?['lockedAccounts'],
    'lockedAccounts',
  );

  /// Extra tokens associated with this token from assets.
  List<dynamic>? get extraTokens =>
      optionalAs<List<dynamic>>(assets?['extraTokens'], 'extraTokens');

  /// Preferred rank algorithm for NFTs.
  String? get preferredRankAlgorithm => optionalAs<String>(
    assets?['preferredRankAlgorithm'],
    'preferredRankAlgorithm',
  );

  /// Price source information from assets.
  Map<String, dynamic>? get priceSource =>
      optionalAs<Map<String, dynamic>>(assets?['priceSource'], 'priceSource');

  /// Last updated timestamp for transactions count.
  int? get transactionsLastUpdatedAt =>
      (raw['transactionsLastUpdatedAt'] as num?)?.toInt();

  /// Last updated timestamp for transfers count.
  int? get transfersLastUpdatedAt =>
      (raw['transfersLastUpdatedAt'] as num?)?.toInt();

  /// Last updated timestamp for accounts count.
  int? get accountsLastUpdatedAt =>
      (raw['accountsLastUpdatedAt'] as num?)?.toInt();

  /// URL for NFT media.
  String? get url => optionalAs<String>(raw['url'], 'url');

  /// Thumbnail URL for NFT.
  String? get thumbnailUrl =>
      optionalAs<String>(raw['thumbnailUrl'], 'thumbnailUrl');

  /// Media array for NFT.
  List<dynamic>? get media => optionalAs<List<dynamic>>(raw['media'], 'media');

  /// Metadata for NFT.
  Map<String, dynamic>? get metadata =>
      optionalAs<Map<String, dynamic>>(raw['metadata'], 'metadata');

  /// Tags associated with token.
  List<dynamic>? get tags => optionalAs<List<dynamic>>(raw['tags'], 'tags');

  /// NFT rank for rarity.
  int? get rank => (raw['rank'] as num?)?.toInt();

  /// NFT rarity score.
  double? get rarityScore => (raw['rarityScore'] as num?)?.toDouble();

  /// Is verified collection.
  bool? get isVerified => optionalAs<bool>(raw['isVerified'], 'isVerified');

  /// Is whitelisted storage.
  bool? get isWhitelistedStorage =>
      optionalAs<bool>(raw['isWhitelistedStorage'], 'isWhitelistedStorage');

  /// NFT holder count.
  int? get holderCount => (raw['holderCount'] as num?)?.toInt();

  /// NFT count in collection.
  int? get nftCount => (raw['nftCount'] as num?)?.toInt();

  /// Value in EGLD.
  double? get valueEgld => (raw['valueEgld'] as num?)?.toDouble();

  /// Balance as BigInt.
  ///
  /// #### Returns
  /// Balance parsed as BigInt, or zero if balance is empty/invalid
  BigInt get balanceAsBigInt {
    if (balance.isEmpty) return BigInt.zero;
    return BigInt.tryParse(balance) ?? BigInt.zero;
  }

  /// Denominated balance as string with full precision.
  ///
  /// #### Returns
  /// Balance with decimals applied as string (avoids floating-point precision issues)
  String get denominatedBalanceString {
    final String balanceStr = balance;
    final int balanceLength = balanceStr.length;

    if (balanceLength <= decimals) {
      final String paddedBalance = balanceStr.padLeft(decimals, '0');
      return '0.$paddedBalance';
    } else {
      final int splitPoint = balanceLength - decimals;
      final String integerPart = balanceStr.substring(0, splitPoint);
      final String decimalPart = balanceStr.substring(splitPoint);
      return '$integerPart.$decimalPart';
    }
  }

  /// Denominated balance.
  ///
  /// #### Returns
  /// Balance with decimals applied as double
  ///
  double get denominatedBalance {
    return double.parse(denominatedBalanceString);
  }

  /// Formats balance with decimals.
  ///
  /// #### Parameters
  /// - `decimalPlaces` - Number of decimal places (default: 2)
  ///
  /// #### Returns
  /// Formatted balance string
  ///
  /// #### Example
  /// ```dart
  /// final token = TokenOnNetwork.fromJson({...});
  /// print(token.formatBalance()); // 1.50
  /// print(token.formatBalance(decimalPlaces: 4)); // 1.5000
  /// ```
  String formatBalance({int decimalPlaces = 2}) {
    final String fullBalance = denominatedBalanceString;
    final List<String> parts = fullBalance.split('.');
    final String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';
    if (decimalPart.length > decimalPlaces) {
      decimalPart = decimalPart.substring(0, decimalPlaces);
    } else {
      decimalPart = decimalPart.padRight(decimalPlaces, '0');
    }

    if (decimalPlaces == 0) {
      return integerPart;
    }

    return '$integerPart.$decimalPart';
  }

  /// Whether this is fungible token.
  bool get isFungible => nonce == 0;

  /// Whether this is NFT.
  bool get isNft => type == 'NonFungibleESDT';

  /// Whether this is semi-fungible token.
  bool get isSemiFungible => type == 'SemiFungibleESDT';

  /// Whether this is Meta-ESDT.
  bool get isMetaEsdt => type == 'MetaESDT';

  /// Whether this is a Dynamic NFT (any dynamic variant).
  bool get isDynamicNft =>
      subType == 'DynamicNonFungibleESDT' ||
      subType == 'DynamicSemiFungibleESDT' ||
      subType == 'DynamicMetaESDT';

  /// Whether this is NFT v2.
  bool get isNftV2 => subType == 'NonFungibleESDTv2';

  /// Whether token has NFT properties.
  bool get isNftLike => isNft || isSemiFungible;

  /// Full token identifier including nonce.
  String get fullIdentifier {
    if (nonce > 0 && isNftLike) {
      String hex = nonce.toRadixString(16);
      if (hex.length.isOdd) hex = '0$hex';
      if (hex.length < 2) hex = hex.padLeft(2, '0');
      return '$identifier-$hex';
    }
    return identifier;
  }

  /// Collection identifier (without nonce).
  String get collectionIdentifier {
    if (collection != null) {
      return collection!;
    }
    if (isNftLike && identifier.contains('-')) {
      final List<String> parts = identifier.split('-');
      if (parts.length >= 2) {
        return '${parts[0]}-${parts[1]}';
      }
    }
    return identifier;
  }

  /// Display string with balance and ticker.
  String get displayString {
    final String formattedBalance = formatBalance();
    final String displayTicker = ticker ?? identifier;
    return '$formattedBalance $displayTicker';
  }

  /// Display name with ticker.
  String get displayName {
    if (name != null && ticker != null) {
      return '$name ($ticker)';
    }
    return name ?? ticker ?? identifier;
  }

  @override
  String toString() => 'TokenOnNetwork($identifier: $balance)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenOnNetwork &&
          runtimeType == other.runtimeType &&
          identifier == other.identifier &&
          balance == other.balance &&
          nonce == other.nonce;

  @override
  int get hashCode => Object.hash(identifier, balance, nonce);
}
