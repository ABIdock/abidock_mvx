import 'dart:typed_data';

/// Bech32 encoder for MultiversX addresses (BIP-0173).
///
/// Encodes and decodes addresses using the Bech32 format with checksums.
final class Bech32Encoder {
  /// Creates a Bech32 encoder with human-readable prefix.
  ///
  /// #### Parameters
  /// - `hrp` - Human-readable part (e.g., 'erd' for MultiversX mainnet)
  const Bech32Encoder({required this.hrp});

  /// Human-readable part (e.g., 'erd').
  final String hrp;

  /// Bech32 character set (32 characters).
  static const String _charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

  /// Character dividing the human-readable part from the data part.
  static const String _separator = '1';

  /// Generator values for checksum calculation (BIP-0173).
  static const List<int> _generator = [
    0x3b6a57b2,
    0x26508e6d,
    0x1ea119fa,
    0x3d4233dd,
    0x2a1462b3,
  ];

  /// Encodes bytes to Bech32 string.
  ///
  /// #### Parameters
  /// - `data` - Bytes to encode (typically 32 bytes for MultiversX addresses)
  ///
  /// #### Returns Bech32 encoded string (e.g., 'erd1qqqqqqqqqqqqqpgq...')
  ///
  /// #### Throws
  /// - `ArgumentError` - If data is empty or conversion fails
  ///
  String encode(List<int> data) {
    if (data.isEmpty) {
      throw ArgumentError.value(data, 'data', 'Data cannot be empty');
    }

    final List<int> converted = _convertBits(data, from: 8, to: 5, pad: true);

    final List<int> checksum = _createChecksum(converted);

    final StringBuffer result = StringBuffer();
    result.write(hrp);
    result.write(_separator);

    for (final int value in converted) {
      result.write(_charset[value]);
    }

    for (final int value in checksum) {
      result.write(_charset[value]);
    }

    return result.toString();
  }

  /// Decodes Bech32 string to bytes.
  ///
  /// Bech32 is case-insensitive per BIP-0173, so input is normalized to lowercase.
  ///
  /// #### Parameters
  /// - `bech32` - Bech32 encoded string (e.g., 'erd1qqqqqqqqqqqqqpgq...')
  ///
  /// #### Returns Decoded bytes (`Uint8List`)
  ///
  /// #### Throws
  /// - `ArgumentError` - If format is invalid, checksum fails, or HRP mismatches
  ///
  Uint8List decode(String bech32) {
    if (bech32.isEmpty) {
      throw ArgumentError.value(
        bech32,
        'bech32',
        'Bech32 string cannot be empty',
      );
    }

    if (bech32 != bech32.toLowerCase() && bech32 != bech32.toUpperCase()) {
      throw ArgumentError.value(
        bech32,
        'bech32',
        'Mixed-case Bech32 strings are not allowed (BIP-0173)',
      );
    }
    final String normalizedBech32 = bech32.toLowerCase();

    final int separatorIndex = normalizedBech32.lastIndexOf('1');
    if (separatorIndex == -1) {
      throw ArgumentError.value(
        bech32,
        'bech32',
        'No separator character (1) found',
      );
    }

    final String foundHrp = normalizedBech32.substring(0, separatorIndex);
    final String data = normalizedBech32.substring(separatorIndex + 1);

    if (foundHrp != hrp) {
      throw ArgumentError.value(
        bech32,
        'bech32',
        'Invalid HRP: expected "$hrp", got "$foundHrp"',
      );
    }

    if (data.length < 6) {
      throw ArgumentError.value(
        bech32,
        'bech32',
        'Data part too short (minimum 6 characters)',
      );
    }

    final List<int> decoded = <int>[];
    for (int i = 0; i < data.length; i++) {
      final int value = _charset.indexOf(data[i]);
      if (value == -1) {
        throw ArgumentError.value(
          bech32,
          'bech32',
          'Invalid character "${data[i]}" at position ${separatorIndex + 1 + i}',
        );
      }
      decoded.add(value);
    }

    if (!_verifyChecksum(decoded)) {
      throw ArgumentError.value(bech32, 'bech32', 'Invalid checksum');
    }

    final List<int> dataWithoutChecksum = decoded.sublist(
      0,
      decoded.length - 6,
    );

    final List<int> bytes = _convertBits(
      dataWithoutChecksum,
      from: 5,
      to: 8,
      pad: false,
    );

    return Uint8List.fromList(bytes);
  }

