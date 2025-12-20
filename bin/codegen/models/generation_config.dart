class GenerationConfig {
  final String abiPath;
  final String outputDir;
  final String contractName;
  final bool generateBarrels;
  final bool formatCode;
  final bool useLogger;
  final bool useAutoGas;
  final bool useTransfers;

  const GenerationConfig({
    required this.abiPath,
    required this.outputDir,
    required this.contractName,
    this.generateBarrels = true,
    this.formatCode = true,
    this.useLogger = false,
    this.useAutoGas = false,
    this.useTransfers = false,
  });
}
