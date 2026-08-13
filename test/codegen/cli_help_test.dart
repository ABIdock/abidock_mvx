/// Regression tests for the `abidock` help path.
///
/// The entrypoint used to dispatch commands only when the first argument did
/// not start with `-`, while `--help` and `-h` were listed as cases *inside*
/// that guarded switch. Both flags were therefore unreachable and fell through
/// to the legacy generator, which printed the terse legacy usage and exited
/// with status 1; a bare `abidock` did the same. Only `abidock help` ever
/// reached the help page.
///
/// These tests pin all four documented forms — `help`, `--help`, `-h` and no
/// arguments — to the same help page and to exit status 0, both at the
/// argument-classification level and end to end through the real executable.
library;

import 'dart:io';

import 'package:test/test.dart';

import '../../bin/codegen/cli/help.dart';

/// First line of the help page.
const String _helpBanner = 'ABIdock - MultiversX Smart Contract Code Generator';

/// Lines that must appear verbatim on the help page.
const List<String> _helpLines = <String>[
  '  init        Create a new abidock.yaml config file',
  '  generate    Generate code from ABIs',
  '  validate    Validate ABI files',
  '  watch       Watch ABIs and auto-regenerate',
  '  help        Show this help message (also: --help, -h, or no arguments)',
  'Init Command:',
  'Generate Command:',
  'Validate Command:',
  'Watch Command:',
  'Legacy Mode (still fully supported):',
];

void main() {
  group('isHelpInvocation', () {
    test('accepts every documented help form', () {
      expect(isHelpInvocation(<String>[]), isTrue);
      expect(isHelpInvocation(<String>['help']), isTrue);
      expect(isHelpInvocation(<String>['--help']), isTrue);
      expect(isHelpInvocation(<String>['-h']), isTrue);
    });

    test('accepts help forms case-insensitively', () {
      expect(isHelpInvocation(<String>['HELP']), isTrue);
      expect(isHelpInvocation(<String>['--HELP']), isTrue);
      expect(isHelpInvocation(<String>['-H']), isTrue);
    });

    test('accepts a help flag after a command', () {
      expect(isHelpInvocation(<String>['generate', '--help']), isTrue);
      expect(isHelpInvocation(<String>['validate', '-h']), isTrue);
    });

    test('leaves real commands alone', () {
      expect(isHelpInvocation(<String>['init']), isFalse);
      expect(isHelpInvocation(<String>['generate']), isFalse);
      expect(
        isHelpInvocation(<String>['validate', '--abi', 'a.json']),
        isFalse,
      );
      expect(isHelpInvocation(<String>['watch', '--skip-initial']), isFalse);
      expect(isHelpInvocation(<String>['--interactive']), isFalse);
      expect(
        isHelpInvocation(<String>['a.abi.json', 'out', 'pair', '--full']),
        isFalse,
      );
    });
  });

  group('abidockHelpText', () {
    test('starts with the banner', () {
      expect(abidockHelpText.split('\n').first, _helpBanner);
    });

    test('documents every command', () {
      for (final String line in _helpLines) {
        expect(abidockHelpText, contains(line));
      }
    });
  });

  group('abidock executable', timeout: const Timeout(Duration(minutes: 5)), () {
    late Directory workDir;
    late String snapshotPath;

    /// Runs the compiled entrypoint with [args] and returns its result.
    Future<ProcessResult> runCli(List<String> args) {
      return Process.run(Platform.resolvedExecutable, <String>[
        snapshotPath,
        ...args,
      ], workingDirectory: Directory.current.path);
    }

    setUpAll(() async {
      workDir = Directory.systemTemp.createTempSync('abidock_cli_help');
      snapshotPath = '${workDir.path}${Platform.pathSeparator}abidock.dill';

      final ProcessResult compiled = await Process.run(
        Platform.resolvedExecutable,
        <String>['compile', 'kernel', 'bin/abidock.dart', '-o', snapshotPath],
        workingDirectory: Directory.current.path,
      );

      expect(compiled.exitCode, 0, reason: compiled.stderr.toString());
    });

    tearDownAll(() {
      if (workDir.existsSync()) {
        workDir.deleteSync(recursive: true);
      }
    });

    for (final List<String> args in <List<String>>[
      <String>[],
      <String>['help'],
      <String>['--help'],
      <String>['-h'],
    ]) {
      final String label = args.isEmpty ? '(no arguments)' : args.join(' ');

      test('prints help and exits 0 for $label', () async {
        final ProcessResult result = await runCli(args);
        final String stdout = (result.stdout as String).replaceAll(
          '\r\n',
          '\n',
        );

        expect(result.exitCode, 0);
        expect(stdout.split('\n').first, _helpBanner);
        for (final String line in _helpLines) {
          expect(stdout, contains(line));
        }
      });
    }

    test('still reports usage and exits 1 for an incomplete legacy '
        'invocation', () async {
      final ProcessResult result = await runCli(<String>['--logger']);
      final String stdout = (result.stdout as String).replaceAll('\r\n', '\n');

      expect(result.exitCode, 1);
      expect(stdout, isNot(contains(_helpBanner)));
      expect(
        stdout.split('\n').first,
        'Usage: abidock <abi_file> <output_dir> <contract_name> '
        '[--logger] [--autogas] [--transfers] [--full]',
      );
    });
  });
}
