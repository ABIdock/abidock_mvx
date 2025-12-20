import 'package:abidock_mvx/src/abi/abi.dart';
import '../core/name_sanitizer.dart';
import '../models/file_output.dart';
import 'generator_base.dart';

class BarrelGenerator extends GeneratorBase {
  final SmartContractAbi abi;
  final String contractName;
  final NameSanitizer nameSanitizer;
  final bool useTransfers;

  BarrelGenerator({
    required this.abi,
    required this.contractName,
    required this.nameSanitizer,
    this.useTransfers = false,
  });

  @override
  List<FileOutput> generate() {
    final buffer = StringBuffer();
    buffer.write(getGeneratedFileHeader());
    final filename = '${nameSanitizer.toSnakeCase(contractName)}.dart';

    final exports = <String>[];

    exports.add('export \'abi.dart\';');
    exports.add('export \'controller.dart\';');

    final eventModelNames = <String>{};
    if (abi.events.isNotEmpty) {
      for (final event in abi.events) {
        String normalized = event.identifier;
        if (normalized.endsWith('_event')) {
          normalized = normalized.substring(0, normalized.length - 6);
        }
        final eventModelName = '${nameSanitizer.toPascalCase(normalized)}Event';
        eventModelNames.add(eventModelName);
      }
    }

    if (abi.types.isNotEmpty) {
      for (final type in abi.types.values) {
        if (eventModelNames.contains(type.name)) {
          continue;
        }
        final name = nameSanitizer.toSnakeCase(type.name);
        exports.add('export \'models/$name.dart\';');
      }
    }

    if (abi.endpoints.viewEndpoints.isNotEmpty) {
      for (final endpoint in abi.endpoints.viewEndpoints) {
        final name = nameSanitizer.toSnakeCase(endpoint.name);
        exports.add('export \'queries/$name.dart\';');
      }
    }

    if (abi.endpoints.mutableEndpoints.isNotEmpty) {
      for (final endpoint in abi.endpoints.mutableEndpoints) {
        final name = nameSanitizer.toSnakeCase(endpoint.name);
        exports.add('export \'calls/$name.dart\';');
      }
    }

    if (abi.events.isNotEmpty) {
      for (final event in abi.events) {
        String normalized = event.identifier;
        if (normalized.endsWith('_event')) {
          normalized = normalized.substring(0, normalized.length - 6);
        }
        final name = '${nameSanitizer.toSnakeCase(normalized)}_event';
        exports.add('export \'models/$name.dart\';');
      }

      for (final event in abi.events) {
        final name = nameSanitizer.toSnakeCase(event.identifier);
        exports.add('export \'events/polling_events/$name.dart\';');
      }

      for (final event in abi.events) {
        final name = nameSanitizer.toSnakeCase(event.identifier);
        exports.add('export \'events/websocket_events/$name.dart\';');
      }
    }

    if (useTransfers) {
      exports.add('export \'transfer_service.dart\';');
      exports.add('export \'transfers/egld_transfer.dart\';');
      exports.add('export \'transfers/esdt_transfer.dart\';');
      exports.add('export \'transfers/multi_transfer.dart\';');
      exports.add('export \'transfers/nft_transfer.dart\';');
    }

    exports.sort();

    for (final export in exports) {
      buffer.writeln(export);
    }

    return [FileOutput(path: filename, content: buffer.toString())];
  }
}
