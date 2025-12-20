/// ABI (Application Binary Interface) system for smart contract interaction.
///
/// Provides complete functionality for parsing, validating, and using contract
/// ABIs including endpoints, events, custom types, and argument encoding.
///
/// Core Components:
/// - [SmartContractAbi]: Complete contract ABI with endpoints, events, types
/// - [AbiRegistry]: Registry for managing multiple contract ABIs
/// - Type system: Primitives, collections, composites, special types
/// - Codecs: Binary encoding/decoding for all ABI types
/// - Serializers: Argument serialization for contract calls

import 'dart:convert';

import 'package:meta/meta.dart';

import '../utils/collection_utils.dart';
import '../utils/helpers.dart';
import 'core/core_types.dart';
import 'core/endpoint.dart';
import 'core/event.dart';
import 'core/types.dart';
import 'extensions/type_extensions.dart';

export 'codecs/codecs.dart';
export 'core/core.dart';
export 'extensions/extensions.dart';
export 'serializers/serializers.dart';
export 'smart_contract/smart_contract.dart';
export 'types/collections/collections.dart';
export 'types/composite/composite.dart';
export 'types/primitives/primitives.dart';
export 'types/special/special.dart';
export 'utils/utils.dart';

/// Complete ABI of a smart contract with endpoints, events, and custom types.
///
/// Represents the full interface of a smart contract including all
/// callable functions (endpoints), emitted events, and custom type definitions
/// (enums, structs). Typically loaded from JSON ABI files generated during
/// contract compilation.
///
/// #### Example
/// ```dart
/// // Load from JSON
/// final abi = SmartContractAbi.fromJson('''
/// {
///   "name": "MyToken",
///   "version": "1.0",
///   "endpoints": [
///     {"name": "transfer", "inputs": [...], "outputs": [...]}
///   ],
///   "events": [
///     {"identifier": "transfer", "inputs": [...]}
///   ],
///   "types": {
///     "TokenStatus": {"type": "enum", "variants": [...]}
///   }
/// }
/// ''');
///
/// // Query endpoints
/// final endpoint = abi.getEndpoint(SmartContractFunction('transfer'));
/// print('Transfer inputs: ${endpoint?.inputs.length}');
///
/// // Check payability
/// if (abi.hasEndpoint(SmartContractFunction('deposit'))) {
///   print('Has deposit endpoint');
/// }
///
/// // List all view functions
/// for (final endpoint in abi.viewEndpoints) {
///   print('View: ${endpoint.name}');
/// }
/// ```
///
/// Contains all information needed to interact with a smart contract including
/// function definitions, event definitions, and custom type information.
@immutable
final class SmartContractAbi {
  /// Creates a smart contract ABI.
  const SmartContractAbi({
    required this.name,
    this.version = '1.0',
    this.constructor,
    this.upgradeConstructor,
    required this.endpoints,
    this.events = const EventDefinitions.empty(),
    this.types = const <String, AbiType>{},
    this.metadata = const <String, dynamic>{},
  });

  /// Creates an empty ABI with no endpoints or events.
  const SmartContractAbi.empty({this.name = '', this.version = '1.0'})
    : constructor = null,
      upgradeConstructor = null,
      endpoints = const AbiEndpoints.empty(),
      events = const EventDefinitions.empty(),
      types = const <String, AbiType>{},
      metadata = const <String, dynamic>{};

  /// Creates ABI from JSON string.
  ///
  /// #### Parameters
  /// - `typeFactory` - Optional AbiTypeFactory instance for type resolution.
  ///   If null, a new instance is created. Useful for test isolation.
  ///
  /// #### Throws
  /// - `FormatException` if JSON is invalid.
  /// - `ArgumentError` if ABI structure is invalid.
  factory SmartContractAbi.fromJson(
    String jsonString, {
    AbiTypeFactory? typeFactory,
  }) {
    try {
      final Map<String, dynamic> data = requireAs<Map<String, dynamic>>(
        jsonDecode(jsonString),
        'json',
      );
      return SmartContractAbi.fromMap(data, typeFactory: typeFactory);
    } catch (e) {
      throw FormatException('Invalid JSON format: $e');
    }
  }

