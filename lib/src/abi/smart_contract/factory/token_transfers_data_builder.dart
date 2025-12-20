/// Builds transaction data parts for ESDT/NFT/SFT token transfers.
import '../../../core/address.dart';
import '../../abi.dart';

/// Builds transaction data parts for ESDT token transfers.
/// Encodes token transfers according to MultiversX protocol specifications.
///
/// #### Example
/// ```dart
/// final builder = TokenTransfersDataBuilder(
///   serializer: ArgSerializer(),
/// );
///
/// // Single fungible token transfer
/// final esdtParts = builder.buildDataPartsForESDTTransfer(
///   TokenTransferValue.fromPrimitives(
///     tokenIdentifier: 'MYTOKEN-abc123',
///     amount: BigInt.from(1000),
///   ),
/// );
///
/// // Multi-token transfer
/// final multiParts = builder.buildDataPartsForMultiESDTNFTTransfer(
///   Address.fromBech32('erd1...'),
///   [transfer1, transfer2],
/// );
/// ```
class TokenTransfersDataBuilder {
  /// Creates token transfers builder with argument serializer.
  ///
  /// #### Parameters
  /// - `serializer` - Serializer for encoding typed values
  const TokenTransfersDataBuilder({required this.serializer});

  /// The argument serializer for encoding typed values.
  final ArgSerializer serializer;

  /// Builds data parts for ESDTTransfer.
  ///
  /// Use for transferring fungible ESDT tokens.
  ///
  /// #### Parameters
  /// - `transfer` - Fungible token transfer details
  ///
  /// #### Returns
  /// `List<String>` with ['ESDTTransfer', tokenId, amount]
  ///
  /// #### Throws
  /// - `ArgumentError` - If transfer has nonce (is NFT/SFT)
  List<String> buildDataPartsForESDTTransfer(TokenTransferValue transfer) {
    if (transfer.isNft) {
      throw ArgumentError(
        'ESDTTransfer requires fungible token (no nonce), '
        'got ${transfer.tokenIdentifier.identifier} with nonce ${transfer.nonce?.value}',
      );
    }
    final List<String> encodedArgs = serializer.valuesToStrings(<TypedValue>[
      transfer.tokenIdentifier,
      transfer.amount,
    ]);

    return <String>['ESDTTransfer', ...encodedArgs];
  }

  /// Builds data parts for ESDTNFTTransfer (single NFT/SFT).
  ///
  /// Use for transferring a single NFT or SFT (with nonce).
  ///
  /// #### Parameters
  /// - `transfer` - NFT/SFT transfer with nonce
  /// - `destination` - Recipient address
  ///
  /// #### Returns
  /// `List<String>` with ['ESDTNFTTransfer', tokenId, nonce, amount, destination]
  ///
  /// #### Throws
  /// - `ArgumentError` - If transfer is fungible (no nonce)
  List<String> buildDataPartsForSingleESDTNFTTransfer(
    TokenTransferValue transfer,
    Address destination,
  ) {
    if (transfer.isFungible) {
      throw ArgumentError(
        'ESDTNFTTransfer requires NFT/SFT token (with nonce), '
        'got fungible token ${transfer.tokenIdentifier.identifier}',
      );
    }

    final List<String> encodedArgs = serializer.valuesToStrings(<TypedValue>[
      transfer.tokenIdentifier,
      transfer.nonce!,
      transfer.amount,
      AddressValue(destination.bytes),
    ]);

    return <String>['ESDTNFTTransfer', ...encodedArgs];
  }

  /// Builds data parts for MultiESDTNFTTransfer (multiple tokens).
  ///
  /// Use for transferring multiple tokens (fungible, NFT, or SFT) in one transaction.
  ///
  /// #### Parameters
  /// - `destination` - Recipient address
  /// - `transfers` - List of token transfers
  ///
  /// #### Returns
  /// `List<String>` with ['MultiESDTNFTTransfer', destination, count, ...tokens]
  ///
  /// #### Throws
  /// - `ArgumentError` - If transfers list is empty
  List<String> buildDataPartsForMultiESDTNFTTransfer(
    Address destination,
    List<TokenTransferValue> transfers,
  ) {
    if (transfers.isEmpty) {
      throw ArgumentError(
        'MultiESDTNFTTransfer requires at least one transfer',
      );
    }

    final List<TypedValue> typedValues = <TypedValue>[
      AddressValue(destination.bytes),
      U32Value(transfers.length),
    ];

    for (final TokenTransferValue transfer in transfers) {
      typedValues.addAll(<TypedValue>[
        transfer.tokenIdentifier,
        transfer.nonce ?? U64Value(BigInt.zero),
        transfer.amount,
      ]);
    }

    final List<String> encodedArgs = serializer.valuesToStrings(typedValues);

    return <String>['MultiESDTNFTTransfer', ...encodedArgs];
  }
}
