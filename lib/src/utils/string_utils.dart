/// String utility functions for text comparison and manipulation.

/// Static utility class for string operations.
///
/// Provides methods for string comparison and manipulation.
class StringUtils {
  /// Private constructor to prevent instantiation.
  StringUtils._();

  /// Calculates the Levenshtein distance between two strings.
  ///
  /// The Levenshtein distance is the minimum number of single-character edits
  /// (insertions, deletions, or substitutions) required to change one string
  /// into another.
  ///
  /// #### Parameters
  /// - `s1` - First string to compare
  /// - `s2` - Second string to compare
  ///
  /// #### Returns
  /// `int` - The edit distance (0 means strings are identical)
  ///
  /// #### Example
  /// ```dart
  /// StringUtils.levenshteinDistance('kitten', 'sitting'); // 3
  /// StringUtils.levenshteinDistance('hello', 'hello'); // 0
  /// StringUtils.levenshteinDistance('', 'abc'); // 3
  /// ```
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final int len1 = s1.length;
    final int len2 = s2.length;
    final List<List<int>> matrix = List<List<int>>.generate(
      len1 + 1,
      (int i) => List<int>.filled(len2 + 1, 0),
    );

    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = <int>[
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((int a, int b) => a < b ? a : b);
      }
    }

    return matrix[len1][len2];
  }
}