  /// Creates ABI from map representation.
  ///
  /// #### Parameters
  /// - `typeFactory` - Optional AbiTypeFactory instance for type resolution.
  ///   If null, a new instance is created. Useful for test isolation.
  factory SmartContractAbi.fromMap(
    Map<String, dynamic> data, {
    AbiTypeFactory? typeFactory,
  }) {
    final String name = optionalAs<String>(data['name'], 'name') ?? '';
    final String version =
        optionalAs<String>(data['version'], 'version') ?? '1.0';

    final AbiTypeFactory factory = typeFactory ?? AbiTypeFactory();
    final Map<String, AbiType> types = <String, AbiType>{};
    if (data.containsKey('types') && data['types'] is Map<String, dynamic>) {
      final Map<String, dynamic> typesData = requireAs<Map<String, dynamic>>(
        data['types'],
        'types',
      );

      for (final String typeName in typesData.keys) {
        factory.registerTypeName(typeName);
      }

      final Set<String> resolved = <String>{};
      final Set<String> resolving = <String>{};

      List<String> extractCustomTypeNames(String typeStr) {
        final List<String> customTypes = <String>[];

        if (typesData.containsKey(typeStr)) {
          customTypes.add(typeStr);
        }

        final typeParamMatch = RegExp(r'<(.+)>$').firstMatch(typeStr);
        if (typeParamMatch != null) {
          final innerTypes = typeParamMatch.group(1)!;
          for (final part in innerTypes.split(',')) {
            customTypes.addAll(extractCustomTypeNames(part.trim()));
          }
        }

        return customTypes;
      }

      void resolveTypeDependencies(String typeName) {
        if (resolved.contains(typeName)) {
          return;
        }

        if (resolving.contains(typeName)) {
          throw FormatException(
            'Circular dependency detected involving type: $typeName',
          );
        }

        resolving.add(typeName);

        final Map<String, dynamic> typeDefinition =
            requireAs<Map<String, dynamic>>(typesData[typeName], typeName);
        final String typeKind = requireAs<String>(
          typeDefinition['type'],
          'type',
        );

        if (typeKind == 'struct') {
          final List<dynamic> fieldsList =
              optionalAs<List<dynamic>>(typeDefinition['fields'], 'fields') ??
              <dynamic>[];
          for (final fieldDef in fieldsList) {
            final String fieldTypeStr = requireAs<String>(
              fieldDef['type'],
              'type',
            );
            final customTypesInField = extractCustomTypeNames(fieldTypeStr);
            for (final depType in customTypesInField) {
              if (!resolved.contains(depType)) {
                resolveTypeDependencies(depType);
              }
            }
          }
        }

        final AbiType resolvedType = factory.resolveType(
          typeName,
          typeDefinition,
        );
        types[typeName] = resolvedType;
        factory.registerCustomType(typeName, resolvedType);

        resolving.remove(typeName);
        resolved.add(typeName);
      }

      for (final String typeName in typesData.keys) {
        if (!resolved.contains(typeName)) {
          resolveTypeDependencies(typeName);
        }
      }
    }

    AbiEndpoint? constructor;
    if (data.containsKey('constructor') && data['constructor'] != null) {
      final Map<String, dynamic> constructorData =
          requireAs<Map<String, dynamic>>(data['constructor'], 'constructor');
      constructor = AbiEndpoint.fromMap(<String, dynamic>{
        'name': 'constructor',
        ...constructorData,
      }, typeFactory: factory);
    }

    AbiEndpoint? upgradeConstructor;
    if (data.containsKey('upgradeConstructor') &&
        data['upgradeConstructor'] != null) {
      final Map<String, dynamic> upgradeConstructorData =
          requireAs<Map<String, dynamic>>(
            data['upgradeConstructor'],
            'upgradeConstructor',
          );
      upgradeConstructor = AbiEndpoint.fromMap(<String, dynamic>{
        'name': 'upgradeConstructor',
        ...upgradeConstructorData,
      }, typeFactory: factory);
    }

    final List<dynamic> endpointsList =
        optionalAs<List<dynamic>>(data['endpoints'], 'endpoints') ??
        <dynamic>[];
    final AbiEndpoints endpoints = AbiEndpoints.fromMaps(
      endpointsList.cast<Map<String, dynamic>>(),
      typeFactory: factory,
    );

    final List<dynamic> eventsList =
        optionalAs<List<dynamic>>(data['events'], 'events') ?? <dynamic>[];
    final EventDefinitions events = EventDefinitions.fromMaps(
      eventsList.cast<Map<String, dynamic>>(),
      typeFactory: factory,
    );

    final Map<String, dynamic> metadata = Map<String, dynamic>.from(data);
    metadata.removeWhere(
      (String key, dynamic value) =>
          key == 'name' ||
          key == 'version' ||
          key == 'constructor' ||
          key == 'upgradeConstructor' ||
          key == 'endpoints' ||
          key == 'events' ||
          key == 'types',
    );

    return SmartContractAbi(
      name: name,
      version: version,
      constructor: constructor,
      upgradeConstructor: upgradeConstructor,
      endpoints: endpoints,
      events: events,
      types: types,
      metadata: metadata,
    );
  }

