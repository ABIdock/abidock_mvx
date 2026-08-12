import '../../infrastructure/network/network_status.dart';
import '../../utils/helpers.dart';
import '../address.dart';
import '../balance.dart';
import '../nonce.dart';
import 'code_metadata.dart';

/// Account state snapshot from the blockchain.
/// Contains balance, nonce, smart contract data, guardians, and other on-chain state.
///
/// #### Example
/// ```dart
/// // From REST API
/// final apiData = await httpClient.get('/accounts/$address');
/// final account = AccountOnNetwork.fromApiResponse(apiData);
/// print('Balance: ${account.balance.toDenominatedTrimmed} EGLD');
/// print('Nonce: ${account.nonce.value}');
/// print('Is contract: ${account.isContract}');
/// print('Shard: ${account.shard}');
///
/// // From Gateway
/// final proxyData = await gateway.getAccount(address);
/// final accountProxy = AccountOnNetwork.fromProxyResponse(proxyData);
///
/// // Check guardian status
/// if (account.hasActiveGuardian) {
///   print('Guardian: ${account.activeGuardian!.address.bech32}');
/// }
/// ```
class AccountOnNetwork {
  /// Creates account state.
  /// Use fromApiResponse or fromProxyResponse when parsing network data.
  ///
  /// #### Parameters
  /// - `address` - Account address
  /// - `nonce` - Current transaction nonce
  /// - `balance` - Current EGLD balance
  /// - `shard` - Shard where account lives (optional)
  /// - `username` - Herotag/username (optional)
  /// - `code` - Smart contract code in hex (optional)
  /// - `codeHash` - Contract code hash (optional)
  /// - `rootHash` - Storage trie root hash (optional)
  /// - `codeMetadata` - Contract metadata (optional)
  /// - `ownerAddress` - Contract owner (optional)
  /// - `developerReward` - Accumulated developer reward (optional)
  /// - `activeGuardian` - Active guardian data (optional)
  /// - `pendingGuardian` - Pending guardian data (optional)
  /// - `isPayable` - Smart contract is payable (optional)
  /// - `isPayableBySmartContract` - Smart contract accepts SC payments (optional)
  /// - `isUpgradeable` - Smart contract is upgradeable (optional)
  /// - `isReadable` - Smart contract storage is readable (optional)
  /// - `scamInfo` - Scam detection information (optional)
  /// - `assets` - Account metadata (name, icon, etc.) (optional)
  /// - `txCount` - Total transaction count (optional)
  /// - `scrCount` - Total smart contract result count (optional)
  /// - `deployTxHash` - Contract deployment transaction hash (optional)
  /// - `deployedAt` - Contract deployment timestamp (optional)
  /// - `isGuardedFlag` - Whether account is guarded flag from API (optional)
  /// - `timestamp` - Indexed account timestamp in seconds (optional)
  /// - `timestampMs` - Indexed account timestamp in milliseconds (optional)
  const AccountOnNetwork({
    required this.address,
    required this.nonce,
    required this.balance,
    this.shard,
    this.username = '',
    this.code,
    this.codeHash,
    this.rootHash,
    this.codeMetadata,
    this.ownerAddress,
    this.developerReward,
    this.activeGuardian,
    this.pendingGuardian,
    this.isPayable,
    this.isPayableBySmartContract,
    this.isUpgradeable,
    this.isReadable,
    this.scamInfo,
    this.assets,
    this.txCount,
    this.scrCount,
    this.deployTxHash,
    this.deployedAt,
    this.isGuardedFlag,
    this.timestamp,
    this.timestampMs,
  });

