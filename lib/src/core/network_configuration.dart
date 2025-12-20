import 'transaction/chain_id.dart';
import 'transaction/gas_models/gas_limit.dart';
import 'transaction/gas_models/gas_price.dart';
import 'transaction/gas_models/gas_price_modifier.dart';
import 'transaction/transaction_version.dart';

/// Default chain ID (mainnet).
const String defaultChainId = '1';

/// Default gas cost per data byte.
const int defaultGasPerDataByte = 1500;

/// Default minimum gas limit.
const int defaultMinGasLimit = 50000;

/// Default minimum gas price (1 Gwei = 10^9 attoEGLD).
const int defaultMinGasPrice = 1000000000;

/// Default gas price modifier (1% increase for network variability).
const double defaultGasPriceModifier = 0.01;

/// Default minimum transaction version.
const int defaultMinTransactionVersion = 1;

/// Network configuration for MultiversX blockchain.
/// Contains gas limits, gas prices, chain ID, and transaction version. Use factory constructors for mainnet/testnet/devnet.
/// Sealed class ensures all configurations inherit from this base.
///
/// #### Example
/// ```dart
/// // Mainnet
/// final mainnet = NetworkConfiguration.mainnet();
/// print(mainnet.chainId.value); // '1'
///
/// // Testnet
/// final testnet = NetworkConfiguration.testnet();
/// print(testnet.chainId.value); // 'T'
///
/// // Devnet
/// final devnet = NetworkConfiguration.devnet();
/// print(devnet.chainId.value); // 'D'
///
/// // From chain ID
/// final config = NetworkConfiguration.fromChainId(ChainId('1'));
/// ```
sealed class NetworkConfiguration {
  /// Creates NetworkConfiguration with specified parameters.
  ///
  /// #### Parameters
  /// - `chainId` - Chain identifier (default: '1' for mainnet)
  /// - `gasPerDataByte` - Gas cost per data byte (default: 1500)
  /// - `minGasLimit` - Minimum gas limit (default: 50000)
  /// - `minGasPrice` - Minimum gas price in attoEGLD (default: 10^9)
  /// - `gasPriceModifier` - Fee calculation modifier (default: 0.01)
  /// - `minTransactionVersion` - Minimum transaction version (default: 1)
  const NetworkConfiguration({
    this.chainId = const ChainId(defaultChainId),
    this.gasPerDataByte = defaultGasPerDataByte,
    this.minGasLimit = const GasLimit(defaultMinGasLimit),
    this.minGasPrice = const GasPrice(defaultMinGasPrice),
    this.gasPriceModifier = const GasPriceModifier(defaultGasPriceModifier),
    this.minTransactionVersion = const TransactionVersion(
      defaultMinTransactionVersion,
    ),
  });

  /// Creates NetworkConfiguration for mainnet.
  ///
  /// #### Returns
  /// MainnetNetworkConfiguration with chain ID '1'
  ///
  /// #### Example
  /// ```dart
  /// final mainnet = NetworkConfiguration.mainnet();
  /// print(mainnet.chainId.isMainnet); // true
  /// ```
  factory NetworkConfiguration.mainnet() = MainnetNetworkConfiguration;

  /// Creates NetworkConfiguration for testnet.
  ///
  /// #### Returns
  /// TestnetNetworkConfiguration with chain ID 'T'
  ///
  /// #### Example
  /// ```dart
  /// final testnet = NetworkConfiguration.testnet();
  /// print(testnet.chainId.isTestnet); // true
  /// ```
  factory NetworkConfiguration.testnet() = TestnetNetworkConfiguration;

  /// Creates NetworkConfiguration for devnet.
  ///
  /// #### Returns
  /// DevnetNetworkConfiguration with chain ID 'D'
  ///
  /// #### Example
  /// ```dart
  /// final devnet = NetworkConfiguration.devnet();
  /// print(devnet.chainId.isDevnet); // true
  /// ```
  factory NetworkConfiguration.devnet() = DevnetNetworkConfiguration;

  /// Creates NetworkConfiguration from chain ID.
  ///
  /// #### Parameters
  /// - `chainId` - ChainId instance ('1', 'T', or 'D')
  ///
  /// #### Returns
  /// Appropriate NetworkConfiguration subclass
  ///
  /// #### Throws
  /// - `ArgumentError` - If chain ID is not '1', 'T', or 'D'
  ///
  /// #### Example
  /// ```dart
  /// final config1 = NetworkConfiguration.fromChainId(ChainId('1')); // mainnet
  /// final config2 = NetworkConfiguration.fromChainId(ChainId('T')); // testnet
  /// final config3 = NetworkConfiguration.fromChainId(ChainId('D')); // devnet
  /// ```
  factory NetworkConfiguration.fromChainId(ChainId chainId) {
    if (chainId.isMainnet) {
      return NetworkConfiguration.mainnet();
    } else if (chainId.isDevnet) {
      return NetworkConfiguration.devnet();
    } else if (chainId.isTestnet) {
      return NetworkConfiguration.testnet();
    }

    throw ArgumentError(
      'Invalid chain ID: ${chainId.value}. Must be "1", "D", or "T".',
    );
  }

  /// Chain ID.
  final ChainId chainId;

  /// Gas cost per data byte.
  final int gasPerDataByte;

  /// Minimum gas limit.
  final GasLimit minGasLimit;

  /// Minimum gas price.
  final GasPrice minGasPrice;

  /// Gas price modifier
  ///
  /// Used by [TransactionComputer.computeTransactionFee] to calculate
  /// the effective gas price
  final GasPriceModifier gasPriceModifier;

  /// Minimum transaction version.
  final TransactionVersion minTransactionVersion;
}

/// Network configuration for mainnet.
/// Chain ID is '1' with production defaults.
///
/// #### Example
/// ```dart
/// const mainnet = MainnetNetworkConfiguration();
/// print(mainnet.chainId.value); // '1'
/// ```
final class MainnetNetworkConfiguration extends NetworkConfiguration {
  /// Creates MainnetNetworkConfiguration.
  const MainnetNetworkConfiguration() : super();
}

/// Network configuration for testnet.
/// Chain ID is 'T' with testing defaults.
///
/// #### Example
/// ```dart
/// const testnet = TestnetNetworkConfiguration();
/// print(testnet.chainId.value); // 'T'
/// ```
final class TestnetNetworkConfiguration extends NetworkConfiguration {
  /// Creates TestnetNetworkConfiguration.
  const TestnetNetworkConfiguration() : super(chainId: const ChainId('T'));
}

/// Network configuration for devnet.
/// Chain ID is 'D' with development defaults.
///
/// #### Example
/// ```dart
/// const devnet = DevnetNetworkConfiguration();
/// print(devnet.chainId.value); // 'D'
/// ```
final class DevnetNetworkConfiguration extends NetworkConfiguration {
  /// Creates DevnetNetworkConfiguration.
  const DevnetNetworkConfiguration() : super(chainId: const ChainId('D'));
}
