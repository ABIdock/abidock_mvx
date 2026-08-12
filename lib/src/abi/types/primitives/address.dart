import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../core/address.dart' as core;
import '../../../utils/hex_utils.dart';
import '../../../wallet/crypto/bech32_encoder.dart';
import '../../core/type_system.dart';

/// Bech32 encoder for MultiversX addresses (hrp: 'erd').
const Bech32Encoder _bech32Encoder = Bech32Encoder(hrp: 'erd');

/// MultiversX address type (32 bytes for accounts or smart contracts).
///
/// Represents blockchain addresses on MultiversX network. Addresses
/// are 32 bytes and can be encoded as bech32 (erd1...) or hexadecimal strings.
///
/// #### Example
/// ```dart
/// // From bech32 string
/// final addr1 = AddressType.create('erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th');
///
/// // From hex string
/// final addr2 = AddressType.create('0139472eff6886771a982f3083da5d421f24c29181e63888228dc81ca60d69e1');
///
/// print(addr1.toBech32()); // erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th
/// print(addr2.toHex()); // 0139472eff6886771a982f3083da5d421f24c29181e63888228dc81ca60d69e1
///
/// // Use in struct definitions
/// final structType = StructType(
///   name: 'Ownership',
///   fieldDefinitions: [
///     FieldDefinition(name: 'owner', type: AddressType.type),
///   ],
/// );
/// ```
@immutable
final class AddressType extends PrimitiveType {
  AddressType._() : super(name: 'Address');

  static final AddressType _instance = AddressType._();

  /// Size of an address in bytes (always 32).
  static const int addressLength = 32;

  @override
  int get sizeInBytes => addressLength;

  @override
  String get className => 'AddressType';

  static const List<String> _classHierarchy = [
    'AddressType',
    'PrimitiveType',
    'AbiType',
  ];

  @override
  List<String> get classHierarchy => _classHierarchy;

  /// Creates an AddressValue from native value.
  ///
  /// #### Parameters
  /// - `nativeValue` - `List<int>` (32 bytes), bech32 string (erd1...), or hex string
  ///
  /// #### Returns
  /// `AddressValue` - Instance with the address value
  ///
  /// #### Throws
  /// - `ArgumentError` - If value format is invalid or wrong length
  static AddressValue create(dynamic nativeValue) {
    if (nativeValue is List<int>) {
      return AddressValue(nativeValue);
    }

    if (nativeValue is String) {
      if (nativeValue.startsWith('erd1')) {
        return AddressValue.fromBech32(nativeValue);
      }
      return AddressValue.fromHex(nativeValue);
    }
    throw ArgumentError.value(
      nativeValue,
      'nativeValue',
      'AddressType requires List<int>, bech32 string (erd1...), or hex string',
    );
  }

  /// Creates a zero address (all bytes are 0).
  static AddressValue createZero() => AddressValue.zero;

  /// Gets the singleton type instance for use in type definitions.
  static AddressType get type => _instance;

  @override
  TypedValue createValue(dynamic nativeValue) => create(nativeValue);
}

/// MultiversX address value (32 bytes).
///
/// Holds a 32-byte blockchain address. Provides conversions between
/// bech32, hexadecimal, and byte representations.
///
/// #### Example
/// ```dart
/// final addr = AddressValue.fromBech32('erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3');
///
/// print(addr.toBech32()); // erd1qqq...
/// print(addr.toHex()); // 000000000000000005...
/// print(addr.toBytes().length); // 32
/// ```
@immutable
final class AddressValue extends TypedValue {
  /// The zero address (all bytes are 0x00).
  ///
  /// Commonly used for:
  /// - Initial/default values
  /// - Null address checks
  /// - Smart contract creation origin
  static final AddressValue zero = AddressValue(List<int>.filled(32, 0));

  /// Creates an Address value.
  ///
  /// #### Parameters
  /// - `value` - `List<int>` with exactly 32 bytes
  ///
  /// #### Throws
  /// - `ArgumentError` - If length is not 32 bytes
  ///
  /// #### Example
  /// ```dart
  /// final bytes = List<int>.generate(32, (i) => i);
  /// final addr = AddressValue(bytes);
  /// ```
  AddressValue(List<int> value)
    : value = _validateAndConvert(value),
      super(AddressType._instance);

