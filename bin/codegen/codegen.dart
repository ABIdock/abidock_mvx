import 'dart:io';

import 'package:abidock_mvx/src/abi/abi.dart';

import 'core/name_sanitizer.dart';
import 'core/type_mapper.dart';
import 'generators/abi_generator.dart';
import 'generators/barrel_generator.dart';
import 'generators/calls_generator.dart';
import 'generators/controller_generator.dart';
import 'generators/event_models_generator.dart';
import 'generators/events_generator.dart';
import 'generators/models_generator.dart';
import 'generators/queries_generator.dart';
import 'generators/transfers_generator.dart';
import 'models/file_output.dart';
import 'models/generation_config.dart';
import 'models/generation_result.dart';
import 'utils/file_writer.dart';
import 'utils/keyword_sanitizer.dart';

class Codegen {
  final GenerationConfig config;

  Codegen(this.config);

  Future<GenerationResult> generate() async {
    final startTime = DateTime.now();
    final allFiles = <FileOutput>[];

    print('🚀 ABIcodegen');
    print('   ABI: ${config.abiPath}');
    print('   Output: ${config.outputDir}');
    print('   Contract: ${config.contractName}');
    print('');

    print('📖 Loading ABI...');
    final abi = await _loadAbi();
    print(
      '   ✓ ${abi.endpoints.length} endpoints, ${abi.types.length} types, ${abi.events.length} events',
    );
    print('');

    await _createDirs();

    return _generateV1(abi, startTime, allFiles);
  }

  Future<GenerationResult> _generateV1(
    SmartContractAbi abi,
    DateTime startTime,
    List<FileOutput> allFiles,
  ) async {
    final typeMapper = TypeMapper();
    final nameSanitizer = NameSanitizer();
    final keywordSanitizer = KeywordSanitizer();
    final writer = FileWriter();

    print('📦 Generating ABI...');
    final abiGen = AbiGenerator(abiPath: config.abiPath);
    final abiFiles = abiGen.generate();
    allFiles.addAll(abiFiles);
    for (final file in abiFiles) {
      writer.writeFileSync('${config.outputDir}/${file.path}', file.content);
    }
    print('   ✓ ${abiFiles.length} files');
    print('');

    if (abi.types.isNotEmpty) {
      print('🏗️  Generating models...');
      final modelsGen = ModelsGenerator(
        abi: abi,
        typeMapper: typeMapper,
        nameSanitizer: nameSanitizer,
        keywordSanitizer: keywordSanitizer,
      );
      final modelFiles = modelsGen.generate();
      allFiles.addAll(modelFiles);
      for (final file in modelFiles) {
        writer.writeFileSync('${config.outputDir}/${file.path}', file.content);
      }
      print('   ✓ ${modelFiles.length} files');
      print('');
    }

    if (abi.events.isNotEmpty) {
      print('🎨 Generating event models...');
      final eventModelsGen = EventModelsGenerator(
        abi: abi,
        typeMapper: typeMapper,
        nameSanitizer: nameSanitizer,
      );
      final eventModelFiles = eventModelsGen.generate();
      allFiles.addAll(eventModelFiles);
      for (final file in eventModelFiles) {
        writer.writeFileSync('${config.outputDir}/${file.path}', file.content);
      }
      print('   ✓ ${eventModelFiles.length} files');
      print('');
    }

    if (abi.endpoints.viewEndpoints.isNotEmpty) {
      print('🔍 Generating queries...');
      final queriesGen = QueriesGenerator(
        abi: abi,
        typeMapper: typeMapper,
        nameSanitizer: nameSanitizer,
      );
      final queryFiles = queriesGen.generate();
      allFiles.addAll(queryFiles);
      for (final file in queryFiles) {
        writer.writeFileSync('${config.outputDir}/${file.path}', file.content);
      }
      print('   ✓ ${queryFiles.length} files');
      print('');
    }

    if (abi.endpoints.mutableEndpoints.isNotEmpty) {
      print('📝 Generating calls...');
      final callsGen = CallsGenerator(
        abi: abi,
        typeMapper: typeMapper,
        nameSanitizer: nameSanitizer,
        useAutoGas: config.useAutoGas,
      );
      final callFiles = callsGen.generate();
      allFiles.addAll(callFiles);
      for (final file in callFiles) {
        writer.writeFileSync('${config.outputDir}/${file.path}', file.content);
      }
      print('   ✓ ${callFiles.length} files');
      print('');
    }

    if (abi.events.isNotEmpty) {
      print('📡 Generating events...');
      final eventsGen = EventsGenerator(
        abi: abi,
        typeMapper: typeMapper,
        nameSanitizer: nameSanitizer,
      );
      final eventFiles = eventsGen.generate();
      allFiles.addAll(eventFiles);
      for (final file in eventFiles) {
        writer.writeFileSync('${config.outputDir}/${file.path}', file.content);
      }
      print('   ✓ ${eventFiles.length} files');
      print('');
    }

    print('🎮 Generating controller...');
    final controllerGen = ControllerGenerator(
      abi: abi,
      nameSanitizer: nameSanitizer,
      typeMapper: typeMapper,
      contractName: config.contractName,
      useLogger: config.useLogger,
      useAutoGas: config.useAutoGas,
    );
    final controllerFiles = controllerGen.generate();
    allFiles.addAll(controllerFiles);
    for (final file in controllerFiles) {
      writer.writeFileSync('${config.outputDir}/${file.path}', file.content);
    }
    print('   ✓ ${controllerFiles.length} files');
    print('');

    if (config.useTransfers) {
      print('💸 Generating transfers...');
      final transfersGen = TransfersGenerator(nameSanitizer: nameSanitizer);
      final transferFiles = transfersGen.generate();
      allFiles.addAll(transferFiles);
      for (final file in transferFiles) {
        writer.writeFileSync('${config.outputDir}/${file.path}', file.content);
      }
      print('   ✓ ${transferFiles.length} files');
      print('');
    }

    if (config.generateBarrels) {
      print('📦 Generating barrel exports...');
      final barrelGen = BarrelGenerator(
        abi: abi,
        contractName: config.contractName,
        nameSanitizer: nameSanitizer,
        useTransfers: config.useTransfers,
      );
      final barrelFiles = barrelGen.generate();
      allFiles.addAll(barrelFiles);
      for (final file in barrelFiles) {
        writer.writeFileSync('${config.outputDir}/${file.path}', file.content);
      }
      print('   ✓ ${barrelFiles.length} files');
      print('');
    }

    final duration = DateTime.now().difference(startTime);
    print('✅ Generation complete!');
    print('   Files: ${allFiles.length}');
    print('   Lines: ${allFiles.fold<int>(0, (sum, f) => sum + f.lines)}');
    print('   Time: ${duration.inMilliseconds}ms');

    return GenerationResult(
      isSuccess: true,
      files: allFiles,
      duration: duration,
    );
  }

  Future<SmartContractAbi> _loadAbi() async {
    final file = File(config.abiPath);
    if (!file.existsSync()) {
      throw FileSystemException('ABI file not found', config.abiPath);
    }

    final content = await file.readAsString();
    return SmartContractAbi.fromJson(content);
  }

  Future<void> _createDirs() async {
    final dirs = [
      '${config.outputDir}/models',
      '${config.outputDir}/queries',
      '${config.outputDir}/calls',
      '${config.outputDir}/events/polling_events',
      '${config.outputDir}/events/websocket_events',
      if (config.useTransfers) '${config.outputDir}/transfers',
    ];

    for (final dir in dirs) {
      await Directory(dir).create(recursive: true);
    }
  }
}
