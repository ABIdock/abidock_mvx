import 'dart:typed_data';
import 'package:convert/convert.dart' as convert;
import 'package:pointycastle/pointycastle.dart' show Digest;
import '../wallet/crypto/bech32_encoder.dart';
import 'nonce.dart';

/// MultiversX blockchain address.
///
/// Supports Bech32 (erd1...) or hexadecimal formats with validation,
/// format conversion, and shard computation for user accounts and smart contracts.
///
/// #### Example
/// ```dart
/// // From Bech32
/// final addr1 = Address.fromBech32('erd1qqqqqqqqqqqqqpgq...');
///
/// // From hex
/// final addr2 = Address.fromHex('0000000000000000...');
///
/// // Check properties
/// print(addr1.bech32); // erd1...
/// print(addr1.hex); // hexadecimal
/// print(addr1.isSmartContract); // true/false
///
/// // Zero address
/// final zero = Address.zero();
/// ```
class Address {
  /// Creates Address from raw bytes (must be 32 bytes).
  ///
  /// #### Parameters
  /// - `bytes` - 32-byte address (`List&lt;int&gt;`)
  /// - `hrp` - Human-readable part for Bech32 (default: 'erd')
  ///
  /// #### Throws
  /// - `AssertionError` - If bytes length is not 32
  ///
  /// #### Example
  /// ```dart
  /// final bytes = List<int>.filled(32, 0);
  /// final addr = Address(bytes);
  /// ```
  Address(this.bytes, {this.hrp = 'erd'})
    : assert(
        bytes.length == _addressLength,
        'Address bytes length must be $_addressLength but it is ${bytes.length}',
      );

  /// Creates Address from Bech32-encoded string.
  ///
  /// #### Parameters
  /// - `bech32` - Bech32 address string (e.g., 'erd1qqqqqqqqqqqqqpgq...')
  ///
  /// #### Throws
  /// - Exception - If Bech32 decoding fails
  ///
  /// #### Example
  /// ```dart
  /// final addr = Address.fromBech32('erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th');
  /// print(addr.hex);
  /// ```
  Address.fromBech32(final String bech32)
    : hrp = _extractHrp(bech32),
      bytes = Bech32Encoder(hrp: _extractHrp(bech32)).decode(bech32);

  /// Creates Address from hexadecimal string.
  ///
  /// #### Parameters
  /// - `hex` - Hexadecimal string (64 characters, with or without 0x prefix)
  /// - `hrp` - Human-readable part (default: 'erd')
  ///
  /// #### Throws
  /// - `FormatException` - If hex string is invalid
  ///
  /// #### Example
  /// ```dart
  /// final addr = Address.fromHex('0000000000000000050000000000000000000000000000000000000000000000');
  /// print(addr.bech32);
  /// ```
  Address.fromHex(final String hex, {this.hrp = 'erd'})
    : bytes = convert.hex.decode(hex) {
    if (bytes.length != _addressLength) {
      throw FormatException(
        'Address hex must decode to $_addressLength bytes, got ${bytes.length}',
      );
    }
  }

  /// Validates Bech32-encoded address string.
  ///
  /// #### Parameters
  /// - `bech32` - Bech32 address string to validate
  ///
  /// #### Returns
  /// `bool` - True if valid, false otherwise
  ///
  /// #### Example
  /// ```dart
  /// print(Address.isValid('erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th')); // true
  /// print(Address.isValid('invalid')); // false
  /// ```
  static bool isValid(String bech32) {
    try {
      final String hrp = _extractHrp(bech32);
      final List<int> decoded = Bech32Encoder(hrp: hrp).decode(bech32);
      return decoded.length == _addressLength;
    } catch (e) {
      return false;
    }
  }

  /// Creates empty address (0 bytes).
  Address.empty({this.hrp = 'erd'}) : bytes = List.empty(growable: false);

  /// Creates zero address (32 bytes all set to 0).
  Address.zero({this.hrp = 'erd'})
    : bytes = List.generate(_addressLength, (_) => 0, growable: false);

  /// Raw bytes of address (32 bytes).
  final List<int> bytes;

  /// Human-readable part for Bech32 address.
  final String hrp;

  /// Address as hexadecimal string.
  String get hex => convert.hex.encode(bytes);

  /// Address as Bech32-encoded string.
  String get bech32 => Bech32Encoder(hrp: hrp).encode(bytes);

