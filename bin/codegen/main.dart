import 'dart:io';

import 'codegen.dart';
import 'interactive/interactive_cli.dart';
import 'models/generation_config.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--interactive')) {
    print('');
    final cli = InteractiveCLI();
    final config = await cli.run();

    if (config == null) {
      print('');
      print('ℹ️ Interactive mode cancelled');
      exit(0);
    }

    try {
      print('');
      print('🚀 Starting code generation...');
      print('');

      final genConfig = GenerationConfig(
        abiPath: config.abiPath,
        outputDir: config.outputDir,
        contractName: config.contractName,
        useLogger: config.useLogger,
        useAutoGas: config.useAutoGas,
        useTransfers: config.useTransfers,
      );

      final codegen = Codegen(genConfig);
      final result = await codegen.generate();

      if (result.isSuccess) {
        cli.showSummary(
          filesGenerated: result.files.length,
          linesGenerated: result.files.fold<int>(0, (sum, f) => sum + f.lines),
          timeMs: result.duration.inMilliseconds,
          outputDir: config.outputDir,
        );
      }

      exit(0);
    } catch (e, stackTrace) {
      print('❌ Error: $e');
      print('');
      print('Stack trace:');
      print(stackTrace);
      exit(1);
    }
  }

  final positionalArgs = args.where((arg) => !arg.startsWith('--')).toList();

  if (positionalArgs.length < 3) {
    print(
      'Usage: abidock <abi_file> <output_dir> <contract_name> [--logger] [--autogas] [--transfers] [--full]',
    );
    print('   Or: abidock --interactive');
    print('');
    print('Flags:');
    print('  --logger    Auto-inject ConsoleLogger in generated controller');
    print(
      '  --autogas   Generate auto gas estimation methods (via simulation)',
    );
    print('  --transfers Generate transfer controller for EGLD/ESDT/NFT');
    print('  --full      Enable ALL features (logger + autogas + transfers)');
    print('');
    print('Examples:');
    print('  abidock assets/pair.abi.json output/pair pair --full');
    print('  abidock assets/pair.abi.json output/pair pair --logger');
    print('  abidock --interactive');
    exit(1);
  }

  final abiPath = positionalArgs[0];
  final outputDir = positionalArgs[1];
  final contractName = positionalArgs[2];

  final useFull = args.contains('--full');
  final useLogger = useFull || args.contains('--logger');
  final useAutoGas = useFull || args.contains('--autogas');
  final useTransfers = useFull || args.contains('--transfers');

  try {
    final config = GenerationConfig(
      abiPath: abiPath,
      outputDir: outputDir,
      contractName: contractName,
      useLogger: useLogger,
      useAutoGas: useAutoGas,
      useTransfers: useTransfers,
    );

    final codegen = Codegen(config);
    await codegen.generate();

    exit(0);
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('');
    print('Stack trace:');
    print(stackTrace);
    exit(1);
  }
}