  /// Creates from REST API response.
  /// Parses account data from MultiversX REST API format.
  ///
  /// #### Parameters
  /// - `data` - JSON map from API response
  ///
  /// #### Returns
  /// `AccountOnNetwork` - Parsed AccountOnNetwork instance
  ///
  /// #### Example
  /// ```dart
  /// final response = {
  ///   'address': 'erd1qqqqqqqqqqqqqpgqvc7gdl0p4s97guh498wgz75k8sav6sjfjlwqh679jy',
  ///   'nonce': 5,
  ///   'balance': '100000000000000000',
  ///   'shard': 1,
  ///   'username': 'alice.elrond',
  ///   'code': '0061736d...',
  ///   'codeHash': 'n9BVPZc73Tr...',
  ///   'ownerAddress': 'erd1...',
  ///   'developerReward': '50000000000000000',
  ///   'isUpgradeable': true,
  ///   'isPayable': false,
  /// };
  /// final account = AccountOnNetwork.fromApiResponse(response);
  /// print('Contract owner: ${account.ownerAddress?.bech32}');
  /// ```
  factory AccountOnNetwork.fromApiResponse(Map<String, dynamic> data) {
    final String? codeMetadataRaw = optionalAs<String>(
      data['codeMetadata'],
      'codeMetadata',
    );
    final CodeMetadata? decodedMetadata = CodeMetadata.tryParseBase64(
      codeMetadataRaw,
    );
    return AccountOnNetwork(
      address: Address.fromBech32(
        requireAs<String>(data['address'], 'address'),
      ),
      nonce: Nonce(requireAs<int>(data['nonce'], 'nonce')),
      balance: Balance.fromString(
        requireAs<String>(data['balance'], 'balance'),
      ),
      shard: optionalAs<int>(data['shard'], 'shard'),
      username: optionalAs<String>(data['username'], 'username') ?? '',
      code: optionalAs<String>(data['code'], 'code'),
      codeHash: optionalAs<String>(data['codeHash'], 'codeHash'),
      rootHash: optionalAs<String>(data['rootHash'], 'rootHash'),
      codeMetadata: codeMetadataRaw,
      ownerAddress: data['ownerAddress'] != null
          ? Address.fromBech32(
              requireAs<String>(data['ownerAddress'], 'ownerAddress'),
            )
          : null,
      developerReward: data['developerReward'] != null
          ? Balance.fromString(
              requireAs<String>(data['developerReward'], 'developerReward'),
            )
          : null,
      activeGuardian: _guardianFromApi(
        data,
        addressKey: 'activeGuardianAddress',
        epochKey: 'activeGuardianActivationEpoch',
        serviceUidKey: 'activeGuardianServiceUid',
        nested: data['activeGuardian'],
      ),
      pendingGuardian: _guardianFromApi(
        data,
        addressKey: 'pendingGuardianAddress',
        epochKey: 'pendingGuardianActivationEpoch',
        serviceUidKey: 'pendingGuardianServiceUid',
        nested: data['pendingGuardian'],
      ),
      isPayable:
          optionalAs<bool>(data['isPayable'], 'isPayable') ??
          decodedMetadata?.isPayable,
      isPayableBySmartContract:
          optionalAs<bool>(
            data['isPayableBySmartContract'],
            'isPayableBySmartContract',
          ) ??
          decodedMetadata?.isPayableBySmartContract,
      isUpgradeable:
          optionalAs<bool>(data['isUpgradeable'], 'isUpgradeable') ??
          decodedMetadata?.isUpgradeable,
      isReadable:
          optionalAs<bool>(data['isReadable'], 'isReadable') ??
          decodedMetadata?.isReadable,
      scamInfo: optionalAs<Map<String, dynamic>>(data['scamInfo'], 'scamInfo'),
      assets: optionalAs<Map<String, dynamic>>(data['assets'], 'assets'),
      txCount: (data['txCount'] as num?)?.toInt(),
      scrCount: (data['scrCount'] as num?)?.toInt(),
      deployTxHash: optionalAs<String>(data['deployTxHash'], 'deployTxHash'),
      deployedAt: (data['deployedAt'] as num?)?.toInt(),
      isGuardedFlag: optionalAs<bool>(data['isGuarded'], 'isGuarded'),
      timestamp: optionalInt(data['timestamp'], 'timestamp'),
      timestampMs: optionalInt(data['timestampMs'], 'timestampMs'),
    );
  }