  /// Checks if address is empty (0 bytes).
  bool get isEmpty => bytes.isEmpty;

  /// Checks if address is the zero address (32 zero bytes).
  bool get isZero {
    if (bytes.length != _addressLength) return false;
    for (int i = 0; i < _addressLength; i++) {
      if (bytes[i] != 0) return false;
    }
    return true;
  }

  /// Checks if address is smart contract address.
  ///
  /// #### Returns
  /// `bool` - True if address is a smart contract (bytes 8-9 are [0x05, 0x00])
  ///
  /// #### Example
  /// ```dart
  /// final contract = Address.fromBech32('erd1qqqqqqqqqqqqqpgq...');
  /// print(contract.isSmartContract); // true
  ///
  /// final user = Address.fromBech32('erd1qyu5wthldzr8wx5c...');
  /// print(user.isSmartContract); // false
  /// ```
  bool get isSmartContract {
    if (bytes.length < 10) return false;
    return bytes[8] == 0x05 && bytes[9] == 0x00;
  }

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    if (other is! Address) return false;
    if (hrp != other.hrp) return false;
    if (bytes.length != other.bytes.length) return false;
    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] != other.bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    int hash = 0x811c9dc5;
    for (final int code in hrp.codeUnits) {
      hash = ((hash ^ code) * 0x01000193) & 0x7FFFFFFF;
    }
    for (int i = 0; i < bytes.length; i++) {
      hash = ((hash ^ bytes[i]) * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  @override
  String toString() => bech32;

  static const int _addressLength = 32;

  /// Extracts HRP from Bech32 address string.
  static String _extractHrp(String bech32) {
    final separatorIndex = bech32.lastIndexOf('1');
    if (separatorIndex <= 0) return 'erd';
    return bech32.substring(0, separatorIndex);
  }

  /// Gets shard of address using bit masking algorithm (matches blockchain implementation).
  static int getShardOfAddress(Address address, {int numberOfShards = 3}) {
    if (numberOfShards <= 0) {
      throw ArgumentError.value(
        numberOfShards,
        'numberOfShards',
        'must be positive',
      );
    }

    if (isPubkeyOfMetachain(address)) {
      return 4294967295;
    }

    final lastByteOfPubKey = address.bytes[31];

    int n = 0;
    int v = numberOfShards - 1;
    while (v > 0) {
      n++;
      v >>= 1;
    }
    final maskHigh = (1 << n) - 1;
    final maskLow = (1 << (n - 1)) - 1;

    var shard = lastByteOfPubKey & maskHigh;
    if (shard > numberOfShards - 1) {
      shard = lastByteOfPubKey & maskLow;
    }

    return shard;
  }

  /// Checks if address belongs to metachain.
  static bool isPubkeyOfMetachain(Address address) {
    final isZero = address.bytes.every((b) => b == 0);
    if (isZero) return true;

    if (address.bytes.length >= 10) {
      return address.bytes[8] == 0x00 && address.bytes[9] == 0x01;
    }

    return false;
  }
}

/// Helper for computing smart contract addresses.
class AddressComputer {
  AddressComputer._();

  /// Computes smart contract address from deployer and nonce.
  static Address computeContractAddress(Address deployer, Nonce nonce) {
    final nonceBytes = _encodeU64LittleEndian(nonce.value);
    final reversedNonce = nonceBytes.reversed.toList();

    final List<int> bytesToHash = <int>[...deployer.bytes, ...reversedNonce];

    final List<int> digest = Digest(
      'Keccak/256',
    ).process(Uint8List.fromList(bytesToHash)).toList();

    final List<int> contractBytes = <int>[
      for (int i = 0; i < 8; i++) 0,
      0x05,
      0x00,
      ...digest.sublist(10, 30),
      ...deployer.bytes.sublist(30),
    ];

    return Address(contractBytes, hrp: deployer.hrp);
  }

  /// Encodes integer as 8-byte u64 little-endian.
  static Uint8List _encodeU64LittleEndian(int value) {
    final bytes = Uint8List(8);
    bytes.buffer.asByteData().setUint64(0, value, Endian.little);
    return bytes;
  }

  /// Gets shard of smart contract address.
  static int getShardOfContractAddress(
    Address contractAddress, {
    int numberOfShards = 3,
  }) {
    return Address.getShardOfAddress(
      contractAddress,
      numberOfShards: numberOfShards,
    );
  }
}
