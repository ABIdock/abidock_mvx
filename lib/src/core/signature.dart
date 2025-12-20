import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;

/// Cryptographic signature.
/// Used for transaction signing, message signing, and signature verification.
///
/// #### Example
/// ```dart
/// // From hex
/// final sig1 = Signature('a1b2c3d4...');
///
/// // From bytes
/// final bytes = [161, 178, 195, 212, ...];
/// final sig2 = Signature.fromBytes(bytes);
///
/// // Empty signature
/// const empty = Signature.empty();
/// print(empty.isEmpty); // true
///
/// // Convert to bytes
/// final sigBytes = sig1.bytes;
/// final uint8List = sig1.toUint8List();
/// ```
class Signature {
  /// Creates Signature with hexadecimal string.
  ///
  /// #### Parameters
  /// - `hex` - Hexadecimal string representation of signature
  const Signature(this.hex);

  /// Creates empty Signature.
  const Signature.empty() : hex = '';

  /// Creates Signature from bytes.
  ///
  /// #### Parameters
  /// - `bytes` - `List&lt;int&gt;` signature bytes
  ///
  /// #### Returns
  /// Signature with hex-encoded bytes
  ///
  /// #### Example
  /// ```dart
  /// final bytes = [161, 178, 195, 212];
  /// final sig = Signature.fromBytes(bytes);
  /// print(sig.hex); // 'a1b2c3d4'
  /// ```
  factory Signature.fromBytes(List<int> bytes) =>
      Signature(convert.hex.encode(bytes));

  /// Creates Signature from Uint8List.
  ///
  /// #### Parameters
  /// - `bytes` - Uint8List signature bytes
  ///
  /// #### Returns
  /// Signature with hex-encoded bytes
  ///
  /// #### Example
  /// ```dart
  /// final bytes = Uint8List.fromList([161, 178, 195, 212]);
  /// final sig = Signature.fromUint8List(bytes);
  /// ```
  factory Signature.fromUint8List(Uint8List bytes) =>
      Signature(convert.hex.encode(bytes));

  /// Hexadecimal representation of signature.
  final String hex;

  /// Bytes as `List&lt;int&gt;`.
  List<int> get bytes => hex.isEmpty ? <int>[] : convert.hex.decode(hex);

  /// Bytes as Uint8List.
  ///
  /// #### Returns
  /// Uint8List of signature bytes (empty if no signature)
  ///
  /// #### Example
  /// ```dart
  /// final sig = Signature.fromBytes([161, 178, 195, 212]);
  /// final uint8 = sig.toUint8List();
  /// print(uint8.runtimeType); // Uint8List
  /// ```
  Uint8List toUint8List() =>
      hex.isEmpty ? Uint8List(0) : Uint8List.fromList(convert.hex.decode(hex));

  /// Whether signature is empty.
  bool get isEmpty => hex.isEmpty;

  /// Whether signature is not empty.
  bool get isNotEmpty => hex.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Signature && other.hex == hex;
  }

  @override
  int get hashCode => hex.hashCode;

  @override
  String toString() => 'Signature{ $hex }';
}
