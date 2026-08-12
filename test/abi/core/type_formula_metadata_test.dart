/// Regression test for CR3-2: `TypeFormulaParser.parseString` must correctly
/// peel off a trailing `*metadata*` segment from ABI type names such as
/// `ManagedDecimal<usize>*N*` and `ManagedDecimal<8>*8*`.
///
/// The round-3 audit briefly flagged this as broken because the LEXER alone
/// did not stop at `*`. In fact `parseString` strips the trailing `*meta*`
/// via `_splitMetadata` BEFORE tokenising, so well-formed inputs round-trip
/// correctly. This pinning test exists so a future refactor cannot quietly
/// drop the metadata stripping step.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group(
    'TypeFormulaParser.parseString trailing *metadata* (CR3-2 pinning)',
    () {
      test('ManagedDecimal<usize>*N* parses with metadata captured', () {
        final TypeFormula formula = TypeFormulaParser.parseString(
          'ManagedDecimal<usize>*N*',
        );
        expect(formula.name, equals('ManagedDecimal'));
        expect(formula.typeParameters, hasLength(1));
        expect(formula.typeParameters.single.name, equals('usize'));
        expect(formula.metadata, equals('N'));
      });

      test('ManagedDecimal<8>*8* (fixed-scale shorthand) parses', () {
        final TypeFormula formula = TypeFormulaParser.parseString(
          'ManagedDecimal<8>*8*',
        );
        expect(formula.name, equals('ManagedDecimal'));
        expect(formula.typeParameters, hasLength(1));
        expect(formula.typeParameters.single.name, equals('8'));
        expect(formula.metadata, equals('8'));
      });

      test('parse → toString → parse is a stable round-trip', () {
        const String input = 'ManagedDecimal<usize>*N*';
        final TypeFormula first = TypeFormulaParser.parseString(input);
        final TypeFormula second = TypeFormulaParser.parseString(
          first.toString(),
        );
        expect(second.name, equals(first.name));
        expect(second.metadata, equals(first.metadata));
        expect(
          second.typeParameters.length,
          equals(first.typeParameters.length),
        );
      });

      test(
        'Plain types without metadata still parse and yield null metadata',
        () {
          final TypeFormula formula = TypeFormulaParser.parseString(
            'Option<u32>',
          );
          expect(formula.name, equals('Option'));
          expect(formula.metadata, isNull);
        },
      );

      test('Unterminated *metadata* throws AbiTypeFormulaParseException', () {
        expect(
          () => TypeFormulaParser.parseString('ManagedDecimal<usize>*N'),
          throwsA(isA<AbiTypeFormulaParseException>()),
        );
      });
    },
  );
}
