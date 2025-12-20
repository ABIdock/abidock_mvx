/// Type formula parser for smart contract ABI types.
import 'package:meta/meta.dart';

import '../../utils/sdk_exceptions.dart';
import 'type_formula.dart';

/// Creates error for unexpected character.
///
/// #### Parameters
/// - `char` - Unexpected character
/// - `position` - Position in input string
AbiTypeFormulaParseException unexpectedCharacterException(
  String char,
  int position,
) {
  return AbiTypeFormulaParseException(
    'Unexpected character "$char" at position $position',
    formula: char,
  );
}

/// Creates error for unexpected end of input.
AbiTypeFormulaParseException unexpectedEndException() {
  return const AbiTypeFormulaParseException('Unexpected end of input');
}

/// Creates error for mismatched brackets.
AbiTypeFormulaParseException mismatchedBracketsException() {
  return const AbiTypeFormulaParseException('Mismatched angle brackets < >');
}

/// Creates error for empty type name.
AbiTypeFormulaParseException emptyTypeNameException() {
  return const AbiTypeFormulaParseException('Type name cannot be empty');
}

/// Token types for type formula lexical analysis.
enum TokenType {
  /// Type name identifier.
  identifier,

  /// Left angle bracket <.
  leftAngle,

  /// Right angle bracket >.
  rightAngle,

  /// Comma separator.
  comma,

  /// End of input.
  eof,
}

/// Token representing lexical element in type formula.
///
/// Used internally by lexer and parser.
@immutable
class Token {
  /// Creates token with type, value, and position.
  ///
  /// #### Parameters
  /// - `type` - Token type (identifier, leftAngle, rightAngle, comma, eof)
  /// - `value` - Token text (for identifiers)
  /// - `position` - Character position in input
  const Token({
    required this.type,
    required this.value,
    required this.position,
  });

  /// Token type.
  final TokenType type;

  /// Token value (for identifiers).
  final String value;

  /// Position in input string.
  final int position;

  @override
  String toString() => 'Token($type, "$value", $position)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Token &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          value == other.value &&
          position == other.position;

  @override
  int get hashCode => Object.hash(type, value, position);
}

/// Lexical analyzer for type formula strings.
class TypeFormulaLexer {
  /// Creates lexer for input string.
  ///
  /// #### Parameters
  /// - `_input` - Type formula string to tokenize
  TypeFormulaLexer(this._input);
  final String _input;
  int _position = 0;

  /// Current character at position (null if at end).
  String? get _currentChar =>
      _position < _input.length ? _input[_position] : null;

  /// Advances to next character.
  void _advance() => _position++;

  /// Skips whitespace characters.
  void _skipWhitespace() {
    while (_currentChar != null && _currentChar!.trim().isEmpty) {
      _advance();
    }
  }

  /// Reads identifier token (type name).
  Token _readIdentifier() {
    final int start = _position;
    final StringBuffer buffer = StringBuffer();

    while (_currentChar != null &&
        (_currentChar!.contains(RegExp(r'[a-zA-Z0-9_]')))) {
      buffer.write(_currentChar);
      _advance();
    }

    final String value = buffer.toString();
    if (value.isEmpty) {
      throw emptyTypeNameException();
    }

    return Token(type: TokenType.identifier, value: value, position: start);
  }

  /// Gets next token from input.
  ///
  /// #### Returns
  /// `Token` - Next token or EOF token at end
  ///
  /// #### Throws
  /// - `AbiTypeFormulaParseException` - Unexpected character or empty type name
  Token nextToken() {
    _skipWhitespace();

    if (_currentChar == null) {
      return Token(type: TokenType.eof, value: '', position: _position);
    }

    final String char = _currentChar!;
    final int position = _position;

    switch (char) {
      case '<':
        _advance();
        return Token(
          type: TokenType.leftAngle,
          value: char,
          position: position,
        );

      case '>':
        _advance();
        return Token(
          type: TokenType.rightAngle,
          value: char,
          position: position,
        );

      case ',':
        _advance();
        return Token(type: TokenType.comma, value: char, position: position);

      default:
        if (char.contains(RegExp(r'[a-zA-Z_]'))) {
          return _readIdentifier();
        } else {
          throw unexpectedCharacterException(char, position);
        }
    }
  }

