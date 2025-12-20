/// PEM entry representation for wallet export with label and key data.
/// Used for creating wallet backup files in standard PEM format.
import 'dart:convert';
import 'dart:typed_data';

import '../utils/hex_utils.dart';

/// PEM entry with label and key data for import and export.
///
/// #### Example
/// ```dart
/// final entry = PemEntry(
///   label: 'erd1...',
///   message: keyBytes,
/// );
///
/// // Export to PEM text
/// final pemText = entry.toText();
/// ```
class PemEntry {
  /// Creates PEM entry.
  ///
  /// #### Parameters
  /// - `label` - Address label (typically bech32 address)
  /// - `message` - Key data bytes
  ///
  /// #### Example
  /// ```dart
  /// final entry = PemEntry(
  ///   label: 'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  ///   message: secretKeyBytes,
  /// );
  /// ```
  const PemEntry({required this.label, required this.message});
  final String label;
  final Uint8List message;

  /// Parses all PEM entries from text.
  ///
  /// #### Parameters
  /// - `pemText` - PEM file content with one or more key entries
  ///
  /// #### Returns
  /// `List<PemEntry>` - All PEM entries found in text
  ///
  /// #### Throws
  /// - `FormatException` - If PEM format is invalid
  ///
  /// #### Example
  /// ```dart
  /// final pemContent = '''
  /// -----BEGIN PRIVATE KEY for erd1qyu5...-----
  /// NWY5ODJlYzJhNTcyMzc4Yzg3YTI4ZjJhMmU0NTRjNTg5YjU4MWE1OTZmOTc4ZTU5
  /// ZGYyYzVlNzU5YzU4ZTk5Zjk4MmVjMmE1NzIzNzhjODdhMjhmMmEyZTQ1NGM1ODk=
  /// -----END PRIVATE KEY for erd1qyu5...-----
  ///
  /// -----BEGIN PRIVATE KEY for erd1spyavw...-----
  /// ...
  /// -----END PRIVATE KEY for erd1spyavw...-----
  /// ''';
  ///
  /// final entries = PemEntry.fromTextAll(pemContent);
  /// print('Found ${entries.length} keys');
  ///
  /// for (final entry in entries) {
  ///   print('Label: ${entry.label}');
  ///   final secretKey = UserSecretKey(entry.message.sublist(0, 32));
  /// }
  /// ```
  static List<PemEntry> fromTextAll(String pemText) {
    final List<String> lines = _cleanLines(pemText.split('\n'));
    final List<List<String>> blocks = _groupBlocks(lines);

    return blocks.map((List<String> block) {
      if (block.length < 2) {
        throw const FormatException(
          'Invalid PEM format: Block must have header and footer',
        );
      }
      final String header = block.first;
      final String footer = block.last;

      if (!header.startsWith('-----BEGIN PRIVATE KEY for') ||
          !footer.startsWith('-----END PRIVATE KEY for')) {
        throw const FormatException('Invalid PEM format');
      }

      final String label = header
          .replaceAll('-----BEGIN PRIVATE KEY for', '')
          .replaceAll('-----', '')
          .trim();

      final String base64Message = block.sublist(1, block.length - 1).join('');
      final String messageHex = utf8.decode(base64.decode(base64Message));
      final Uint8List messageBytes = HexUtils.hexToBytes(messageHex);

      return PemEntry(label: label, message: messageBytes);
    }).toList();
  }

  /// Converts entry to PEM text format.
  ///
  /// #### Returns
  /// `String` - PEM formatted string with BEGIN/END markers
  ///
  /// #### Example
  /// ```dart
  /// final entry = PemEntry(
  ///   label: 'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th',
  ///   message: keyBytes,
  /// );
  ///
  /// final pemText = entry.toText();
  /// print(pemText);
  /// // -----BEGIN PRIVATE KEY for erd1qyu5...-----
  /// // NWY5ODJlYzJhNTcyMzc4Yzg3YTI4ZjJhMmU0NTRjNTg5YjU4MWE1OTZmOTc4ZTU5
  /// // ZGYyYzVlNzU5YzU4ZTk5Zjk4MmVjMmE1NzIzNzhjODdhMjhmMmEyZTQ1NGM1ODk=
  /// // -----END PRIVATE KEY for erd1qyu5...-----
  ///
  /// // Save to file
  /// await File('wallet.pem').writeAsString(pemText);
  /// ```
  String toText() {
    final String header = '-----BEGIN PRIVATE KEY for $label-----';
    final String footer = '-----END PRIVATE KEY for $label-----';

    final String messageHex = HexUtils.bytesToHex(message);
    final String messageBase64 = base64.encode(utf8.encode(messageHex));
    final List<String> payloadLines = _wrapText(messageBase64, 64);
    final String payload = payloadLines.join('\n');

    return <String>[header, payload, footer].join('\n');
  }

  static List<String> _cleanLines(List<String> lines) {
    return lines
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
  }

  static List<List<String>> _groupBlocks(List<String> lines) {
    final List<List<String>> blocks = <List<String>>[];
    List<String> currentBlock = <String>[];

    for (final String line in lines) {
      if (line.startsWith('-----BEGIN PRIVATE KEY for')) {
        if (currentBlock.isNotEmpty) {
          blocks.add(currentBlock);
        }
        currentBlock = <String>[line];
      } else if (line.startsWith('-----END PRIVATE KEY for')) {
        currentBlock.add(line);
        blocks.add(currentBlock);
        currentBlock = <String>[];
      } else {
        currentBlock.add(line);
      }
    }

    if (currentBlock.isNotEmpty) {
      throw const FormatException(
        'Invalid PEM format: Missing END line for a block',
      );
    }

    return blocks;
  }

  static List<String> _wrapText(String text, int width) {
    final List<String> lines = <String>[];
    for (int i = 0; i < text.length; i += width) {
      final int end = (i + width < text.length) ? i + width : text.length;
      lines.add(text.substring(i, end));
    }
    return lines;
  }
}
