import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../config/config.dart';
import 'debouncer.dart';

class AbiWatcher {
  final List<ContractConfig> contracts;
  final WatchConfig config;
  final Future<void> Function(String contractName, String abiPath)
  onFileChanged;
  final void Function(String error)? onError;
  final Map<String, StreamSubscription> _watchers = {};
  final Map<String, Debouncer> _debouncers = {};
  bool _isActive = false;

  AbiWatcher({
    required this.contracts,
    required this.config,
    required this.onFileChanged,
    this.onError,
  });

  Future<void> start() async {
    if (_isActive) {
      throw StateError('Watcher is already active');
    }

    _isActive = true;

    for (final contract in contracts) {
      await _watchContract(contract);
    }
  }

  Future<void> stop() async {
    if (!_isActive) return;
    _isActive = false;
    for (final subscription in _watchers.values) {
      await subscription.cancel();
    }
    _watchers.clear();
    for (final debouncer in _debouncers.values) {
      debouncer.dispose();
    }
    _debouncers.clear();
  }

  Future<void> _watchContract(ContractConfig contract) async {
    final abiFile = File(contract.abi);

    if (!await abiFile.exists()) {
      final error = 'ABI file not found: ${contract.abi}';
      onError?.call(error);
      return;
    }
    final debouncer = Debouncer(
      duration: Duration(milliseconds: config.debounceMs),
    );
    _debouncers[contract.name] = debouncer;
    final directory = abiFile.parent;
    final fileName = path.basename(abiFile.path);

    StreamSubscription? subscription;
    try {
      final watcher = directory.watch(events: FileSystemEvent.all);

      subscription = watcher.listen(
        (event) => _handleFileEvent(event, fileName, contract, debouncer),
        onError: (error) {
          final msg = 'Watch error for ${contract.name}: $error';
          onError?.call(msg);
        },
      );

      _watchers[contract.name] = subscription;
    } catch (e) {
      final error = 'Failed to watch ${contract.name}: $e';
      onError?.call(error);
      await subscription?.cancel();
    }
  }

  void _handleFileEvent(
    FileSystemEvent event,
    String targetFileName,
    ContractConfig contract,
    Debouncer debouncer,
  ) {
    final eventFileName = path.basename(event.path);
    if (eventFileName != targetFileName) return;

    if (_isExcluded(event.path)) return;

    if (config.verbose) {
      final eventType = switch (event.type) {
        FileSystemEvent.create => 'created',
        FileSystemEvent.modify => 'modified',
        FileSystemEvent.delete => 'deleted',
        FileSystemEvent.move => 'moved',
        _ => 'changed',
      };
      print('  File $eventType: ${event.path}');
    }

    debouncer(() async {
      if (!_isActive) return;

      try {
        await onFileChanged(contract.name, contract.abi);
      } catch (e) {
        final error = 'Error processing ${contract.name}: $e';
        onError?.call(error);
      }
    });
  }

  bool _isExcluded(String filePath) {
    final patterns = config.excludePatterns;
    if (patterns == null || patterns.isEmpty) return false;

    final fileName = path.basename(filePath);

    for (final pattern in patterns) {
      final regexPattern = pattern
          .replaceAll('.', r'\.')
          .replaceAll('*', '.*')
          .replaceAll('?', '.');

      if (RegExp('^$regexPattern\$').hasMatch(fileName)) {
        return true;
      }
    }

    return false;
  }
}