  /// Creates an AddressValue from a bech32 string.
  ///
  /// #### Parameters
  /// - `bech32` - Bech32 encoded address (starts with 'erd1')
  ///
  /// #### Throws
  /// - Exception from bech32 decoder if format is invalid
  ///
  /// #### Example
  /// ```dart
  /// final addr = AddressValue.fromBech32('erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3');
  /// print(addr.toBytes().length); // 32
  /// ```
  factory AddressValue.fromBech32(String bech32) {
    final Uint8List bytes = _bech32Encoder.decode(bech32);
    return AddressValue(bytes);
  }

  /// Creates an AddressValue from a hex string.
  ///
  /// #### Parameters
  /// - `hex` - Hexadecimal string (64 characters for 32 bytes)
  ///
  /// #### Throws
  /// - `FormatException` - If hex format is invalid
  /// - `ArgumentError` - If resulting length is not 32 bytes
  ///
  /// #### Example
  /// ```dart
  /// final addr = AddressValue.fromHex('000000000000000005000000000000000000000100000000000000000001f4');
  /// print(addr.toBech32()); // erd1qqqqqqqqqqqqqpgq...
  /// ```
  factory AddressValue.fromHex(String hex) {
    return AddressValue(HexUtils.hexToBytes(hex));
  }

  /// Address bytes (32 bytes).
  final Uint8List value;

  static Uint8List _validateAndConvert(List<int> value) {
    if (value.length != AddressType.addressLength) {
      throw ArgumentError.value(
        value,
        'value',
        'Address must be exactly ${AddressType.addressLength} bytes',
      );
    }
    return Uint8List.fromList(value);
  }

  @override
  String get className => 'AddressValue';

  static const List<String> _classHierarchy = ['AddressValue', 'TypedValue'];

  @override
  List<String> get classHierarchy => _classHierarchy;

  @override
  String get nativeValue => toBech32();

  @pragma('vm:prefer-inline')
  @override
  List<int> toBytes() => Uint8List.fromList(value);

  /// Returns the hex representation of this address.
  @override
  String toHex() => HexUtils.bytesToHex(value);

  /// Returns the bech32 representation with HRP 'erd'.
  ///
  /// #### Returns
  /// Bech32 encoded address string (starts with 'erd1')
  ///
  /// #### Example
  /// ```dart
  /// final addr = AddressValue.fromHex('000000000000000005000000000000000000000100000000000000000001f4');
  /// print(addr.toBech32());
  /// // erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3
  /// ```
  String toBech32() {
    return _bech32Encoder.encode(value);
  }

  /// Checks if this address is a smart contract address.
  ///
  /// Smart contracts have the 10th byte (index 8) set to 0x05 (SC_START_MARKER).
  ///
  /// #### Returns
  /// true if this is a smart contract address, false otherwise
  ///
  /// #### Example
  /// ```dart
  /// final scAddr = AddressValue.fromBech32('erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3');
  /// print(scAddr.isSmartContract); // true
  ///
  /// final walletAddr = AddressValue.fromHex('0139472eff6886771a982f3083da5d421f24c29181e63888228dc81ca60d69e1');
  /// print(walletAddr.isSmartContract); // false
  /// ```
  bool get isSmartContract {
    if (value.length < 10) return false;
    for (int i = 0; i < 8; i++) {
      if (value[i] != 0x00) return false;
    }
    return value[8] == 0x05 && value[9] == 0x00;
  }

  /// Checks if this address is a wallet (user) address.
  ///
  /// Wallet addresses do NOT have the smart contract marker.
  ///
  /// #### Returns
  /// true if this is a wallet address, false otherwise
  ///
  /// #### Example
  /// ```dart
  /// final walletAddr = AddressValue.fromHex('0139472eff6886771a982f3083da5d421f24c29181e63888228dc81ca60d69e1');
  /// print(walletAddr.isWalletAddress); // true
  /// ```
  bool get isWalletAddress => !isSmartContract;

  /// Checks if this address is the zero address (all bytes are 0x00).
  ///
  /// The zero address is a special address with all 32 bytes set to 0.
  ///
  /// #### Returns
  /// true if all bytes are 0x00, false otherwise
  ///
  /// #### Example
  /// ```dart
  /// final zeroAddr = AddressValue(List<int>.filled(32, 0));
  /// print(zeroAddr.isZeroAddress); // true
  ///
  /// final normalAddr = AddressValue.fromBech32('erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3');
  /// print(normalAddr.isZeroAddress); // false
  /// ```
  bool get isZeroAddress {
    for (final int byte in value) {
      if (byte != 0) return false;
    }
    return true;
  }