  /// Converts bits from one base to another.
  ///
  /// #### Parameters
  /// - `data` - Input data to convert
  /// - `from` - Source bit width (e.g., 8 for bytes)
  /// - `to` - Target bit width (e.g., 5 for Bech32)
  /// - `pad` - Whether to pad the last group with zeros
  ///
  /// #### Returns
  /// Converted data as list of integers
  List<int> _convertBits(
    List<int> data, {
    required int from,
    required int to,
    required bool pad,
  }) {
    int accumulator = 0;
    int pendingBits = 0;
    final List<int> result = <int>[];
    final int targetMask = (1 << to) - 1;
    final int accumulatorMask = (1 << (from + to - 1)) - 1;

    for (final int value in data) {
      if (value < 0 || (value >> from) != 0) {
        throw ArgumentError.value(
          value,
          'value',
          'Value out of range for $from-bit conversion',
        );
      }

      accumulator = ((accumulator << from) | value) & accumulatorMask;
      pendingBits += from;

      while (pendingBits >= to) {
        pendingBits -= to;
        result.add((accumulator >> pendingBits) & targetMask);
      }
    }

    if (pad) {
      if (pendingBits > 0) {
        result.add((accumulator << (to - pendingBits)) & targetMask);
      }
    } else if (pendingBits >= from ||
        ((accumulator << (to - pendingBits)) & targetMask) != 0) {
      throw ArgumentError('Invalid padding in conversion');
    }

    return result;
  }

  /// Creates checksum for data (6 characters = 30 bits).
  ///
  /// #### Parameters
  /// - `values` - 5-bit data values to checksum
  ///
  /// #### Returns
  /// 6-character checksum as list of 5-bit values
  List<int> _createChecksum(List<int> values) {
    final List<int> expanded = _expandHrp();
    final List<int> combined = <int>[...expanded, ...values, 0, 0, 0, 0, 0, 0];
    final int polymod = _polymod(combined) ^ 1;

    final List<int> checksum = <int>[];
    for (int i = 0; i < 6; i++) {
      checksum.add((polymod >> (5 * (5 - i))) & 31);
    }

    return checksum;
  }

  /// Verifies checksum of decoded data.
  ///
  /// #### Parameters
  /// - `values` - Decoded 5-bit values (including 6-character checksum)
  ///
  /// #### Returns
  /// `true` if checksum is valid, `false` otherwise
  bool _verifyChecksum(List<int> values) {
    final List<int> expanded = _expandHrp();
    final List<int> combined = <int>[...expanded, ...values];
    return _polymod(combined) == 1;
  }

  /// Expands HRP to 5-bit values for checksum calculation.
  ///
  /// #### Returns
  /// Expanded HRP as list of 5-bit values
  List<int> _expandHrp() {
    final List<int> result = <int>[];

    for (int i = 0; i < hrp.length; i++) {
      result.add(hrp.codeUnitAt(i) >> 5);
    }

    result.add(0);

    for (int i = 0; i < hrp.length; i++) {
      result.add(hrp.codeUnitAt(i) & 31);
    }

    return result;
  }

  /// Calculates polymod (polynomial modulo) for checksum.
  ///
  /// #### Parameters
  /// - `values` - 5-bit values to calculate polymod over
  ///
  /// #### Returns
  /// 30-bit polymod result
  int _polymod(List<int> values) {
    int chk = 1;

    for (final int value in values) {
      final int top = chk >> 25;
      chk = ((chk & 0x1ffffff) << 5) ^ value;

      for (int i = 0; i < 5; i++) {
        if ((top >> i) & 1 != 0) {
          chk ^= _generator[i];
        }
      }
    }

    return chk;
  }
}