  /// Creates from Gateway (Proxy) response.
  /// Handles numeric fields as strings (nonce may be string in Proxy responses).
  ///
  /// #### Parameters
  /// - `data` - JSON map from Gateway response
  ///
  /// #### Returns
  /// `AccountOnNetwork` - Parsed AccountOnNetwork instance
  ///
  /// #### Example
  /// ```dart
  /// final proxyResponse = {
  ///   'address': 'erd1...',
  ///   'nonce': '5', // String in Proxy
  ///   'balance': '100000000000000000',
  ///   'username': 'bob.elrond',
  /// };
  /// final account = AccountOnNetwork.fromProxyResponse(proxyResponse);
  /// print('Nonce: ${account.nonce.value}');
  /// ```
  factory AccountOnNetwork.fromProxyResponse(Map<String, dynamic> data) {
    final String? codeMetadataRaw = optionalAs<String>(
      data['codeMetadata'],
      'codeMetadata',
    );
    final CodeMetadata? decodedMetadata = CodeMetadata.tryParseBase64(
      codeMetadataRaw,
    );
    return AccountOnNetwork(
      address: Address.fromBech32(
        requireAs<String>(data['address'], 'address'),
      ),
      nonce: Nonce(int.parse(data['nonce'].toString())),
      balance: Balance.fromString(
        requireAs<String>(data['balance'], 'balance'),
      ),
      shard: optionalAs<int>(data['shard'], 'shard'),
      username: optionalAs<String>(data['username'], 'username') ?? '',
      code: optionalAs<String>(data['code'], 'code'),
      codeHash: optionalAs<String>(data['codeHash'], 'codeHash'),
      rootHash: optionalAs<String>(data['rootHash'], 'rootHash'),
      codeMetadata: codeMetadataRaw,
      ownerAddress:
          data['ownerAddress'] != null &&
              (requireAs<String>(
                data['ownerAddress'],
                'ownerAddress',
              )).isNotEmpty
          ? Address.fromBech32(
              requireAs<String>(data['ownerAddress'], 'ownerAddress'),
            )
          : null,
      developerReward: data['developerReward'] != null
          ? Balance.fromString(
              requireAs<String>(data['developerReward'], 'developerReward'),
            )
          : null,
      activeGuardian: data['activeGuardian'] != null
          ? AccountGuardian.fromProxyResponse(
              requireAs<Map<String, dynamic>>(
                data['activeGuardian'],
                'activeGuardian',
              ),
            )
          : null,
      pendingGuardian: data['pendingGuardian'] != null
          ? AccountGuardian.fromProxyResponse(
              requireAs<Map<String, dynamic>>(
                data['pendingGuardian'],
                'pendingGuardian',
              ),
            )
          : null,
      isPayable:
          optionalAs<bool>(data['isPayable'], 'isPayable') ??
          decodedMetadata?.isPayable,
      isPayableBySmartContract:
          optionalAs<bool>(
            data['isPayableBySmartContract'],
            'isPayableBySmartContract',
          ) ??
          decodedMetadata?.isPayableBySmartContract,
      isUpgradeable:
          optionalAs<bool>(data['isUpgradeable'], 'isUpgradeable') ??
          decodedMetadata?.isUpgradeable,
      isReadable:
          optionalAs<bool>(data['isReadable'], 'isReadable') ??
          decodedMetadata?.isReadable,
      scamInfo: optionalAs<Map<String, dynamic>>(data['scamInfo'], 'scamInfo'),
      assets: optionalAs<Map<String, dynamic>>(data['assets'], 'assets'),
      txCount: (data['txCount'] as num?)?.toInt(),
      scrCount: (data['scrCount'] as num?)?.toInt(),
      deployTxHash: optionalAs<String>(data['deployTxHash'], 'deployTxHash'),
      deployedAt: (data['deployedAt'] as num?)?.toInt(),
      isGuardedFlag: optionalAs<bool>(data['isGuarded'], 'isGuarded'),
      timestamp: optionalInt(data['timestamp'], 'timestamp'),
      timestampMs: optionalInt(data['timestampMs'], 'timestampMs'),
    );
  }

  /// Account address.
  final Address address;

  /// Current nonce.
  final Nonce nonce;

  /// Current balance in EGLD base units.
  final Balance balance;

  /// Shard where the account lives.
  final int? shard;

  /// Associated username.
  final String username;

  /// Smart contract code (hex encoded).
  final String? code;

  /// Smart contract code hash.
  final String? codeHash;

  /// Storage trie root hash.
  final String? rootHash;

  /// Contract code metadata.
  final String? codeMetadata;

  /// Contract owner address.
  final Address? ownerAddress;

  /// Contract developer reward.
  final Balance? developerReward;

  /// Active guardian.
  final AccountGuardian? activeGuardian;

  /// Pending guardian.
  final AccountGuardian? pendingGuardian;

  /// Whether smart contract is payable (accepts EGLD).
  final bool? isPayable;

  /// Whether smart contract accepts payments from other smart contracts.
  final bool? isPayableBySmartContract;

  /// Whether smart contract is upgradeable.
  final bool? isUpgradeable;

  /// Whether smart contract storage is readable.
  final bool? isReadable;

  /// Scam detection information if account is flagged.
  /// Contains 'type' and 'info' fields when present.
  final Map<String, dynamic>? scamInfo;

  /// Account metadata (name, description, icon URL, social links).
  final Map<String, dynamic>? assets;

  /// Total number of transactions sent from this account.
  final int? txCount;

  /// Total number of smart contract results involving this account.
  final int? scrCount;

