/// Regression test for audit H3-2.
///
/// Ensures the generated controller field is typed as the abstract
/// [Logger] interface, not the concrete `ConsoleLogger`. Without this,
/// passing a `NullLogger` or `FileLogger` into [SmartContractController]
/// would crash with a `TypeError` on assignment to the generated field.
library;

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../../bin/codegen/core/name_sanitizer.dart';
import '../../bin/codegen/core/type_mapper.dart';
import '../../bin/codegen/generators/controller_generator.dart';

void main() {
  group('ControllerGenerator / logger field typing (H3-2)', () {
    /// Minimal ABI with one endpoint and no events — enough to exercise
    /// the controller-class emission path with `useLogger: true`.
    const String minimalAbiJson = '''
    {
      "name": "MinimalLoggerProbe",
      "endpoints": [
        {
          "name": "ping",
          "mutability": "readonly",
          "inputs": [],
          "outputs": [{"type": "u32"}]
        }
      ],
      "events": [],
      "types": {}
    }
    ''';

    /// Helper that runs the generator with `useLogger: true` and returns
    /// the single emitted `controller.dart` source string.
    String runGenerator() {
      final SmartContractAbi abi = SmartContractAbi.fromJson(minimalAbiJson);
      final ControllerGenerator generator = ControllerGenerator(
        abi: abi,
        nameSanitizer: NameSanitizer(),
        typeMapper: TypeMapper(),
        contractName: 'minimal_logger_probe',
        useLogger: true,
      );
      final List<dynamic> outputs = generator.generate();
      expect(outputs, hasLength(1));
      return outputs.single.content as String;
    }

    test('emits `final Logger logger` not `final ConsoleLogger logger`', () {
      final String source = runGenerator();

      expect(
        source,
        contains('final Logger logger;'),
        reason:
            'Controller field must be the abstract Logger interface so any '
            'Logger subtype (NullLogger, FileLogger, ConsoleLogger) flows '
            'through without an implicit downcast crash.',
      );
      expect(
        source.contains('final ConsoleLogger logger'),
        isFalse,
        reason:
            'Field must NOT be typed as the concrete ConsoleLogger — that '
            'would force an implicit downcast when other Logger subtypes '
            'are supplied (audit H3-2).',
      );
    });

    test('withController factory does not cast logger to ConsoleLogger', () {
      final String source = runGenerator();

      /// The `.withController` body must not contain `as ConsoleLogger`
      /// because `_controller.logger` is typed as `Logger?` and casting
      /// any non-ConsoleLogger subtype would throw at runtime.
      expect(
        source.contains('as ConsoleLogger'),
        isFalse,
        reason:
            'Generated code must never downcast Logger to ConsoleLogger; '
            'subclasses such as NullLogger or FileLogger would crash with '
            'a TypeError (audit H3-2).',
      );
    });

    test('logger constructor parameter accepts abstract Logger', () {
      final String source = runGenerator();

      expect(
        source,
        contains('Logger? logger,'),
        reason:
            'Public constructor must accept any Logger subtype, not only '
            'ConsoleLogger.',
      );
    });
  });
}