  /// Contract name.
  final String name;

  /// ABI format version.
  final String version;

  /// Constructor endpoint (for deploy operations), null if not defined.
  final AbiEndpoint? constructor;

  /// Upgrade constructor endpoint (for upgrade operations), null if not defined.
  final AbiEndpoint? upgradeConstructor;

  /// Contract endpoints (functions).
  final AbiEndpoints endpoints;

  /// Contract events.
  final EventDefinitions events;

  /// Custom type definitions (enums, structs).
  final Map<String, AbiType> types;

  /// Additional contract metadata.
  final Map<String, dynamic> metadata;

  /// Gets endpoint by name, returns null if not found.
  AbiEndpoint? getEndpoint(SmartContractFunction endpointName) {
    return endpoints.getByName(endpointName.name);
  }

  /// Checks if endpoint exists.
  bool hasEndpoint(SmartContractFunction endpointName) {
    return endpoints.hasEndpoint(endpointName.name);
  }

  /// Whether contract has constructor defined.
  bool get hasConstructor => constructor != null;

  /// Whether contract has upgrade constructor defined.
  bool get hasUpgradeConstructor => upgradeConstructor != null;

  /// Gets event by identifier, returns null if not found.
  EventDefinition? getEvent(String eventIdentifier) {
    return events.getByIdentifier(eventIdentifier);
  }

  /// Checks if event exists.
  bool hasEvent(String eventIdentifier) {
    return events.hasEvent(eventIdentifier);
  }

  /// All view (read-only) endpoints.
  List<AbiEndpoint> get viewEndpoints => endpoints.viewEndpoints;

  /// All mutable (state-changing) endpoints.
  List<AbiEndpoint> get mutableEndpoints => endpoints.mutableEndpoints;

  /// All payable endpoints (can receive EGLD).
  List<AbiEndpoint> get payableEndpoints => endpoints.payableEndpoints;

  /// Total number of endpoints.
  int get endpointCount => endpoints.length;

  /// Whether ABI has no endpoints.
  bool get isEmpty => endpoints.isEmpty;

  /// Whether ABI has endpoints.
  bool get isNotEmpty => endpoints.isNotEmpty;

  /// Gets custom type by name, returns null if not found.
  AbiType? getCustomType(String typeName) {
    return types[typeName];
  }

  /// Gets enum type by name, returns null if not found.
  ///
  /// #### Throws
  /// `StateError` if type exists but is not an enum.
  EnumType? getEnum(String typeName) {
    final AbiType? type = types[typeName];
    if (type == null) return null;
    return type.requireType<EnumType>('Type "$typeName" is not an enum type');
  }