  /// Tokenizes entire input string.
  ///
  /// #### Returns
  /// `List<Token>` - List of all tokens including EOF
  List<Token> tokenize() {
    final List<Token> tokens = <Token>[];
    Token token;

    do {
      token = nextToken();
      tokens.add(token);
    } while (token.type != TokenType.eof);

    return tokens;
  }
}

/// Parser for type formula expressions using recursive descent.
class TypeFormulaParser {
  /// Creates parser for given tokens.
  ///
  /// #### Parameters
  /// - `_tokens` - Token list from lexer
  TypeFormulaParser(this._tokens);
  final List<Token> _tokens;
  int _position = 0;
  Token get _currentToken =>
      _position < _tokens.length ? _tokens[_position] : _tokens.last;
  void _advance() {
    if (_position < _tokens.length - 1) {
      _position++;
    }
  }

  void _expect(TokenType expectedType) {
    if (_currentToken.type != expectedType) {
      throw AbiTypeFormulaParseException(
        'Expected $expectedType but found ${_currentToken.type} '
        'at position ${_currentToken.position}',
      );
    }
    _advance();
  }

  List<TypeFormula> _parseTypeParameters() {
    _expect(TokenType.leftAngle);

    final List<TypeFormula> parameters = <TypeFormula>[];

    if (_currentToken.type == TokenType.rightAngle) {
      _advance();
      return parameters;
    }

    parameters.add(_parseTypeFormula());

    while (_currentToken.type == TokenType.comma) {
      _advance();
      parameters.add(_parseTypeFormula());
    }

    _expect(TokenType.rightAngle);
    return parameters;
  }

  TypeFormula _parseTypeFormula() {
    if (_currentToken.type != TokenType.identifier) {
      throw AbiTypeFormulaParseException(
        'Expected type name but found ${_currentToken.type} '
        'at position ${_currentToken.position}',
      );
    }

    final String typeName = _currentToken.value;
    _advance();

    List<TypeFormula> typeParameters = <TypeFormula>[];

    if (_currentToken.type == TokenType.leftAngle) {
      typeParameters = _parseTypeParameters();
    }

    return TypeFormula(name: typeName, typeParameters: typeParameters);
  }

  /// Parses token stream into TypeFormula.
  ///
  /// #### Returns
  /// `TypeFormula` - Parsed type formula
  ///
  /// #### Throws
  /// - `AbiTypeFormulaParseException` - Empty input or unexpected tokens
  TypeFormula parse() {
    if (_tokens.isEmpty || _tokens.first.type == TokenType.eof) {
      throw const AbiTypeFormulaParseException('Empty input');
    }

    final TypeFormula result = _parseTypeFormula();

    if (_currentToken.type != TokenType.eof) {
      throw AbiTypeFormulaParseException(
        'Unexpected token after type formula: ${_currentToken.type} '
        'at position ${_currentToken.position}',
      );
    }

    return result;
  }

  /// Parses type formula string directly.
  ///
  /// #### Parameters
  /// - `input` - Type formula string (e.g., "Option<Address>")
  ///
  /// #### Returns
  /// `TypeFormula` - Parsed type formula
  ///
  /// #### Throws
  /// - `AbiTypeFormulaParseException` - Empty input or parsing errors
  static TypeFormula parseString(String input) {
    if (input.trim().isEmpty) {
      throw const AbiTypeFormulaParseException('Type formula cannot be empty');
    }

    if (!validateBrackets(input)) {
      throw const AbiTypeFormulaParseException(
        'Unbalanced angle brackets in type formula',
      );
    }

    try {
      final TypeFormulaLexer lexer = TypeFormulaLexer(input.trim());
      final List<Token> tokens = lexer.tokenize();
      final TypeFormulaParser parser = TypeFormulaParser(tokens);
      return parser.parse();
    } on AbiTypeFormulaParseException {
      rethrow;
    } catch (e) {
      throw AbiTypeFormulaParseException(
        'Failed to parse type formula "$input": $e',
      );
    }
  }

  /// Validates that brackets are properly matched.
  static bool validateBrackets(String input) {
    int depth = 0;

    for (int i = 0; i < input.length; i++) {
      switch (input[i]) {
        case '<':
          depth++;
          break;
        case '>':
          depth--;
          if (depth < 0) return false;
          break;
      }
    }

    return depth == 0;
  }
}
