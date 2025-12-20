class CodegenConfig {
  final String abiPath;
  final String outputDir;
  final String contractName;
  final bool useLogger;
  final bool useAutoGas;
  final bool useTransfers;

  const CodegenConfig({
    required this.abiPath,
    required this.outputDir,
    required this.contractName,
    this.useLogger = false,
    this.useAutoGas = false,
    this.useTransfers = false,
  });

  factory CodegenConfig.fromArgs(List<String> args) {
    String? abiPath;
    String? outputDir;
    String? contractName;

    final useFull = args.contains('--full');
    final useLogger = useFull || args.contains('--logger');
    final useAutoGas = useFull || args.contains('--autogas');
    final useTransfers = useFull || args.contains('--transfers');

    final positionalArgs = args.where((arg) => !arg.startsWith('--')).toList();

    if (positionalArgs.isNotEmpty) abiPath = positionalArgs[0];
    if (positionalArgs.length >= 2) outputDir = positionalArgs[1];
    if (positionalArgs.length >= 3) contractName = positionalArgs[2];

    if (abiPath == null || outputDir == null || contractName == null) {
      throw ArgumentError(
        'Usage: dart run bin/abidock.dart <abi_path> <output_dir> <contract_name> [options]\n'
        '\n'
        'Options:\n'
        '  --logger     Auto-inject ConsoleLogger in generated controller\n'
        '  --autogas    Use automatic gas estimation via simulation\n'
        '  --transfers  Generate transfer controller for EGLD/ESDT/NFT\n'
        '  --full       Enable ALL features (logger + autogas + transfers)\n',
      );
    }

    return CodegenConfig(
      abiPath: abiPath,
      outputDir: outputDir,
      contractName: contractName,
      useLogger: useLogger,
      useAutoGas: useAutoGas,
      useTransfers: useTransfers,
    );
  }
}
