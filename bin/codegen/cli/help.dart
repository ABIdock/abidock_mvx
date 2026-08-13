/// Help page for the `abidock` executable and the argument forms that ask
/// for it.
library;

/// Flags that request the help page, accepted in any argument position.
const Set<String> _helpFlags = <String>{'--help', '-h'};

/// The bare command that requests the help page.
const String _helpCommand = 'help';

/// The complete help page, shared by every help invocation.
const String abidockHelpText = '''
ABIdock - MultiversX Smart Contract Code Generator

Commands:
  init        Create a new abidock.yaml config file
  generate    Generate code from ABIs
  validate    Validate ABI files
  watch       Watch ABIs and auto-regenerate
  help        Show this help message (also: --help, -h, or no arguments)

Init Command:
  abidock init [options]
    --config, -c <path>    Output config file path (default: abidock.yaml)
    --name <name>          Initial contract name
    --abi <path>           Initial ABI file path
    --output-dir <path>    Initial output directory

Generate Command:
  abidock generate [options]
  abidock generate <abi> <output> <name> [flags]
    --config, -c <path>    Config file path
    --logger               Auto-inject ConsoleLogger
    --autogas              Generate auto gas estimation methods (via simulation)
    --transfers            Generate transfer controller
    --full                 Enable ALL features (logger + autogas + transfers)

Validate Command:
  abidock validate [options]
    --config, -c <path>    Config file path
    --abi <path>           ABI file to validate
    --name <name>          Contract name (required with --abi)
    --verbose, -v          Show detailed validation info
    --json                 Output results as JSON
    --fail-on-warnings     Treat warnings as errors

Watch Command:
  abidock watch [options]
    --config, -c <path>    Config file path
    --skip-initial         Skip initial generation on start

Legacy Mode (still fully supported):
  abidock <abi_file> <output_dir> <contract_name> [flags]
  abidock --interactive

Examples:
  # Initialize config
  abidock init
  abidock init --name MyContract --abi assets/my.abi.json

  # Generate from config
  abidock generate
  abidock generate -c custom.yaml

  # Generate single contract
  abidock generate assets/pair.abi.json lib/generated pair --full

  # Validate ABIs
  abidock validate
  abidock validate --verbose
  abidock validate --abi assets/pair.abi.json --name Pair

  # Watch mode (auto-regenerate on ABI changes)
  abidock watch
  abidock watch --skip-initial

  # Interactive mode
  abidock --interactive
''';

/// Reports whether the given command line asks for the help page.
///
/// Help is requested by an empty command line, by `help` as the first
/// argument, or by `--help` / `-h` in any position, so that
/// `abidock generate --help` documents the tool instead of running a
/// generation pass. Matching is case-insensitive.
///
/// #### Parameters
/// - `args` - Raw command-line arguments, as handed to `main`
///
/// #### Returns
/// `bool` - True when the help page should be printed
///
/// #### Example
/// ```dart
/// if (isHelpInvocation(args)) {
///   printHelp();
///   exit(0);
/// }
/// ```
bool isHelpInvocation(List<String> args) {
  if (args.isEmpty) {
    return true;
  }

  if (args.first.toLowerCase() == _helpCommand) {
    return true;
  }

  return args.any((String arg) => _helpFlags.contains(arg.toLowerCase()));
}

/// Prints the help page to stdout.
void printHelp() {
  print(abidockHelpText);
}
