import '../core/name_sanitizer.dart';
import '../models/file_output.dart';
import 'generator_base.dart';

class TransfersGenerator extends GeneratorBase {
  final NameSanitizer nameSanitizer;
  final bool generateUnsigned;

  TransfersGenerator({
    required this.nameSanitizer,
    this.generateUnsigned = true,
  });

  @override
  List<FileOutput> generate() {
    return [
      _generateEgldTransfer(),
      _generateEsdtTransfer(),
      _generateNftTransfer(),
      _generateMultiTransfer(),
      _generateTransfersController(),
    ];
  }

  FileOutput _generateEgldTransfer() {
    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());

    buffer.writeln('import \'dart:typed_data\';');
    buffer.writeln();
    buffer.writeln('import \'package:abidock_mvx/abidock_mvx.dart\';');
    buffer.writeln();

    buffer.writeln('/// Transfers native EGLD tokens.');
    buffer.writeln('Future<Transaction> egld(');
    buffer.writeln('  NetworkProvider provider,');
    buffer.writeln('  IAccount sender,');
    buffer.writeln('  Nonce nonce,');
    buffer.writeln('  Address receiver,');
    buffer.writeln('  Balance amount,');
    buffer.writeln('  {');
    buffer.writeln('    Address? relayer,');
    buffer.writeln('    Address? guardian,');
    buffer.writeln('    Uint8List? data,');
    buffer.writeln('    GasLimit? gasLimit,');
    buffer.writeln('  }');
    buffer.writeln(') async {');

    buffer.writeln('  final transfersCtrl = TransfersController(');
    buffer.writeln('    chainId: provider.chainId,');
    buffer.writeln('  );');
    buffer.writeln();
    buffer.writeln(
      '  final tx = await transfersCtrl.createTransactionForNativeTransfer(',
    );
    buffer.writeln('    sender,');
    buffer.writeln('    nonce,');
    buffer.writeln('    NativeTransferInput(');
    buffer.writeln('      receiver: receiver,');
    buffer.writeln('      amount: amount,');
    buffer.writeln('      data: data,');
    buffer.writeln('    ),');

    _writeBaseOptions(buffer, true);

    buffer.writeln('  );');
    buffer.writeln();
    buffer.writeln('  return tx;');
    buffer.writeln('}');

