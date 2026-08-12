/// Factory for creating unsigned smart contract call transactions.
/// Builds transactions ready for signing without nonce management or gas estimation.
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/address.dart';
import '../../../core/balance.dart';
import '../../../core/network_configuration.dart';
import '../../../core/nonce.dart';
import '../../../core/transaction/chain_id.dart';
import '../../../core/transaction/gas_models/gas_limit.dart';
import '../../../core/transaction/transaction.dart';
import '../../../core/transaction/transaction_version.dart';
import '../../../infrastructure/logging/logger.dart';
import '../../../utils/hex_utils.dart';
import '../../abi.dart';
import '../utils/argument_validation.dart';

/// Factory for creating unsigned smart contract call transactions.
///
/// Builds transaction data with optional ABI validation. Does NOT handle signing,
/// nonce management, gas estimation, or guardian/relayer setup.
///
/// Supports two modes of operation:
/// - **With ABI**: Arguments are native Dart values, automatically validated and encoded
/// - **Without ABI**: Arguments must be [TypedValue] or [Uint8List], no validation
///
/// #### Example with ABI
/// ```dart
/// final factory = SmartContractCallFactory(
///   contractAddress: SmartContractAddress.fromBech32('erd1qqqqqq...'),
///   abi: contractAbi,
///   chainId: ChainId.devnet(),
/// );
///
/// final tx = factory.createCall(
///   sender: wallet.address,
///   nonce: Nonce(42),
///   endpointName: 'increment',
///   arguments: [BigInt.from(100)],
///   gasLimit: GasLimit(5000000),
/// );
/// ```
///
/// #### Example without ABI
/// ```dart
/// final factory = SmartContractCallFactory.withoutAbi(
///   contractAddress: SmartContractAddress.fromBech32('erd1qqqqqq...'),
///   chainId: ChainId.devnet(),
/// );
///
/// final tx = factory.createCall(
///   sender: wallet.address,
///   nonce: Nonce(42),
///   endpointName: 'increment',
///   arguments: [BigUIntValue(BigInt.from(100))],
///   gasLimit: GasLimit(5000000),
/// );
/// ```
final class SmartContractCallFactory {
  /// Creates factory with contract address, ABI, and chain configuration.
  ///
  /// #### Parameters
  /// - `contractAddress` - Target smart contract address
  /// - `abi` - Smart contract ABI for validation and encoding
  /// - `chainId` - Network chain ID (mainnet, devnet, testnet)
  /// - `logger` - Optional logger for debugging
  SmartContractCallFactory({
    required this.contractAddress,
    required SmartContractAbi abi,
    required ChainId chainId,
    this.logger,
  }) : _abi = abi,
       _networkConfig = NetworkConfiguration.fromChainId(chainId),
       _endpointResolver = EndpointResolver(abi, logger: logger),
       _argumentEncoder = ArgumentEncoder(
         serializer: ArgSerializer(),
         resolver: EndpointResolver(abi, logger: logger),
         logger: logger,
       ),
       _tokenTransfersBuilder = TokenTransfersDataBuilder(
         serializer: ArgSerializer(),
       ),
       _rawArgValidator = RawArgumentValidator(ArgSerializer());

  /// Creates factory without ABI for raw [TypedValue] or [Uint8List] arguments.
  ///
  /// When no ABI is provided, arguments must be pre-typed:
  /// - [TypedValue] instances (e.g., [BigUIntValue], [AddressValue])
  /// - [Uint8List] raw bytes (will be hex-encoded directly)
  ///
  /// #### Parameters
  /// - `contractAddress` - Target smart contract address
  /// - `chainId` - Network chain ID (mainnet, devnet, testnet)
  /// - `logger` - Optional logger for debugging
  ///
  /// #### Example
  /// ```dart
  /// final factory = SmartContractCallFactory.withoutAbi(
  ///   contractAddress: SmartContractAddress.fromBech32('erd1qqqqqq...'),
  ///   chainId: ChainId.devnet(),
  /// );
  ///
  /// final tx = factory.createCall(
  ///   sender: wallet.address,
  ///   nonce: Nonce(42),
  ///   endpointName: 'swapTokens',
  ///   arguments: [
  ///     TokenIdentifierValue('WEGLD-abc123'),
  ///     BigUIntValue(BigInt.from(1000000000000000000)),
  ///   ],
  ///   gasLimit: GasLimit(15000000),
  /// );
  /// ```
  SmartContractCallFactory.withoutAbi({
    required this.contractAddress,
    required ChainId chainId,
    this.logger,
  }) : _abi = null,
       _networkConfig = NetworkConfiguration.fromChainId(chainId),
       _endpointResolver = null,
       _argumentEncoder = null,
       _tokenTransfersBuilder = TokenTransfersDataBuilder(
         serializer: ArgSerializer(),
       ),
       _rawArgValidator = RawArgumentValidator(ArgSerializer());

  /// The target smart contract address.
  final SmartContractAddress contractAddress;

  /// The smart contract ABI for validation and encoding (optional).
  final SmartContractAbi? _abi;

