import 'package:meta/meta.dart';

import '../../utils/collection_utils.dart';
import '../../utils/helpers.dart';
import 'types.dart';

/// Smart contract event definition from ABI.
///
/// Represents an event with typed topics/fields.
@immutable
final class EventDefinition {
  /// Creates event definition.
  ///
  /// #### Parameters
  /// - `identifier` - Event name/identifier (required)
  /// - `inputs` - Topics/fields (default: empty)
  /// - `documentation` - Optional docs
  const EventDefinition({
    required this.identifier,
    this.inputs = const <EventTopicDefinition>[],
    this.documentation,
  });

  /// Creates event definition with no inputs.
  ///
  /// #### Parameters
  /// - `identifier` - Event name (required)
  /// - `documentation` - Optional docs
  const EventDefinition.empty({required this.identifier, this.documentation})
    : inputs = const <EventTopicDefinition>[];

  /// Creates event definition from JSON map.
  ///
  /// #### Parameters
  /// - `data` - Map with 'identifier', 'inputs', optional 'docs'
  /// - `typeFactory` - Optional AbiTypeFactory for custom type resolution
  factory EventDefinition.fromMap(
    Map<String, dynamic> data, {
    AbiTypeFactory? typeFactory,
  }) {
    final String identifier =
        optionalAs<String>(data['identifier'], 'identifier') ?? '?';
    final List<dynamic> inputsList =
        optionalAs<List<dynamic>>(data['inputs'], 'inputs') ?? <dynamic>[];

    final List<EventTopicDefinition> inputs = inputsList
        .cast<Map<String, dynamic>>()
        .map(
          (Map<String, dynamic> map) =>
              EventTopicDefinition.fromMap(map, typeFactory: typeFactory),
        )
        .toList();

    final List<dynamic>? docs = optionalAs<List<dynamic>>(data['docs'], 'docs');
    final String? documentation =
        optionalAs<String>(data['documentation'], 'documentation') ??
        (docs != null && docs.isNotEmpty ? docs.join('\n') : null);

    return EventDefinition(
      identifier: identifier,
      inputs: inputs,
      documentation: documentation,
    );
  }

  /// Event identifier/name.
  final String identifier;

  /// Input topics/fields for this event.
  final List<EventTopicDefinition> inputs;

  /// Optional documentation.
  final String? documentation;

  /// Number of inputs.
  int get inputCount => inputs.length;

  /// Whether event has inputs.
  bool get hasInputs => inputs.isNotEmpty;

  /// Whether event has no inputs.
  bool get isEmpty => inputs.isEmpty;

  /// Gets indexed topics for efficient filtering.
  List<EventTopicDefinition> get indexedTopics =>
      inputs.where((EventTopicDefinition input) => input.indexed).toList();

  /// Gets non-indexed data fields.
  List<EventTopicDefinition> get dataFields =>
      inputs.where((EventTopicDefinition input) => !input.indexed).toList();

  /// Number of indexed topics.
  int get indexedCount => indexedTopics.length;

  /// Number of non-indexed data fields.
  int get dataCount => dataFields.length;

  /// Gets input by name, returns null if not found.
  ///
  /// #### Parameters
  /// - `name` - Input/topic name to find
  ///
  /// #### Returns
  /// `EventTopicDefinition?` - Topic definition or null
  EventTopicDefinition? getInput(String name) {
    try {
      return inputs.firstWhere(
        (EventTopicDefinition input) => input.name == name,
      );
    } catch (e) {
      return null;
    }
  }

  /// Checks if event has input with given name.
  ///
  /// #### Parameters
  /// - `name` - Input name to check
  ///
  /// #### Returns
  /// `bool` - True if input exists
  bool hasInput(String name) => getInput(name) != null;

  /// Converts to map.
  ///
  /// #### Returns
  /// JSON-like map representation
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'identifier': identifier,
      'inputs': inputs
          .map((EventTopicDefinition input) => input.toMap())
          .toList(),
      if (documentation != null) 'documentation': documentation,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventDefinition &&
          runtimeType == other.runtimeType &&
          identifier == other.identifier &&
          CollectionUtils.listEquals(inputs, other.inputs) &&
          documentation == other.documentation;

  @override
  int get hashCode =>
      Object.hash(identifier, Object.hashAll(inputs), documentation);

  @override
  String toString() {
    final String inputsStr = inputs
        .map((EventTopicDefinition i) => i.toString())
        .join(', ');
    return 'event $identifier($inputsStr)';
  }
}

/// Event topic (field) definition.
///
/// Defines a single topic/field in an event.
@immutable
final class EventTopicDefinition {
  /// Creates event topic definition.
  ///
  /// #### Parameters
  /// - `name` - Topic/field name (required)
  /// - `type` - Data type (required)
  /// - `indexed` - Whether indexed for filtering (default: false)
  /// - `documentation` - Optional docs
  const EventTopicDefinition({
    required this.name,
    required this.type,
    this.indexed = false,
    this.documentation,
  });