    return FileOutput(
      path: 'transfers/egld_transfer.dart',
      content: buffer.toString(),
    );
  }

  FileOutput _generateEsdtTransfer() {
    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());

    buffer.writeln('import \'package:abidock_mvx/abidock_mvx.dart\';');
    buffer.writeln();

    buffer.writeln('/// Transfers ESDT fungible tokens.');
    buffer.writeln('///');
    buffer.writeln(
      '/// Creates and signs a transaction for transferring ESDT tokens.',
    );
    buffer.writeln(
      '/// Supports any fungible ESDT token with specified amount.',
    );
    buffer.writeln('///');
    buffer.writeln('/// Example:');
    buffer.writeln('/// ```dart');
    buffer.writeln('/// final provider = GatewayProvider(');
    buffer.writeln('///   gatewayUrl: \'https://gateway.multiversx.com\',');
    buffer.writeln('/// );');
    buffer.writeln('/// final tx = await esdt(');
    buffer.writeln('///   provider,');
    buffer.writeln('///   sender: alice,');
    buffer.writeln('///   nonce: nonce,');
    buffer.writeln('///   receiver: bobAddress,');
    buffer.writeln('///   tokenId: \'MYTOKEN-abc123\',');
    buffer.writeln('///   amount: BigInt.from(1000),');
    buffer.writeln('/// );');
    buffer.writeln('/// await provider.sendTransaction(tx);');
    buffer.writeln('/// ```');
    buffer.writeln('Future<Transaction> esdt(');
    buffer.writeln('  NetworkProvider provider,');
    buffer.writeln('  IAccount sender,');
    buffer.writeln('  Nonce nonce,');
    buffer.writeln('  Address receiver,');
    buffer.writeln('  String tokenId,');
    buffer.writeln('  BigInt amount,');
    buffer.writeln('  {');
    buffer.writeln('    Address? relayer,');
    buffer.writeln('    Address? guardian,');
    buffer.writeln('    GasLimit? gasLimit,');
    buffer.writeln('  }');
    buffer.writeln(') async {');

    buffer.writeln('  final transfersCtrl = TransfersController(');
    buffer.writeln('    chainId: provider.chainId,');
    buffer.writeln('  );');
    buffer.writeln();
    buffer.writeln(
      '  final tx = await transfersCtrl.createTransactionForTokenTransfer(',
    );
    buffer.writeln('    sender,');
    buffer.writeln('    nonce,');
    buffer.writeln('    TokenTransferInput(');
    buffer.writeln('      receiver: receiver,');
    buffer.writeln('      transfers: [');
    buffer.writeln('        TokenTransfer.fungible(');
    buffer.writeln('          tokenIdentifier: tokenId,');
    buffer.writeln('          amount: amount,');
    buffer.writeln('        ),');
    buffer.writeln('      ],');
    buffer.writeln('    ),');

    _writeBaseOptions(buffer, true);

    buffer.writeln('  );');
    buffer.writeln();
    buffer.writeln('  return tx;');
    buffer.writeln('}');

    return FileOutput(
      path: 'transfers/esdt_transfer.dart',
      content: buffer.toString(),
    );
  }

  FileOutput _generateNftTransfer() {
    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());

    buffer.writeln('import \'package:abidock_mvx/abidock_mvx.dart\';');
    buffer.writeln();

    buffer.writeln('/// Transfers NFT/SFT tokens.');
    buffer.writeln('///');
    buffer.writeln(
      '/// Creates and signs a transaction for transferring non-fungible',
    );
    buffer.writeln(
      '/// or semi-fungible tokens. Requires token ID, nonce, and amount.',
    );
    buffer.writeln('///');
    buffer.writeln('/// Example:');
    buffer.writeln('/// ```dart');
    buffer.writeln('/// final provider = GatewayProvider(');
    buffer.writeln('///   gatewayUrl: \'https://gateway.multiversx.com\',');
    buffer.writeln('/// );');
    buffer.writeln('/// final tx = await nft(');
    buffer.writeln('///   provider,');
    buffer.writeln('///   sender: alice,');
    buffer.writeln('///   nonce: nonce,');
    buffer.writeln('///   receiver: bobAddress,');
    buffer.writeln('///   tokenId: \'NFT-abc123\',');
    buffer.writeln('///   tokenNonce: 42,');
    buffer.writeln('///   amount: BigInt.one,');
    buffer.writeln('/// );');
    buffer.writeln('/// await provider.sendTransaction(tx);');
    buffer.writeln('/// ```');
    buffer.writeln('Future<Transaction> nft(');
    buffer.writeln('  NetworkProvider provider,');
    buffer.writeln('  IAccount sender,');
    buffer.writeln('  Nonce nonce,');
    buffer.writeln('  Address receiver,');
    buffer.writeln('  String tokenId,');
    buffer.writeln('  int tokenNonce,');
    buffer.writeln('  BigInt amount,');
    buffer.writeln('  {');
    buffer.writeln('    Address? relayer,');
    buffer.writeln('    Address? guardian,');
    buffer.writeln('    GasLimit? gasLimit,');
    buffer.writeln('  }');
    buffer.writeln(') async {');

    buffer.writeln('  final transfersCtrl = TransfersController(');
    buffer.writeln('    chainId: provider.chainId,');
    buffer.writeln('  );');
    buffer.writeln();
    buffer.writeln(
      '  final tx = await transfersCtrl.createTransactionForTokenTransfer(',
    );
    buffer.writeln('    sender,');
    buffer.writeln('    nonce,');
    buffer.writeln('    TokenTransferInput(');
    buffer.writeln('      receiver: receiver,');
    buffer.writeln('      transfers: [');
    buffer.writeln('        TokenTransfer.nonFungible(');
    buffer.writeln('          tokenIdentifier: tokenId,');
    buffer.writeln('          nonce: tokenNonce,');
    buffer.writeln('          amount: amount,');
    buffer.writeln('        ),');
    buffer.writeln('      ],');
    buffer.writeln('    ),');

    _writeBaseOptions(buffer, true);

    buffer.writeln('  );');
    buffer.writeln();
    buffer.writeln('  return tx;');
    buffer.writeln('}');

    return FileOutput(
      path: 'transfers/nft_transfer.dart',
      content: buffer.toString(),
    );
  }

  FileOutput _generateMultiTransfer() {
    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());

    buffer.writeln('import \'package:abidock_mvx/abidock_mvx.dart\';');
    buffer.writeln();

    buffer.writeln(
      '/// Transfers multiple ESDT/NFT tokens in a single transaction.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// Creates and signs a transaction for transferring multiple tokens',
    );
    buffer.writeln(
      '/// (fungible, semi-fungible, or non-fungible) in a single transaction.',
    );
    buffer.writeln('/// Efficient for batch token transfers.');
    buffer.writeln('///');
    buffer.writeln('/// Example:');
    buffer.writeln('/// ```dart');
    buffer.writeln('/// final provider = GatewayProvider(');
    buffer.writeln('///   gatewayUrl: \'https://gateway.multiversx.com\',');
    buffer.writeln('/// );');
    buffer.writeln('/// final tx = await multi(');
    buffer.writeln('///   provider,');
    buffer.writeln('///   sender: alice,');
    buffer.writeln('///   nonce: nonce,');
    buffer.writeln('///   receiver: bobAddress,');
    buffer.writeln('///   transfers: [');
    buffer.writeln('///     TokenTransfer.fungible(');
    buffer.writeln('///       tokenIdentifier: \'TOKEN-abc123\',');
    buffer.writeln('///       amount: BigInt.from(500),');
    buffer.writeln('///     ),');
    buffer.writeln('///     TokenTransfer.nonFungible(');
    buffer.writeln('///       tokenIdentifier: \'NFT-def456\',');
    buffer.writeln('///       nonce: 1,');
    buffer.writeln('///       amount: BigInt.one,');
    buffer.writeln('///     ),');
    buffer.writeln('///   ],');
    buffer.writeln('/// );');
    buffer.writeln('/// await provider.sendTransaction(tx);');
    buffer.writeln('/// ```');
    buffer.writeln('Future<Transaction> multi(');
    buffer.writeln('  NetworkProvider provider,');
    buffer.writeln('  IAccount sender,');
    buffer.writeln('  Nonce nonce,');
    buffer.writeln('  Address receiver,');
    buffer.writeln('  List<TokenTransfer> transfers,');
    buffer.writeln('  {');
    buffer.writeln('    Address? relayer,');
    buffer.writeln('    Address? guardian,');
    buffer.writeln('    GasLimit? gasLimit,');
    buffer.writeln('  }');
    buffer.writeln(') async {');

    buffer.writeln('  final transfersCtrl = TransfersController(');
    buffer.writeln('    chainId: provider.chainId,');
    buffer.writeln('  );');
    buffer.writeln();
    buffer.writeln(
      '  final tx = await transfersCtrl.createTransactionForMultiTokenTransfer(',
    );
    buffer.writeln('    sender,');
    buffer.writeln('    nonce,');
    buffer.writeln('    TokenTransferInput(');
    buffer.writeln('      receiver: receiver,');
    buffer.writeln('      transfers: transfers,');
    buffer.writeln('    ),');

    _writeBaseOptions(buffer, true);

    buffer.writeln('  );');
    buffer.writeln();
    buffer.writeln('  return tx;');
    buffer.writeln('}');

    return FileOutput(
      path: 'transfers/multi_transfer.dart',
      content: buffer.toString(),
    );
  }

  void _writeBaseOptions(StringBuffer buffer, bool needsGasLimit) {
    buffer.write('    baseOptions: ');
    final conditions = <String>[];
    if (needsGasLimit) conditions.add('gasLimit != null');
    conditions.add('relayer != null');
    conditions.add('guardian != null');

    buffer.writeln(conditions.join(' || '));
    buffer.write('        ? BaseControllerInput(');
    final params = <String>[];
    if (needsGasLimit) params.add('gasLimit: gasLimit');
    params.add('relayer: relayer');
    params.add('guardian: guardian');
    buffer.writeln(params.join(', '));
    buffer.writeln('        )');
    buffer.writeln('        : const BaseControllerInput(),');
  }

  FileOutput _generateTransfersController() {
    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());

    buffer.writeln('import \'dart:typed_data\';');
    buffer.writeln();
    buffer.writeln('import \'package:abidock_mvx/abidock_mvx.dart\';');
    buffer.writeln();
    buffer.writeln('import \'transfers/egld_transfer.dart\' as egld_transfer;');
    buffer.writeln('import \'transfers/esdt_transfer.dart\' as esdt_transfer;');
    buffer.writeln(
      'import \'transfers/multi_transfer.dart\' as multi_transfer;',
    );
    buffer.writeln('import \'transfers/nft_transfer.dart\' as nft_transfer;');
    buffer.writeln();

    buffer.writeln('/// Stateless transfer helper for direct token moves.');
    buffer.writeln(
      '/// Handles EGLD, ESDT, NFT, and multi-token batches without controllers.',
    );
    buffer.writeln('class TransferService {');
    buffer.writeln('  const TransferService(this._provider);');
    buffer.writeln();
    buffer.writeln('  final NetworkProvider _provider;');
    buffer.writeln();

    buffer.writeln('  /// Transfers native EGLD tokens.');
    buffer.writeln('  Future<Transaction> egld(');
    buffer.writeln('    IAccount sender,');
    buffer.writeln('    Nonce nonce,');
    buffer.writeln('    Address receiver,');
    buffer.writeln('    Balance amount,');
    buffer.writeln('    {');
    buffer.writeln('      Address? relayer,');
    buffer.writeln('      Address? guardian,');
    buffer.writeln('      Uint8List? data,');
    buffer.writeln('      GasLimit? gasLimit,');
    buffer.writeln('    }');
    buffer.write(
      '  ) => egld_transfer.egld(_provider, sender, nonce, receiver, amount',
    );

    final forwardParams = <String>[
      'relayer: relayer',
      'guardian: guardian',
      'data: data',
      'gasLimit: gasLimit',
    ];

    buffer.writeln(', ${forwardParams.join(', ')});');
    buffer.writeln();

    buffer.writeln('  /// Transfers ESDT fungible tokens.');
    buffer.writeln('  Future<Transaction> esdt(');
    buffer.writeln('    IAccount sender,');
    buffer.writeln('    Nonce nonce,');
    buffer.writeln('    Address receiver,');
    buffer.writeln('    String tokenId,');
    buffer.writeln('    BigInt amount,');
    buffer.writeln('    {');
    buffer.writeln('      Address? relayer,');
    buffer.writeln('      Address? guardian,');
    buffer.writeln('      GasLimit? gasLimit,');
    buffer.writeln('    }');
    buffer.write(
      '  ) => esdt_transfer.esdt(_provider, sender, nonce, receiver, tokenId, amount',
    );

    final forwardParamsEsdt = <String>[
      'relayer: relayer',
      'guardian: guardian',
      'gasLimit: gasLimit',
    ];

    buffer.writeln(', ${forwardParamsEsdt.join(', ')});');
    buffer.writeln();

    buffer.writeln('  /// Transfers NFT/SFT tokens.');
    buffer.writeln('  Future<Transaction> nft(');
    buffer.writeln('    IAccount sender,');
    buffer.writeln('    Nonce nonce,');
    buffer.writeln('    Address receiver,');
    buffer.writeln('    String tokenId,');
    buffer.writeln('    int tokenNonce,');
    buffer.writeln('    BigInt amount,');
    buffer.writeln('    {');
    buffer.writeln('      Address? relayer,');
    buffer.writeln('      Address? guardian,');
    buffer.writeln('      GasLimit? gasLimit,');
    buffer.writeln('    }');
    buffer.write(
      '  ) => nft_transfer.nft(_provider, sender, nonce, receiver, tokenId, tokenNonce, amount',
    );

    final forwardParamsNft = <String>[
      'relayer: relayer',
      'guardian: guardian',
      'gasLimit: gasLimit',
    ];

    buffer.writeln(', ${forwardParamsNft.join(', ')});');
    buffer.writeln();

    buffer.writeln('  /// Transfers multiple ESDT/NFT tokens.');
    buffer.writeln('  Future<Transaction> multi(');
    buffer.writeln('    IAccount sender,');
    buffer.writeln('    Nonce nonce,');
    buffer.writeln('    Address receiver,');
    buffer.writeln('    List<TokenTransfer> transfers,');
    buffer.writeln('    {');
    buffer.writeln('      Address? relayer,');
    buffer.writeln('      Address? guardian,');
    buffer.writeln('      GasLimit? gasLimit,');
    buffer.writeln('    }');
    buffer.write(
      '  ) => multi_transfer.multi(_provider, sender, nonce, receiver, transfers',
    );

    final forwardParamsMulti = <String>[
      'relayer: relayer',
      'guardian: guardian',
      'gasLimit: gasLimit',
    ];

    buffer.writeln(', ${forwardParamsMulti.join(', ')});');

    if (generateUnsigned) {
      buffer.writeln();
      buffer.writeln('  /// Raw transfer factory exposed for custom batching.');
      buffer.writeln(
        '  TransferTransactionsFactory get transferFactory => TransferTransactionsFactory(',
      );
      buffer.writeln(
        '    config: TransferTransactionsConfig(chainId: _provider.chainId),',
      );
      buffer.writeln('  );');
      buffer.writeln();
      buffer.writeln('  /// Unsigned EGLD transfer for offline batching.');
      buffer.writeln('  Transaction egldUnsigned({');
      buffer.writeln('    required Address sender,');
      buffer.writeln('    required Nonce nonce,');
      buffer.writeln('    required Address receiver,');
      buffer.writeln('    required Balance amount,');
      buffer.writeln('    Uint8List? data,');
      buffer.writeln('    GasLimit? gasLimit,');
      buffer.writeln('  }) {');
      buffer.writeln(
        '    return transferFactory.createTransactionForNativeTokenTransfer(',
      );
      buffer.writeln('      sender: sender,');
      buffer.writeln('      receiver: receiver,');
      buffer.writeln('      nativeAmount: amount,');
      buffer.writeln('      data: data,');
      buffer.writeln('      gasLimit: gasLimit,');
      buffer.writeln('    ).copyWith(newNonce: nonce);');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  /// Unsigned ESDT transfer for offline batching.');
      buffer.writeln('  Transaction esdtUnsigned({');
      buffer.writeln('    required Address sender,');
      buffer.writeln('    required Nonce nonce,');
      buffer.writeln('    required Address receiver,');
      buffer.writeln('    required String tokenId,');
      buffer.writeln('    required BigInt amount,');
      buffer.writeln('    GasLimit? gasLimit,');
      buffer.writeln('  }) {');
      buffer.writeln(
        '    return transferFactory.createTransactionForEsdtTransfer(',
      );
      buffer.writeln('      sender: sender,');
      buffer.writeln('      receiver: receiver,');
      buffer.writeln('      tokenTransfers: [');
      buffer.writeln(
        '        TokenTransfer.fungible(tokenIdentifier: tokenId, amount: amount),',
      );
      buffer.writeln('      ],');
      buffer.writeln('      gasLimit: gasLimit,');
      buffer.writeln('    ).copyWith(newNonce: nonce);');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  /// Unsigned NFT/SFT transfer for offline batching.');
      buffer.writeln('  Transaction nftUnsigned({');
      buffer.writeln('    required Address sender,');
      buffer.writeln('    required Nonce nonce,');
      buffer.writeln('    required Address receiver,');
      buffer.writeln('    required String tokenId,');
      buffer.writeln('    required int tokenNonce,');
      buffer.writeln('    required BigInt amount,');
      buffer.writeln('    GasLimit? gasLimit,');
      buffer.writeln('  }) {');
      buffer.writeln(
        '    return transferFactory.createTransactionForEsdtTransfer(',
      );
      buffer.writeln('      sender: sender,');
      buffer.writeln('      receiver: receiver,');
      buffer.writeln('      tokenTransfers: [');
      buffer.writeln(
        '        TokenTransfer.nonFungible(tokenIdentifier: tokenId, nonce: tokenNonce, amount: amount),',
      );
      buffer.writeln('      ],');
      buffer.writeln('      gasLimit: gasLimit,');
      buffer.writeln('    ).copyWith(newNonce: nonce);');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln(
        '  /// Unsigned multi-token transfer for offline batching.',
      );
      buffer.writeln('  Transaction multiUnsigned({');
      buffer.writeln('    required Address sender,');
      buffer.writeln('    required Nonce nonce,');
      buffer.writeln('    required Address receiver,');
      buffer.writeln('    required List<TokenTransfer> transfers,');
      buffer.writeln('    GasLimit? gasLimit,');
      buffer.writeln('  }) {');
      buffer.writeln(
        '    return transferFactory.createTransactionForEsdtTransfer(',
      );
      buffer.writeln('      sender: sender,');
      buffer.writeln('      receiver: receiver,');
      buffer.writeln('      tokenTransfers: transfers,');
      buffer.writeln('      gasLimit: gasLimit,');
      buffer.writeln('    ).copyWith(newNonce: nonce);');
      buffer.writeln('  }');
    }

    buffer.writeln('}');

    return FileOutput(
      path: 'transfer_service.dart',
      content: buffer.toString(),
    );
  }
}
