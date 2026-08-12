import 'dart:typed_data';
import 'package:convert/convert.dart' as convert;
import 'package:pointycastle/pointycastle.dart' show Digest;
import '../utils/sdk_exceptions.dart';
import '../wallet/crypto/bech32_encoder.dart';
import 'nonce.dart';

/// Exception thrown when an [Address] cannot be parsed or validated.
///
/// Used by [Address.fromBech32], [Address.fromHex], and shard helpers when
/// the input is malformed. Inherits from [AbidockException] so callers can
/// trap any SDK error with a single `on AbidockException catch (e)` clause.
///
/// #### Example
/// ```dart
/// try {
///   Address.fromBech32('not-a-bech32');
/// } on AddressException catch (e) {
///   print('Bad address: ${e.message}');
/// }
/// ```
class AddressException extends AbidockException {
  /// Creates an address exception.
  ///
  /// #### Parameters
  /// - `message` - Human-readable error description, typically including the
  ///   offending input.
  const AddressException(super.message, {super.cause, super.stackTrace});
}

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
  /// - [AddressException] - If bytes length is not 32
  ///
  /// #### Example
  /// ```dart
  /// final bytes = List<int>.filled(32, 0);
  /// final addr = Address(bytes);
  /// ```
  Address(this.bytes, {this.hrp = 'erd'}) {
    if (bytes.length != _addressLength) {
      throw AddressException(
        'Address bytes length must be $_addressLength '
        'but it is ${bytes.length}',
      );
    }
  }

  /// Creates Address from Bech32-encoded string.
  ///
  /// #### Parameters
  /// - `bech32` - Bech32 address string (e.g., 'erd1qqqqqqqqqqqqqpgq...')
  ///
  /// #### Throws
  /// - [AddressException] - If the string is not a well-formed Bech32 address:
  ///   missing separator, invalid character, bad checksum, or a payload that
  ///   does not decode to 32 bytes.
  ///
  /// #### Example
  /// ```dart
  /// final addr = Address.fromBech32('erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th');
  /// print(addr.hex);
  /// ```
  factory Address.fromBech32(final String bech32) {
    final String hrp = _extractHrp(bech32);
    final List<int> decoded;
    try {
      decoded = Bech32Encoder(hrp: hrp).decode(bech32);
    } on ArgumentError catch (e, s) {
      throw AddressException(
        'Invalid bech32 address "$bech32": ${e.message}',
        cause: e,
        stackTrace: s,
      );
    }
    return Address(decoded, hrp: hrp);
  }

  /// Creates Address from hexadecimal string.
  ///
  /// #### Parameters
  /// - `hex` - Hexadecimal string of 64 characters, without a `0x` prefix
  /// - `hrp` - Human-readable part (default: 'erd')
  ///
  /// #### Throws
  /// - [AddressException] - If the string is not valid hexadecimal or does not
  ///   decode to exactly 32 bytes.
  ///
  /// #### Example
  /// ```dart
  /// final addr = Address.fromHex('0000000000000000050000000000000000000000000000000000000000000000');
  /// print(addr.bech32);
  /// ```
  factory Address.fromHex(final String hex, {final String hrp = 'erd'}) {
    final List<int> decoded;
    try {
      decoded = convert.hex.decode(hex);
    } on FormatException catch (e, s) {
      throw AddressException(
        'Invalid hex address "$hex": ${e.message}',
        cause: e,
        stackTrace: s,
      );
    }
    if (decoded.length != _addressLength) {
      throw AddressException(
        'Address hex must decode to $_addressLength bytes, '
        'got ${decoded.length} (input: "$hex")',
      );
    }
    return Address(decoded, hrp: hrp);
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

  /// Creates an empty address: 32 zero bytes with the default `erd` HRP.
  ///
  /// Use [isEmpty] to test whether an address equals this sentinel value.
  ///
  /// #### Returns
  /// `Address` - All-zero 32-byte pubkey, hrp `erd`.
  static Address empty() => Address.zero();

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

  /// Checks if this address equals the zero address (32 zero bytes).
  bool get isEmpty {
    if (bytes.length != _addressLength) return false;
    for (int i = 0; i < _addressLength; i++) {
      if (bytes[i] != 0) return false;
    }
    return true;
  }

  /// Checks if address is the zero address (32 zero bytes).
  bool get isZero => isEmpty;

  /// Checks if address is a smart contract address.
  ///
  /// Contract pubkeys are minted with a zeroed prefix: the first 8 bytes are
  /// all zero for system and user smart contracts alike.
  ///
  /// #### Returns
  /// `bool` - True when the leading 8 bytes are all zero.
  ///
  /// #### Example
  /// ```dart
  /// final contract = Address.fromBech32('erd1qqqqqqqqqqqqqpgq...');
  /// print(contract.isSmartContract); // true
  /// ```
  bool get isSmartContract {
    if (bytes.length < _scPrefixLength) return false;
    for (int i = 0; i < _scPrefixLength; i++) {
      if (bytes[i] != 0) return false;
    }
    return true;
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
  static const int _scPrefixLength = 8;

  /// Extracts the HRP from a Bech32 address string.
  ///
  /// Throws [AddressException] if no separator is present. Previously this
  /// silently returned `erd` for any malformed input, which let invalid
  /// strings round-trip through [Address.fromBech32].
  static String _extractHrp(String bech32) {
    final int separatorIndex = bech32.lastIndexOf('1');
    if (separatorIndex <= 0) {
      throw AddressException(
        'Invalid bech32 address: missing separator in "$bech32"',
      );
    }
    return bech32.substring(0, separatorIndex);
  }

  /// Gets shard of address by bit-masking the last pubkey byte, the same
  /// derivation the chain uses to assign an account to a shard.
  static int getShardOfAddress(Address address, {int numberOfShards = 3}) {
    if (numberOfShards <= 0) {
      throw AddressException(
        'getShardOfAddress requires numberOfShards > 0, '
        'got $numberOfShards',
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

  /// Computes a smart contract address from deployer and nonce.
  ///
  /// #### Parameters
  /// - `deployer` - Account that deploys the contract.
  /// - `nonce` - Account nonce at deployment time.
  ///
  /// #### Returns
  /// `Address` - Newly minted contract address with the deployer's HRP.
  static Address computeContractAddress(Address deployer, Nonce nonce) {
    return computeContractAddressFromBigInt(deployer, BigInt.from(nonce.value));
  }

  /// Computes a smart contract address from deployer and `BigInt` nonce.
  ///
  /// Accepts nonces beyond the 64-bit range of [computeContractAddress].
  ///
  /// #### Parameters
  /// - `deployer` - Account that deploys the contract.
  /// - `nonce` - Account nonce at deployment time as a `BigInt`.
  ///
  /// #### Returns
  /// `Address` - Newly minted contract address with the deployer's HRP.
  static Address computeContractAddressFromBigInt(
    Address deployer,
    BigInt nonce,
  ) {
    final Uint8List nonceBytes = _encodeU64LittleEndianBigInt(nonce);
    final List<int> reversedNonce = nonceBytes.reversed.toList();

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

  /// Encodes a `BigInt` nonce as an 8-byte u64 little-endian buffer.
  static Uint8List _encodeU64LittleEndianBigInt(BigInt value) {
    final BigInt mask = BigInt.from(0xFF);
    final Uint8List bytes = Uint8List(8);
    BigInt v = value;
    for (int i = 0; i < 8; i++) {
      bytes[i] = (v & mask).toInt();
      v = v >> 8;
    }
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