  /// Creates event topic definition from JSON map.
  ///
  /// #### Parameters
  /// - `data` - Map with 'name', 'type', optional 'indexed'
  /// - `typeFactory` - Optional AbiTypeFactory for custom type resolution
  factory EventTopicDefinition.fromMap(
    Map<String, dynamic> data, {
    AbiTypeFactory? typeFactory,
  }) {
    final String name = optionalAs<String>(data['name'], 'name') ?? '?';
    final String typeString =
        optionalAs<String>(data['type'], 'type') ?? 'bytes';
    final bool indexed = optionalAs<bool>(data['indexed'], 'indexed') ?? false;

    final AbiTypeFactory factory = typeFactory ?? AbiTypeFactory();
    final AbiType type = factory.fromString(typeString);

    final List<dynamic>? docs = optionalAs<List<dynamic>>(data['docs'], 'docs');
    final String? documentation =
        optionalAs<String>(data['documentation'], 'documentation') ??
        (docs != null && docs.isNotEmpty ? docs.join('\n') : null);

    return EventTopicDefinition(
      name: name,
      type: type,
      indexed: indexed,
      documentation: documentation,
    );
  }

  /// Topic/field name.
  final String name;

  /// Data type in this topic.
  final AbiType type;

  /// Whether indexed for filtering.
  final bool indexed;

  /// Optional documentation.
  final String? documentation;

  /// Converts to field definition.
  ///
  /// #### Returns
  /// `FieldDefinition` - For struct fields
  FieldDefinition toFieldDefinition() {
    return FieldDefinition(name: name, type: type, description: documentation);
  }

  /// Converts to map.
  ///
  /// #### Returns
  /// `Map<String, dynamic>` - JSON-like map representation
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'type': type.fullyQualifiedName,
      'indexed': indexed,
      if (documentation != null) 'documentation': documentation,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventTopicDefinition &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          type.equals(other.type) &&
          indexed == other.indexed;

  @override
  int get hashCode => Object.hash(name, type.fullyQualifiedName, indexed);

  @override
  String toString() {
    final String indexedStr = indexed ? 'indexed ' : '';
    return '$indexedStr${type.fullyQualifiedName} $name';
  }
}

/// Collection of event definitions for smart contract.
///
/// Manages all event definitions.
@immutable
final class EventDefinitions extends Iterable<EventDefinition> {
  /// Creates collection of event definitions.
  const EventDefinitions(this._items);

  /// Creates empty collection.
  const EventDefinitions.empty() : _items = const <EventDefinition>[];

  @override
  Iterator<EventDefinition> get iterator => _items.iterator;

  /// Creates from list of maps.
  ///
  /// #### Parameters
  /// - `maps` - List of JSON-like maps
  /// - `typeFactory` - Optional AbiTypeFactory for custom type resolution
  factory EventDefinitions.fromMaps(
    List<Map<String, dynamic>> maps, {
    AbiTypeFactory? typeFactory,
  }) {
    final List<EventDefinition> events = maps
        .map(
          (Map<String, dynamic> map) =>
              EventDefinition.fromMap(map, typeFactory: typeFactory),
        )
        .toList();
    return EventDefinitions(events);
  }

  /// Internal list of events.
  final List<EventDefinition> _items;

  /// Gets event at index.
  EventDefinition operator [](int index) => _items[index];

  /// Gets event by identifier, returns null if not found.
  ///
  /// #### Parameters
  /// - `identifier` - Event identifier/name
  ///
  /// #### Returns
  /// `EventDefinition?` - Event definition or null
  EventDefinition? getByIdentifier(String identifier) {
    try {
      return _items.firstWhere(
        (EventDefinition e) => e.identifier == identifier,
      );
    } catch (e) {
      final String alternativeIdentifier = _convertNamingConvention(identifier);
      try {
        return _items.firstWhere(
          (EventDefinition e) => e.identifier == alternativeIdentifier,
        );
      } catch (e) {
        return null;
      }
    }
  }

  String _convertNamingConvention(String identifier) {
    if (identifier.contains('_')) {
      final List<String> parts = identifier.split('_');
      return parts.first +
          parts
              .skip(1)
              .map(
                (String p) =>
                    p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1),
              )
              .join();
    }
    return identifier.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (Match match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  /// Checks if event with identifier exists.
  ///
  /// #### Parameters
  /// - `identifier` - Event identifier to check
  ///
  /// #### Returns
  /// `bool` - True if event exists
  bool hasEvent(String identifier) => getByIdentifier(identifier) != null;

  /// Gets all event identifiers.
  ///
  /// #### Returns
  /// `List<String>` - List of event names
  List<String> get identifiers =>
      _items.map((EventDefinition e) => e.identifier).toList();

  /// Converts to list of maps.
  ///
  /// #### Returns
  /// `List<Map<String, dynamic>>` - List of JSON-like maps
  List<Map<String, dynamic>> toMaps() {
    return _items.map((EventDefinition e) => e.toMap()).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventDefinitions &&
          runtimeType == other.runtimeType &&
          CollectionUtils.listEquals(_items, other._items);

  @override
  int get hashCode => Object.hashAll(_items);

  @override
  String toString() => 'EventDefinitions{${_items.length} events}';
}