  /// The smart contract ABI for validation and encoding.
  ///
  /// #### Throws
  /// - [StateError] if factory was created without ABI
  SmartContractAbi get abi {
    if (_abi == null) {
      throw StateError(
        'ABI is not available. Factory was created with withoutAbi().',
      );
    }
    return _abi;
  }

  /// Whether this factory has an ABI for validation.
  bool get hasAbi => _abi != null;

  /// Optional logger for debugging.
  final Logger? logger;

  /// Network configuration (gas prices, chain ID, etc.).
  final NetworkConfiguration _networkConfig;

  /// Endpoint resolver for ABI validation (null when no ABI).
  final EndpointResolver? _endpointResolver;

  /// Argument encoder for ABI encoding (null when no ABI).
  final ArgumentEncoder? _argumentEncoder;

  /// Token transfers data builder for ESDT/NFT transfers.
  final TokenTransfersDataBuilder _tokenTransfersBuilder;

  /// Validator for raw arguments (used when no ABI).
  final RawArgumentValidator _rawArgValidator;

  /// Creates unsigned transaction for smart contract call.
  ///
  /// Builds transaction with ABI-validated arguments and data field.
  /// No signing, nonce fetching, or gas estimation is performed.
  ///
  /// #### Parameters
  /// - `sender` - Transaction sender address
  /// - `nonce` - Sender's account nonce (must be provided)
  /// - `endpointName` - Smart contract function name to call
  /// - `arguments` - Function arguments (native Dart values)
  /// - `gasLimit` - Gas limit for the transaction (required)
  /// - `value` - Optional EGLD value to send
  ///
  /// #### Returns
  /// `Transaction` - Unsigned transaction ready for signing
  ///
  /// #### Throws
  /// - `EndpointNotFoundException` - If endpoint not found in ABI
  /// - `ArgumentError` - If endpoint is view-only
  /// - `ArgumentEncodingException` - If arguments don't match endpoint signature
  ///
  /// #### Example
  /// ```dart
  /// // Simple call without tokens
  /// final tx = factory.createCall(
  ///   sender: walletAddress,
  ///   nonce: Nonce(42),
  ///   endpointName: 'deposit',
  ///   arguments: [BigInt.from(1000)],
  ///   gasLimit: GasLimit(10000000),
  ///   value: Balance.fromEgld(0.1),
  /// );
  ///
  /// // Call with token transfers
  /// final txWithTokens = factory.createCall(
  ///   sender: walletAddress,
  ///   nonce: Nonce(42),
  ///   endpointName: 'stake',
  ///   tokenTransfers: [
  ///     TokenTransferValue.fromPrimitives(
  ///       tokenIdentifier: 'STAKE-abc123',
  ///       amount: BigInt.from(1000000),
  ///     ),
  ///   ],
  ///   gasLimit: GasLimit(15000000),
  /// );
  /// ```
  /// ```
  Transaction createCall({
    required Address sender,
    required Nonce nonce,
    required String endpointName,
    List<dynamic> arguments = const <dynamic>[],
    List<TokenTransferValue> tokenTransfers = const <TokenTransferValue>[],
    required GasLimit gasLimit,
    Balance? value,
    Address? guardian,
  }) {
    return _buildTransaction(
      sender: sender,
      nonce: nonce,
      endpointName: endpointName,
      arguments: arguments,
      tokenTransfers: tokenTransfers,
      gasLimit: gasLimit,
      value: value,
      guardian: guardian,
    );
  }

  /// Builds the transaction with proper data encoding.
  Transaction _buildTransaction({
    required Address sender,
    required Nonce nonce,
    required String endpointName,
    required List<dynamic> arguments,
    required List<TokenTransferValue> tokenTransfers,
    required GasLimit gasLimit,
    Balance? value,
    Address? guardian,
  }) {
    final SmartContractFunction function = SmartContractFunction.validated(
      endpointName,
    );

    AbiEndpoint? endpoint;
    if (hasAbi) {
      endpoint = _endpointResolver!.getEndpoint(function.name);

      if (endpoint.isView) {
        throw ArgumentError(
          'Cannot create transaction for view endpoint "${endpoint.name}". '
          'Use SmartContractQueryRunner for queries instead.',
        );
      }

      if (tokenTransfers.isNotEmpty) {
        _validateTokenTransfersForEndpoint(endpoint, tokenTransfers);
      }
    }

    logger?.debug(
      'Building smart contract call transaction',
      context: <String, dynamic>{
        'contract': contractAddress.bech32,
        'endpoint': endpointName,
        'sender': sender.bech32,
        'nonce': nonce.value,
        'gasLimit': gasLimit.value,
        'argsCount': arguments.length,
        'tokenTransfersCount': tokenTransfers.length,
        'hasAbi': hasAbi.toString(),
      },
    );

    Address effectiveReceiver = contractAddress;
    final List<String> dataParts = <String>[];

    if (tokenTransfers.isNotEmpty) {
      final TransferType transferType = determineTransferType(tokenTransfers);

      switch (transferType) {
        case TransferType.esdtTransfer:
          dataParts.addAll(
            _tokenTransfersBuilder.buildDataPartsForESDTTransfer(
              tokenTransfers[0],
            ),
          );
          break;

        case TransferType.esdtNftTransfer:
          dataParts.addAll(
            _tokenTransfersBuilder.buildDataPartsForSingleESDTNFTTransfer(
              tokenTransfers[0],
              contractAddress,
            ),
          );
          effectiveReceiver = sender;

        case TransferType.multiEsdtNftTransfer:
          dataParts.addAll(
            _tokenTransfersBuilder.buildDataPartsForMultiESDTNFTTransfer(
              contractAddress,
              tokenTransfers,
            ),
          );
          effectiveReceiver = sender;

        case TransferType.regular:
          break;
      }
    }

    if (dataParts.isNotEmpty) {
      dataParts.add(HexUtils.utf8ToHex(function.name));
    } else {
      dataParts.add(function.name);
    }

    if (arguments.isNotEmpty) {
      final List<String> encodedArgs = _encodeArguments(
        endpoint: endpoint,
        arguments: arguments,
      );
      dataParts.addAll(encodedArgs);
    }

    final String dataString = dataParts.join('@');
    final Uint8List data = Uint8List.fromList(utf8.encode(dataString));

    return Transaction(
      nonce: nonce,
      sender: sender,
      receiver: effectiveReceiver,
      data: data,
      gasLimit: gasLimit,
      gasPrice: _networkConfig.minGasPrice,
      chainId: _networkConfig.chainId,
      version: TransactionVersion(guardian != null ? 2 : 1),
      value: value ?? Balance.zero(),
      guardian: guardian,
    );
  }

