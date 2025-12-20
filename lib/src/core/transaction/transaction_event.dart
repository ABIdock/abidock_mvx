/// Smart contract event representation with topics and data.
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../utils/collection_utils.dart';
import '../../utils/helpers.dart';
import '../../utils/hex_utils.dart';
import '../address.dart';

/// Represents an event emitted by a smart contract transaction.
/// Contains indexed parameters, non-indexed parameters, and data payload.
///
/// #### Example
/// ```dart
/// final event = TransactionEvent(
///   address: contractAddress,
///   identifier: 'deposit',
///   topics: [userAddressBytes, amountBytes],
///   data: additionalDataBytes,
/// );
///
/// print('Event: ${event.identifier}');
/// print('Contract: ${event.address.bech32}');
/// ```
@immutable
class TransactionEvent {
  /// Creates a transaction event with all components.
  ///
  /// #### Parameters
  /// - `address` - Smart contract address that emitted the event
  /// - `identifier` - Event name/type (e.g., 'transfer', 'deposit')
  /// - `topics` - Indexed parameters as byte arrays
  /// - `data` - Main data payload
  /// - `additionalData` - Extra data segments (optional, default: empty)
  /// - `order` - Event order in the transaction (0-based)
  /// - `addressAssets` - Account assets for the event address (optional)
  /// - `raw` - Original API response map (optional, for debugging)
  const TransactionEvent({
    required this.address,
    required this.identifier,
    required this.topics,
    required this.data,
    this.additionalData = const <Uint8List>[],
    this.order = 0,
    this.addressAssets,
    this.raw = const <String, dynamic>{},
  });

  /// Creates an event from the API HTTP response with base64-encoded data.
  ///
  /// #### Parameters
  /// - `response` - API response map with 'address', 'identifier', 'topics', 'data', 'additionalData'
  ///
  /// #### Returns
  /// `TransactionEvent` - Transaction event with decoded byte arrays
  ///
  /// #### Example
  /// ```dart
  /// // From /transactions/:hash endpoint
  /// final txResponse = await provider.getTransaction(txHash);
  /// final logs = txResponse['logs'];
  /// final events = logs['events'].map((e) =>
  ///   TransactionEvent.fromHttpResponse(e)
  /// ).toList();
  ///
  /// for (final event in events) {
  ///   print('Event: ${event.identifier}');
  /// }
  /// ```
  factory TransactionEvent.fromHttpResponse(Map<String, dynamic> response) {
    final String addressStr = requireAs<String>(response['address'], 'address');
    final String identifierStr =
        optionalAs<String>(response['identifier'], 'identifier') ?? '';
    final List<dynamic> topicsList =
        optionalAs<List<dynamic>>(response['topics'], 'topics') ?? <dynamic>[];
    final String? dataStr = optionalAs<String>(response['data'], 'data');
    final List<dynamic> additionalDataList =
        optionalAs<List<dynamic>>(
          response['additionalData'],
          'additionalData',
        ) ??
        <dynamic>[];
    final int order = optionalAs<int>(response['order'], 'order') ?? 0;
    final Map<String, dynamic>? addressAssets =
        optionalAs<Map<String, dynamic>>(
          response['addressAssets'],
          'addressAssets',
        );

    final List<Uint8List> topics = topicsList
        .map(
          (topic) => Uint8List.fromList(
            base64.decode(requireAs<String>(topic, 'topic')),
          ),
        )
        .toList();

    final Uint8List data = dataStr != null
        ? Uint8List.fromList(base64.decode(dataStr))
        : Uint8List(0);

    final List<Uint8List> additionalData = additionalDataList
        .map(
          (item) => Uint8List.fromList(
            base64.decode(requireAs<String>(item, 'additionalDataItem')),
          ),
        )
        .toList();

    return TransactionEvent(
      address: Address.fromBech32(addressStr),
      identifier: identifierStr,
      topics: topics,
      data: data,
      additionalData: additionalData,
      order: order,
      addressAssets: addressAssets,
      raw: response,
    );
  }

  /// Creates an event from the `/events` API endpoint response with hex-encoded data.
  ///
  /// #### Parameters
  /// - `response` - API response map from `/events` endpoint
  ///
  /// #### Returns
  /// `TransactionEvent` - Transaction event with decoded byte arrays
  ///
  /// #### Example
  /// ```dart
  /// // From /events endpoint
  /// final eventsResponse = await provider.getEvents({
  ///   'address': contractAddress.bech32,
  ///   'identifier': 'transfer',
  /// });
  ///
  /// final events = eventsResponse['events'].map((e) =>
  ///   TransactionEvent.fromEventsEndpoint(e)
  /// ).toList();
  ///
  /// for (final event in events) {
  ///   final amount = event.getTopicAsBigInt(2);
  ///   print('Transfer amount: $amount');
  /// }
  /// ```
  factory TransactionEvent.fromEventsEndpoint(Map<String, dynamic> response) {
    final String addressStr = requireAs<String>(response['address'], 'address');
    final String identifierStr =
        optionalAs<String>(response['identifier'], 'identifier') ?? '';
    final List<dynamic> topicsList =
        optionalAs<List<dynamic>>(response['topics'], 'topics') ?? <dynamic>[];
    final String? dataStr = optionalAs<String>(response['data'], 'data');
    final List<dynamic> additionalDataList =
        optionalAs<List<dynamic>>(
          response['additionalData'],
          'additionalData',
        ) ??
        <dynamic>[];
    final int order = optionalAs<int>(response['order'], 'order') ?? 0;
    final Map<String, dynamic>? addressAssets =
        optionalAs<Map<String, dynamic>>(
          response['addressAssets'],
          'addressAssets',
        );

    final List<Uint8List> topics = topicsList
        .map((topic) => HexUtils.hexToBytes(requireAs<String>(topic, 'topic')))
        .toList();

    final Uint8List data = dataStr != null && dataStr.isNotEmpty
        ? HexUtils.hexToBytes(dataStr)
        : Uint8List(0);

    final List<Uint8List> additionalData = additionalDataList
        .map(
          (item) => HexUtils.hexToBytes(
            requireAs<String>(item, 'additionalDataItem'),
          ),
        )
        .toList();

    return TransactionEvent(
      address: Address.fromBech32(addressStr),
      identifier: identifierStr,
      topics: topics,
      data: data,
      additionalData: additionalData,
      order: order,
      addressAssets: addressAssets,
      raw: response,
    );
  }