  /// Transaction hash of the contract deployment.
  final String? deployTxHash;

  /// Timestamp when the contract was deployed.
  final int? deployedAt;

  /// Whether account is guarded (from API flag).
  final bool? isGuardedFlag;

  /// Indexed account timestamp in seconds, if reported.
  ///
  /// The API reports it only when the account is requested with
  /// `withTimestamp=true`; without that flag the key is absent and this stays
  /// `null`. The gateway's account route does not carry it at all. Prefer
  /// [indexedAt], which does not depend on the reported unit.
  final int? timestamp;

  /// Indexed account timestamp in milliseconds, if reported.
  ///
  /// Gated behind the same `withTimestamp=true` request flag as [timestamp],
  /// and additionally absent for accounts whose indexed record predates
  /// millisecond granularity — in that case only [timestamp] is reported.
  final int? timestampMs;

  /// Instant of the account's indexed state, normalised to UTC.
  ///
  /// Prefers [timestampMs] and falls back to [timestamp], deciding the unit of
  /// whichever value it uses by magnitude via [ChainTimestamp].
  ///
  /// #### Returns
  /// `DateTime?` - UTC instant, or `null` when neither timestamp was reported,
  /// which is the case for every account fetched without `withTimestamp=true`
  ///
  /// #### Example
  /// ```dart
  /// final AccountOnNetwork account = await provider.getAccount(address);
  /// print(account.indexedAt);
  /// ```
  DateTime? get indexedAt =>
      ChainTimestamp.toDateTime(timestampMs ?? timestamp);

  /// Checks if account is a smart contract.
  ///
  /// #### Returns
  /// `bool` - True if account has deployed smart contract code
  bool get isContract => code != null && code!.isNotEmpty;

  /// Checks if account has active guardian.
  ///
  /// #### Returns
  /// `bool` - True if account has an active guardian for 2FA security
  bool get hasActiveGuardian => activeGuardian != null;

  /// Checks if account has pending guardian.
  ///
  /// #### Returns
  /// `bool` - True if account has a guardian activation pending
  bool get hasPendingGuardian => pendingGuardian != null;

  /// Checks if account has any guardian.
  ///
  /// #### Returns
  /// `bool` - True if account has active or pending guardian (2FA enabled)
  bool get isGuarded =>
      isGuardedFlag == true || hasActiveGuardian || hasPendingGuardian;

  @override
  String toString() =>
      'AccountOnNetwork('
      'address: ${address.bech32}, '
      'balance: ${balance.value}, '
      'nonce: ${nonce.value}, '
      'shard: $shard, '
      'username: $username, '
      'isContract: $isContract, '
      'isGuarded: $isGuarded)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountOnNetwork &&
        other.address == address &&
        other.nonce == nonce &&
        other.balance == balance &&
        other.shard == shard &&
        other.username == username &&
        other.code == code &&
        other.codeHash == codeHash &&
        other.rootHash == rootHash &&
        other.codeMetadata == codeMetadata &&
        other.ownerAddress == ownerAddress &&
        other.developerReward == developerReward &&
        other.activeGuardian == activeGuardian &&
        other.pendingGuardian == pendingGuardian &&
        other.isPayable == isPayable &&
        other.isPayableBySmartContract == isPayableBySmartContract &&
        other.isUpgradeable == isUpgradeable &&
        other.isReadable == isReadable &&
        other.scamInfo == scamInfo &&
        other.assets == assets &&
        other.txCount == txCount &&
        other.scrCount == scrCount &&
        other.deployTxHash == deployTxHash &&
        other.deployedAt == deployedAt &&
        other.isGuardedFlag == isGuardedFlag &&
        other.timestamp == timestamp &&
        other.timestampMs == timestampMs;
  }

  @override
  int get hashCode => Object.hashAll([
    address,
    nonce,
    balance,
    shard,
    username,
    code,
    codeHash,
    rootHash,
    codeMetadata,
    ownerAddress,
    developerReward,
    activeGuardian,
    pendingGuardian,
    isPayable,
    isPayableBySmartContract,
    isUpgradeable,
    isReadable,
    scamInfo,
    assets,
    txCount,
    scrCount,
    deployTxHash,
    deployedAt,
    isGuardedFlag,
    timestamp,
    timestampMs,
  ]);

  /// Builds a guardian from the API's flat `*GuardianAddress` /
  /// `*GuardianActivationEpoch` / `*GuardianServiceUid` scalars.
  ///
  /// `GET /accounts/:address?withGuardianInfo=true` returns those fields flat
  /// on the account object rather than as nested guardian objects. `nested` is
  /// still honoured as a fallback so gateway-shaped payloads keep parsing.
  /// Returns `null` when neither carries a guardian address.
  static AccountGuardian? _guardianFromApi(
    Map<String, dynamic> data, {
    required String addressKey,
    required String epochKey,
    required String serviceUidKey,
    required dynamic nested,
  }) {
    final String? flatAddress = optionalAs<String>(
      data[addressKey],
      addressKey,
    );
    if (flatAddress != null && flatAddress.isNotEmpty) {
      return AccountGuardian(
        address: Address.fromBech32(flatAddress),
        activationEpoch: optionalInt(data[epochKey], epochKey) ?? 0,
        serviceUID: optionalAs<String>(data[serviceUidKey], serviceUidKey),
      );
    }
    if (nested is Map<String, dynamic> && nested['address'] != null) {
      return AccountGuardian.fromApiResponse(nested);
    }
    return null;
  }
}

