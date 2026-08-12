/// Regression tests for the emitted event-decoding path.
///
/// The polling streams used to pull a single ABI field out of the parsed
/// event — a field name guessed as `<identifier>_event` — and hand that
/// nested struct to `<Event>.fromAbi`. The event model, however, is built
/// from *all* event inputs (indexed topics plus the data struct), so the
/// nested struct is missing every topic field and decoding threw
/// `ArgumentError: Field not found: <topic>` on every event received.
///
/// The generated code still compiled, so `dart analyze` never caught it.
/// These tests pin the emission to `EventConverter.convertEvent`, which
/// reconstructs the complete event value the model expects.
library;

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

import '../../bin/codegen/core/name_sanitizer.dart';
import '../../bin/codegen/core/type_mapper.dart';
import '../../bin/codegen/generators/events_generator.dart';
import '../../bin/codegen/models/file_output.dart';

void main() {
  group('EventsGenerator / event decoding', () {
    /// Two events, each with indexed topics plus a trailing data struct —
    /// the shape that broke. Two events also trigger the multi-event
    /// polling stream, which had the same defect in two more places.
    const String abiJson = '''
    {
      "name": "EventProbe",
      "endpoints": [],
      "events": [
        {
          "identifier": "swap",
          "inputs": [
            {"name": "token_in", "type": "TokenIdentifier", "indexed": true},
            {"name": "caller", "type": "Address", "indexed": true},
            {"name": "swap_event", "type": "SwapEvent"}
          ]
        },
        {
          "identifier": "deposit",
          "inputs": [
            {"name": "depositor", "type": "Address", "indexed": true},
            {"name": "payload", "type": "SwapEvent"}
          ]
        }
      ],
      "types": {
        "SwapEvent": {
          "type": "struct",
          "fields": [
            {"name": "amount", "type": "BigUint"}
          ]
        }
      }
    }
    ''';

    List<FileOutput> runGenerator() {
      final SmartContractAbi abi = SmartContractAbi.fromJson(abiJson);
      return EventsGenerator(
        abi: abi,
        typeMapper: TypeMapper(),
        nameSanitizer: NameSanitizer(),
      ).generate();
    }

    test('no emitted file decodes via a guessed event-struct field', () {
      for (final FileOutput file in runGenerator()) {
        expect(
          file.content.contains('getValueByName('),
          isFalse,
          reason:
              '${file.path} decodes the event from a single guessed field. '
              'The event model is built from every event input, so the '
              'nested struct is missing all indexed topics and decoding '
              'throws ArgumentError at runtime.',
        );
      }
    });

    test('polling streams decode through EventConverter.convertEvent', () {
      final Iterable<FileOutput> pollingFiles = runGenerator().where(
        (FileOutput f) => f.path.contains('polling_events/'),
      );

      expect(pollingFiles, isNotEmpty);

      for (final FileOutput file in pollingFiles) {
        expect(
          file.content,
          contains('EventConverter.convertEvent<'),
          reason:
              '${file.path} must rebuild the whole event value before '
              'calling fromAbi, exactly as the WebSocket streams do.',
        );
      }
    });

    test('multi-event polling stream decodes every event the same way', () {
      final FileOutput multi = runGenerator().firstWhere(
        (FileOutput f) => f.path.contains('polling_stream'),
        orElse: () => throw StateError('multi-event polling stream not found'),
      );

      expect(
        'EventConverter.convertEvent<'.allMatches(multi.content).length,
        greaterThanOrEqualTo(4),
        reason:
            'Both the per-event getters and the combined `all` stream must '
            'use the converter — there are 2 events, so at least 4 sites.',
      );
    });
  });

  group('EventsGenerator / documentation escaping', () {
    /// Contract docs routinely name generic types. Copied verbatim into a
    /// `///` comment they read as HTML tags, which mangles the rendered
    /// docs and trips `unintended_html_in_doc_comment` in the user's
    /// project.
    const String abiJson = '''
    {
      "name": "DocProbe",
      "endpoints": [],
      "events": [
        {
          "identifier": "emitted",
          "docs": [
            "Takes a ManagedVec<ManagedBuffer> of payloads.",
            "Already backticked: `Option<u64>` stays literal."
          ],
          "inputs": [{"name": "value", "type": "u32"}]
        }
      ],
      "types": {}
    }
    ''';

    test('angle brackets outside code spans are escaped', () {
      final SmartContractAbi abi = SmartContractAbi.fromJson(abiJson);
      final List<FileOutput> files = EventsGenerator(
        abi: abi,
        typeMapper: TypeMapper(),
        nameSanitizer: NameSanitizer(),
      ).generate();

      /// Only the per-event streams carry the event's own documentation;
      /// the aggregate multi-event files document themselves instead.
      final Iterable<FileOutput> perEvent = files.where(
        (FileOutput f) =>
            f.path.contains('polling_events/') ||
            f.path.contains('websocket_events/'),
      );

      expect(perEvent, isNotEmpty);

      for (final FileOutput file in perEvent) {
        expect(
          file.content,
          contains('ManagedVec&lt;ManagedBuffer&gt;'),
          reason: '${file.path} must escape angle brackets in contract prose.',
        );
        expect(
          file.content,
          contains('`Option<u64>`'),
          reason:
              '${file.path} must leave backticked code spans alone — markdown '
              'renders them literally, so escaping would show `&lt;` to the '
              'reader.',
        );
      }
    });
  });
}