  /// Gets struct type by name, returns null if not found.
  ///
  /// #### Throws
  /// `StateError` if type exists but is not a struct.
  StructType? getStruct(String typeName) {
    final AbiType? type = types[typeName];
    if (type == null) return null;
    return type.requireType<StructType>(
      'Type "$typeName" is not a struct type',
    );
  }

  /// Checks if custom type exists.
  bool hasCustomType(String typeName) {
    return types.containsKey(typeName);
  }

  /// Total number of custom types.
  int get customTypeCount => types.length;

  /// Validates input parameters for specific endpoint.
  ///
  /// Returns true if inputs are valid, false if endpoint doesn't exist or
  /// inputs are invalid.
  bool validateInputs(
    SmartContractFunction endpointName,
    List<dynamic> inputs,
  ) {
    final AbiEndpoint? endpoint = getEndpoint(endpointName);
    if (endpoint == null) {
      return false;
    }
    return endpoint.areInputsValid(inputs);
  }

  /// Creates copy with updated properties.
  SmartContractAbi copyWith({
    String? name,
    String? version,
    AbiEndpoint? constructor,
    AbiEndpoint? upgradeConstructor,
    AbiEndpoints? endpoints,
    EventDefinitions? events,
    Map<String, AbiType>? types,
    Map<String, dynamic>? metadata,
  }) {
    return SmartContractAbi(
      name: name ?? this.name,
      version: version ?? this.version,
      constructor: constructor ?? this.constructor,
      upgradeConstructor: upgradeConstructor ?? this.upgradeConstructor,
      endpoints: endpoints ?? this.endpoints,
      events: events ?? this.events,
      types: types ?? this.types,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Converts ABI to map representation for JSON serialization.
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> result = <String, dynamic>{
      'name': name,
      'version': version,
      if (constructor != null) 'constructor': constructor!.toMap(),
      if (upgradeConstructor != null)
        'upgradeConstructor': upgradeConstructor!.toMap(),
      'endpoints': endpoints.toMaps(),
      if (events.isNotEmpty) 'events': events.toMaps(),
      if (types.isNotEmpty)
        'types': types.map(
          (String key, AbiType value) =>
              MapEntry<String, Map<String, dynamic>>(key, value.toMap()),
        ),
    };

    result.addAll(metadata);

    return result;
  }

  /// Converts ABI to JSON string with optional indentation.
  String toJson({String? indent}) {
    final Map<String, dynamic> map = toMap();
    if (indent != null) {
      final JsonEncoder encoder = JsonEncoder.withIndent(indent);
      return encoder.convert(map);
    }
    return jsonEncode(map);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartContractAbi &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          version == other.version &&
          constructor == other.constructor &&
          upgradeConstructor == other.upgradeConstructor &&
          endpoints == other.endpoints &&
          events == other.events &&
          CollectionUtils.mapEquals(types, other.types) &&
          CollectionUtils.mapEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
    name,
    version,
    constructor,
    upgradeConstructor,
    endpoints,
    events,
    Object.hashAll(types.entries),
    Object.hashAll(metadata.entries),
  );

  @override
  String toString() {
    final List<String> parts = <String>[
      '$name v$version',
      if (constructor != null) 'has constructor',
      if (upgradeConstructor != null) 'has upgradeConstructor',
      '${endpoints.length} endpoints',
      if (events.isNotEmpty) '${events.length} events',
    ];
    return 'SmartContractAbi{${parts.join(', ')}}';
  }
}

/// Registry for loading and managing multiple contract ABIs.
///
/// Centralized storage for ABIs of multiple contracts. Useful when
/// working with multiple contracts in an application, allowing quick lookup
/// and management of contract interfaces.
///
/// #### Example
/// ```dart
/// // Create registry
/// final registry = AbiRegistry();
///
/// // Register ABIs
/// registry.register('TokenContract', tokenAbi);
/// registry.register('NFTContract', nftAbi);
/// registry.loadFromJson('StakingContract', stakingAbiJson);
///
/// // Query ABIs
/// final tokenAbi = registry.getAbi('TokenContract');
/// if (registry.hasAbi('NFTContract')) {
///   print('NFT ABI is registered');
/// }
///
/// // List all
/// for (final name in registry.contractNames) {
///   print('Contract: $name');
/// }
///
/// // Clean up
/// registry.remove('TokenContract');
/// registry.clear(); // Remove all
/// ```
class AbiRegistry {
  /// Creates empty ABI registry.
  ///
  /// Initializes a new registry with no ABIs. Use [register] or
  /// [loadFromJson] to add ABIs.
  ///
  /// #### Example
  /// ```dart
  /// final registry = AbiRegistry();
  /// print(registry.isEmpty); // true
  /// ```
  AbiRegistry();

