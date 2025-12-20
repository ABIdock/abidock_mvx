import 'dart:io';
import '../config/config.dart';
import '../config/config_loader.dart';

class InitCommand {
  Future<void> execute({
    String? configPath,
    String? contractName,
    String? abiPath,
    String? outputPath,
  }) async {
    final targetPath = configPath ?? 'abidock.yaml';

    print('Initializing abidock configuration...');
    print('');

    try {
      await ConfigLoader.createDefault(
        path: targetPath,
        contractName: contractName,
        abiPath: abiPath,
        outputPath: outputPath,
      );

      print('✅ Created config file: $targetPath');
      print('');
      print('Next steps:');
      print('  1. Edit $targetPath to configure your contracts');
      print('  2. Run: abidock generate');
      print('  3. Or run: abidock watch (for auto-regeneration)');
      print('');
    } on ConfigException catch (e) {
      print('❌ Error: ${e.message}');
      exit(1);
    } catch (e) {
      print('❌ Unexpected error: $e');
      exit(1);
    }
  }
}
