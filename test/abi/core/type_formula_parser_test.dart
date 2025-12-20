import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('TypeFormulaLexer', () {
    test('tokenizes primitive type', () {
      final lexer = TypeFormulaLexer('u32');
      final tokens = lexer.tokenize();

      expect(tokens.length, 2);
      expect(tokens[0].type, TokenType.identifier);
      expect(tokens[0].value, 'u32');
      expect(tokens[1].type, TokenType.eof);
    });

    test('tokenizes generic type', () {
      final lexer = TypeFormulaLexer('Option<u32>');
      final tokens = lexer.tokenize();

      expect(tokens.length, 5);
      expect(tokens[0].value, 'Option');
      expect(tokens[1].type, TokenType.leftAngle);
      expect(tokens[2].value, 'u32');
      expect(tokens[3].type, TokenType.rightAngle);
      expect(tokens[4].type, TokenType.eof);
    });
  });

  group('TypeFormulaParser', () {
    test('parses primitive type', () {
      final formula = TypeFormulaParser.parseString('u32');

      expect(formula.name, 'u32');
      expect(formula.isPrimitive, true);
      expect(formula.typeParameters.isEmpty, true);
    });

    test('parses generic type', () {
      final formula = TypeFormulaParser.parseString('Option<u32>');

      expect(formula.name, 'Option');
      expect(formula.isPrimitive, false);
      expect(formula.typeParameters.length, 1);
      expect(formula.typeParameters.first.name, 'u32');
    });

    test('parses nested generic type', () {
      final formula = TypeFormulaParser.parseString('List<Option<u32>>');

      expect(formula.name, 'List');
      expect(formula.typeParameters.length, 1);
      expect(formula.typeParameters.first.name, 'Option');
      expect(formula.typeParameters.first.typeParameters.length, 1);
      expect(formula.typeParameters.first.typeParameters.first.name, 'u32');
    });

    test('parses multiple type parameters', () {
      final formula = TypeFormulaParser.parseString('Tuple<u32,Address>');

      expect(formula.name, 'Tuple');
      expect(formula.typeParameters.length, 2);
      expect(formula.typeParameters[0].name, 'u32');
      expect(formula.typeParameters[1].name, 'Address');
    });

    test('handles whitespace', () {
      final formula = TypeFormulaParser.parseString('  Option < u32 >  ');

      expect(formula.name, 'Option');
      expect(formula.typeParameters.length, 1);
      expect(formula.typeParameters.first.name, 'u32');
    });

    test('throws on invalid syntax', () {
      expect(() => TypeFormulaParser.parseString(''), throwsException);
    });
  });
}