  /// Creates registry with initial ABIs.
  ///
  /// #### Parameters
  /// - `abis` - Map of contract names to SmartContractAbi instances
  ///
  /// #### Example
  /// ```dart
  /// final registry = AbiRegistry.withAbis({
  ///   'Token': tokenAbi,
  ///   'NFT': nftAbi,
  /// });
  /// print(registry.count); // 2
  /// ```
  AbiRegistry.withAbis(Map<String, SmartContractAbi> abis) {
    _abis.addAll(abis);
  }

  final Map<String, SmartContractAbi> _abis = <String, SmartContractAbi>{};

  /// Registers ABI for contract name.
  ///
  /// #### Parameters
  /// - `contractName` - Unique identifier for the contract (non-empty)
  /// - `abi` - Smart contract ABI to register
  ///
  /// #### Throws
  /// `ArgumentError` if `contractName` is empty
  ///
  /// #### Example
  /// ```dart
  /// registry.register('MyToken', tokenAbi);
  /// registry.register('MyNFT', nftAbi); // Different contract
  /// registry.register('MyToken', updatedAbi); // Replaces existing
  /// ```
  void register(String contractName, SmartContractAbi abi) {
    if (contractName.isEmpty) {
      throw ArgumentError('Contract name cannot be empty');
    }
    _abis[contractName] = abi;
  }

  /// Loads ABI from JSON string and registers it.
  ///
  /// #### Parameters
  /// - `contractName` - Unique identifier for the contract (non-empty)
  /// - `jsonString` - ABI JSON string to parse
  ///
  /// #### Throws
  /// - `ArgumentError` if `contractName` is empty
  /// - `FormatException` if `jsonString` is invalid JSON
  ///
  /// #### Example
  /// ```dart
  /// final abiJson = '''
  /// {
  ///   "name": "MyContract",
  ///   "endpoints": [...]
  /// }
  /// ''';
  /// registry.loadFromJson('MyContract', abiJson);
  /// ```
  void loadFromJson(String contractName, String jsonString) {
    final SmartContractAbi abi = SmartContractAbi.fromJson(jsonString);
    register(contractName, abi);
  }

  /// Gets ABI by contract name, returns null if not found.
  SmartContractAbi? getAbi(String contractName) {
    return _abis[contractName];
  }

  /// Checks if ABI is registered.
  bool hasAbi(String contractName) {
    return _abis.containsKey(contractName);
  }

  /// All registered contract names.
  List<String> get contractNames => _abis.keys.toList();

  /// All registered ABIs.
  List<SmartContractAbi> get abis => _abis.values.toList();

  /// Number of registered ABIs.
  int get count => _abis.length;

  /// Whether registry is empty.
  bool get isEmpty => _abis.isEmpty;

  /// Whether registry has ABIs.
  bool get isNotEmpty => _abis.isNotEmpty;

  /// Removes ABI, returns removed ABI or null if not found.
  SmartContractAbi? remove(String contractName) {
    return _abis.remove(contractName);
  }

  /// Clears all ABIs.
  void clear() {
    _abis.clear();
  }

  @override
  String toString() => 'AbiRegistry{${_abis.length} ABIs}';
}