  /// The address of the smart contract that emitted this event.
  final Address address;

  /// The identifier (name) of the event.
  final String identifier;

  /// The topics (indexed parameters) of the event.
  final List<Uint8List> topics;

  /// The main data payload of the event.
  final Uint8List data;

  /// Additional data payloads (for complex multi-part events).
  final List<Uint8List> additionalData;

  /// The order of this event in the transaction (0-based index).
  /// Events are ordered by their execution sequence within the transaction.
  final int order;

  /// Account assets associated with the event address.
  /// Contains metadata like name, description, icon for known addresses.
  final Map<String, dynamic>? addressAssets;

  /// The raw response data from the API (for debugging).
  final Map<String, dynamic> raw;

  /// Converts a topic to a UTF-8 decoded string.
  ///
  /// #### Parameters
  /// - `index` - Topic index (0-based)
  ///
  /// #### Returns
  /// `String` - UTF-8 decoded string, empty if index out of bounds
  ///
  /// #### Example
  /// ```dart
  /// // topics[0] might contain event name as string
  /// final eventName = event.getTopicAsString(0);
  /// print('Event type: $eventName');
  /// ```
  String getTopicAsString(int index) {
    if (index >= topics.length) {
      return '';
    }
    return utf8.decode(topics[index]);
  }

  /// Converts a topic to a lowercase hex string.
  ///
  /// #### Parameters
  /// - `index` - Topic index (0-based)
  ///
  /// #### Returns
  /// `String` - Hex string, empty if index out of bounds
  ///
  /// #### Example
  /// ```dart
  /// // topics[1] might contain address bytes
  /// final addressHex = event.getTopicAsHex(1);
  /// print('Address hex: $addressHex');
  /// ```
  String getTopicAsHex(int index) {
    if (index >= topics.length) {
      return '';
    }
    return HexUtils.bytesToHex(topics[index]);
  }

  /// Converts a topic to a BigInt by parsing hex representation.
  ///
  /// #### Parameters
  /// - `index` - Topic index (0-based)
  ///
  /// #### Returns
  /// `BigInt` - BigInt value, zero if index out of bounds or empty
  ///
  /// #### Example
  /// ```dart
  /// // topics[2] might contain amount as big integer
  /// final amount = event.getTopicAsBigInt(2);
  /// print('Transfer amount: $amount');
  /// ```
  BigInt getTopicAsBigInt(int index) {
    if (index >= topics.length) {
      return BigInt.zero;
    }
    final String hex = getTopicAsHex(index);
    if (hex.isEmpty) {
      return BigInt.zero;
    }
    try {
      return BigInt.parse(hex, radix: 16);
    } on FormatException {
      return BigInt.zero;
    }
  }

  /// Converts the data payload to a UTF-8 decoded string.
  ///
  /// #### Returns
  /// `String` - UTF-8 string from data bytes
  ///
  /// #### Example
  /// ```dart
  /// if (event.isSignalError) {
  ///   print('Error message: ${event.dataAsString}');
  /// }
  /// ```
  String get dataAsString => utf8.decode(data);

  /// Converts the data payload to a lowercase hex string.
  ///
  /// #### Returns
  /// `String` - Hex string representation of data
  ///
  /// #### Example
  /// ```dart
  /// print('Data hex: ${event.dataAsHex}');
  /// ```
  String get dataAsHex => HexUtils.bytesToHex(data);

  /// Checks if this is a standard "writeLog" event.
  ///
  /// #### Returns
  /// `bool` - True if identifier is 'writeLog'
  bool get isWriteLog => identifier == 'writeLog';

  /// Checks if this is a "signalError" event indicating failure.
  ///
  /// #### Returns
  /// `bool` - True if identifier is 'signalError'
  ///
  /// #### Example
  /// ```dart
  /// if (event.isSignalError) {
  ///   final errorMsg = event.dataAsString;
  ///   print('Contract error: $errorMsg');
  /// }
  /// ```
  bool get isSignalError => identifier == 'signalError';

  /// Checks if this is a "SCDeploy" (smart contract deployment) event.
  ///
  /// #### Returns
  /// `bool` - True if identifier is 'SCDeploy'
  bool get isScDeploy => identifier == 'SCDeploy';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TransactionEvent) return false;

    return address == other.address &&
        identifier == other.identifier &&
        order == other.order &&
        CollectionUtils.bytesListEquals(topics, other.topics) &&
        CollectionUtils.bytesEquals(data, other.data) &&
        CollectionUtils.bytesListEquals(additionalData, other.additionalData);
  }

  @override
  int get hashCode => Object.hash(
    address,
    identifier,
    order,
    CollectionUtils.bytesListHashCode(topics),
    Object.hashAll(data),
    CollectionUtils.bytesListHashCode(additionalData),
  );

  @override
  String toString() {
    return 'TransactionEvent('
        'identifier: $identifier, '
        'address: ${address.bech32}, '
        'order: $order, '
        'topics: ${topics.length}, '
        'dataBytes: ${data.length}'
        ')';
  }
}