/// Guardian information for account security.
/// Guardians add an extra signature requirement for transactions, enhancing security.
///
/// #### Example
/// ```dart
/// final guardian = AccountGuardian(
///   address: Address.fromBech32('erd1guardian...'),
///   activationEpoch: 1234,
///   serviceUID: 'guardian-service-123',
/// );
///
/// // From API
/// final guardianFromApi = AccountGuardian.fromApiResponse(apiData['activeGuardian']);
/// print('Guardian active since epoch: ${guardianFromApi.activationEpoch}');
/// ```
class AccountGuardian {
  /// Creates guardian data.
  ///
  /// #### Parameters
  /// - `address` - Guardian address
  /// - `activationEpoch` - Epoch when guardian becomes/became active
  /// - `serviceUID` - Guardian service identifier (optional)
  const AccountGuardian({
    required this.address,
    required this.activationEpoch,
    this.serviceUID,
  });

  /// Creates from API response.
  ///
  /// Accepts both the gateway spelling `serviceUID` and the API spelling
  /// `serviceUid`.
  ///
  /// #### Parameters
  /// - `data` - JSON map from REST API guardian data
  ///
  /// #### Returns
  /// `AccountGuardian` - Parsed AccountGuardian instance
  ///
  /// #### Example
  /// ```dart
  /// final guardianData = {
  ///   'address': 'erd1guardian...',
  ///   'activationEpoch': 1234,
  ///   'serviceUID': 'service-123',
  /// };
  /// final guardian = AccountGuardian.fromApiResponse(guardianData);
  /// ```
  factory AccountGuardian.fromApiResponse(Map<String, dynamic> data) {
    return AccountGuardian(
      address: Address.fromBech32(
        requireAs<String>(data['address'], 'address'),
      ),
      activationEpoch: requireAs<int>(
        data['activationEpoch'],
        'activationEpoch',
      ),
      serviceUID:
          optionalAs<String>(data['serviceUID'], 'serviceUID') ??
          optionalAs<String>(data['serviceUid'], 'serviceUid'),
    );
  }

  /// Creates from Gateway (Proxy) response.
  ///
  /// #### Parameters
  /// - `data` - JSON map from Gateway guardian data
  ///
  /// #### Returns
  /// `AccountGuardian` - Parsed AccountGuardian instance
  ///
  /// #### Example
  /// ```dart
  /// final proxyAccountGuardian = {
  ///   'address': 'erd1guardian...',
  ///   'activationEpoch': '1234', // String in Proxy
  ///   'serviceUID': 'service-123',
  /// };
  /// final guardian = AccountGuardian.fromProxyResponse(proxyAccountGuardian);
  /// ```
  factory AccountGuardian.fromProxyResponse(Map<String, dynamic> data) {
    return AccountGuardian(
      address: Address.fromBech32(
        requireAs<String>(data['address'], 'address'),
      ),
      activationEpoch: int.parse(data['activationEpoch'].toString()),
      serviceUID: optionalAs<String>(data['serviceUID'], 'serviceUID'),
    );
  }

  /// Guardian address.
  final Address address;

  /// Activation epoch.
  final int activationEpoch;

  /// Service UID.
  final String? serviceUID;

  @override
  String toString() =>
      'AccountGuardian('
      'address: ${address.bech32}, '
      'activationEpoch: $activationEpoch, '
      'serviceUID: $serviceUID)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountGuardian &&
        other.address == address &&
        other.activationEpoch == activationEpoch &&
        other.serviceUID == serviceUID;
  }

  @override
  int get hashCode => Object.hash(address, activationEpoch, serviceUID);
}