  /// Gets the shard ID for this address.
  ///
  /// Shard ID is computed from the last byte of the address modulo the number of shards.
  /// MultiversX typically uses 3 shards (0, 1, 2) + metachain (4294967295).
  /// Smart contract addresses are always in the same shard as their deployer.
  ///
  /// #### Parameters
  /// - `shardCount` - Number of shards in the network (default: 3), must be > 0
  ///
  /// #### Returns
  /// `int` - Shard ID (0 to shardCount-1)
  ///
  /// #### Throws
  /// - `ArgumentError` - If shardCount is less than or equal to 0
  ///
  /// #### Example
  /// ```dart
  /// final addr = AddressValue.fromHex('0139472eff6886771a982f3083da5d421f24c29181e63888228dc81ca60d69e1');
  /// print(addr.getShardId()); // Computed from last byte: 0xe1 % 3 = 1
  ///
  /// final addr2 = AddressValue.fromHex('0139472eff6886771a982f3083da5d421f24c29181e63888228dc81ca60d69e0');
  /// print(addr2.getShardId()); // Computed from last byte: 0xe0 % 3 = 2
  /// ```
  int getShardId({int shardCount = 3}) {
    if (shardCount <= 0) {
      throw ArgumentError('shardCount must be greater than 0, got $shardCount');
    }
    if (value.isEmpty) return 0;
    final coreAddress = core.Address(Uint8List.fromList(value));
    return core.Address.getShardOfAddress(
      coreAddress,
      numberOfShards: shardCount,
    );
  }

  /// Compares this address with another AddressValue.
  ///
  /// #### Returns
  /// - negative if this < other
  /// - 0 if equal
  /// - positive if this > other
  ///
  /// #### Example
  /// ```dart
  /// final addr1 = AddressValue.fromHex('0000000000000000050000000000000000000001');
  /// final addr2 = AddressValue.fromHex('0000000000000000050000000000000000000002');
  /// print(addr1.compareTo(addr2)); // negative (addr1 < addr2)
  /// ```
  int compareTo(AddressValue other) {
    for (int i = 0; i < value.length && i < other.value.length; i++) {
      final int diff = value[i] - other.value[i];
      if (diff != 0) return diff;
    }
    return value.length - other.value.length;
  }

  /// Checks if this address is less than another address.
  bool operator <(AddressValue other) => compareTo(other) < 0;

  /// Checks if this address is less than or equal to another address.
  bool operator <=(AddressValue other) => compareTo(other) <= 0;

  /// Checks if this address is greater than another address.
  bool operator >(AddressValue other) => compareTo(other) > 0;

  /// Checks if this address is greater than or equal to another address.
  bool operator >=(AddressValue other) => compareTo(other) >= 0;

  /// Returns a truncated display format of the address for UI purposes.
  ///
  /// #### Parameters
  /// - `prefixLength` - Number of characters to show at start (default: 10), must be >= 0
  /// - `suffixLength` - Number of characters to show at end (default: 6), must be >= 0
  ///
  /// #### Returns
  /// `String` - Truncated bech32 string with ellipsis
  ///
  /// #### Throws
  /// - `ArgumentError` - If prefixLength or suffixLength is negative
  ///
  /// #### Example
  /// ```dart
  /// final addr = AddressValue.fromBech32('erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3');
  /// print(addr.toTruncated()); // erd1qqqqqq...3ntjj3
  /// ```
  String toTruncated({int prefixLength = 10, int suffixLength = 6}) {
    if (prefixLength < 0) {
      throw ArgumentError(
        'prefixLength must be non-negative, got $prefixLength',
      );
    }
    if (suffixLength < 0) {
      throw ArgumentError(
        'suffixLength must be non-negative, got $suffixLength',
      );
    }
    final String bech32 = toBech32();
    if (bech32.length <= prefixLength + suffixLength + 3) {
      return bech32;
    }
    return '${bech32.substring(0, prefixLength)}...${bech32.substring(bech32.length - suffixLength)}';
  }

  /// Converts the address to a byte array for use in transactions or serialization.
  Uint8List toUint8List() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressValue &&
          value.length == other.value.length &&
          _bytesEqual(value, other.value);

  bool _bytesEqual(Uint8List a, Uint8List b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(value);

  @override
  String toString() => toBech32();
}
