/// Regression tests for which generation source `abidock generate` selects.
///
/// The command used to test for a config file before looking at its positional
/// arguments, so the mere presence of an `abidock.yaml` in the working
/// directory made `abidock generate <abi> <output> <name>` regenerate whatever
/// the config named and discard all three arguments without a word. Explicit
/// arguments now win over a config discovered in the working directory.
library;

import 'dart:io';

import 'package:test/test.dart';

/// Absolute path of the package root, so the child process can run the CLI
/// while its working directory is the temporary fixture directory.
final String _packageRoot = Directory.current.path;

/// A contract ABI small enough to generate quickly.
final String _abiSource = '$_packageRoot/example/cookbook/pair.abi.json';

ProcessResult _runAbidock(List<String> args, String workingDirectory) {
  return Process.runSync('dart', <String>[
    'run',
    '$_packageRoot/bin/abidock.dart',
    ...args,
  ], workingDirectory: workingDirectory);
}

void main() {
  late Directory fixture;

  setUp(() {
    fixture = Directory.systemTemp.createTempSync('abidock_precedence');
    File(_abiSource).copySync('${fixture.path}/pair.abi.json');
    File('${fixture.path}/abidock.yaml').writeAsStringSync('''
version: 1

contracts:
  - name: FromConfig
    abi: pair.abi.json
    output: out_config
''');
  });

  tearDown(() {
    if (fixture.existsSync()) {
      fixture.deleteSync(recursive: true);
    }
  });

  group('abidock generate source precedence', () {
    test('positional arguments win over a discovered config file', () {
      final ProcessResult result = _runAbidock(<String>[
        'generate',
        'pair.abi.json',
        'out_positional',
        'MyPair',
      ], fixture.path);

      expect(result.exitCode, equals(0));
      expect(
        Directory('${fixture.path}/out_positional').existsSync(),
        isTrue,
        reason: 'the requested output directory must be generated',
      );
      expect(
        Directory('${fixture.path}/out_config').existsSync(),
        isFalse,
        reason: 'the config target must not be generated instead',
      );
    });

    test('the discovered config is used when no arguments are given', () {
      final ProcessResult result = _runAbidock(<String>[
        'generate',
      ], fixture.path);

      expect(result.exitCode, equals(0));
      expect(Directory('${fixture.path}/out_config').existsSync(), isTrue);
      expect(Directory('${fixture.path}/out_positional').existsSync(), isFalse);
    });
  });
}