  /// Encodes arguments based on ABI availability.
  List<String> _encodeArguments({
    required AbiEndpoint? endpoint,
    required List<dynamic> arguments,
  }) {
    if (hasAbi && endpoint != null) {
      return _argumentEncoder!.encodeForEndpoint(
        endpoint: endpoint,
        arguments: arguments,
      );
    }

    return _rawArgValidator.encodeRawArguments(arguments, context: 'call');
  }

  /// Validates token transfers against endpoint's payableInTokens.
  void _validateTokenTransfersForEndpoint(
    AbiEndpoint endpoint,
    List<TokenTransferValue> transfers,
  ) {
    if (transfers.isEmpty) return;

    if (endpoint.payableInTokens.isEmpty) {
      throw ArgumentEncodingException(
        'Endpoint "${endpoint.name}" is not payable in tokens, but '
        '${transfers.length} token transfer(s) provided',
        endpointName: endpoint.name,
      );
    }

    for (final TokenTransferValue transfer in transfers) {
      final String tokenId = transfer.tokenIdentifier.identifier;
      bool isAllowed = false;

      for (final String allowedPattern in endpoint.payableInTokens) {
        if (allowedPattern == '*') {
          isAllowed = true;
          break;
        }

        if (allowedPattern.endsWith('-*')) {
          final String prefix = allowedPattern.substring(
            0,
            allowedPattern.length - 2,
          );
          if (tokenId.startsWith('$prefix-')) {
            isAllowed = true;
            break;
          }
        }

        if (tokenId == allowedPattern) {
          isAllowed = true;
          break;
        }
      }

      if (!isAllowed) {
        throw ArgumentEncodingException(
          'Token "$tokenId" is not accepted by endpoint "${endpoint.name}". '
          'Accepted tokens: ${endpoint.payableInTokens.join(', ')}',
          endpointName: endpoint.name,
        );
      }
    }
  }

  /// Checks if an endpoint exists in the ABI.
  ///
  /// #### Parameters
  /// - `endpointName` - Name of the endpoint to check
  ///
  /// #### Returns
  /// `true` if endpoint exists, `false` otherwise
  ///
  /// #### Throws
  /// - [StateError] if factory was created without ABI
  bool hasEndpoint(String endpointName) {
    if (_endpointResolver == null) {
      throw StateError(
        'Cannot check endpoint: factory was created without ABI.',
      );
    }
    return _endpointResolver.hasEndpoint(endpointName);
  }

  /// Gets an endpoint definition from the ABI.
  ///
  /// #### Parameters
  /// - `endpointName` - Name of the endpoint
  ///
  /// #### Returns
  /// `AbiEndpoint` definition
  ///
  /// #### Throws
  /// - [EndpointNotFoundException] if endpoint not found
  /// - [StateError] if factory was created without ABI
  AbiEndpoint getEndpoint(String endpointName) {
    if (_endpointResolver == null) {
      throw StateError('Cannot get endpoint: factory was created without ABI.');
    }
    return _endpointResolver.getEndpoint(endpointName);
  }

  /// Gets all mutable (non-view) endpoints from the ABI.
  ///
  /// #### Returns
  /// List of endpoints that can be called with transactions
  ///
  /// #### Throws
  /// - [StateError] if factory was created without ABI
  List<AbiEndpoint> getMutableEndpoints() {
    if (_endpointResolver == null) {
      throw StateError(
        'Cannot get endpoints: factory was created without ABI.',
      );
    }
    return _endpointResolver
        .getAllEndpoints()
        .where((AbiEndpoint e) => !e.isView)
        .toList();
  }
}
