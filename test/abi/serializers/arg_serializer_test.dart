import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  final serializer = ArgSerializer();

  group('String to Buffers', () {
    test('parses hex strings', () {
      final buffers = serializer.stringToBuffers('2a@ff@00');
      expect(buffers, hasLength(3));
      expect(buffers[0], [0x2a]);
      expect(buffers[1], [0xff]);
      expect(buffers[2], [0x00]);

      final single = serializer.stringToBuffers('0000002a');
      expect(single, hasLength(1));
      expect(single[0], [0, 0, 0, 0x2a]);
    });

    test('handles special formats', () {
      final withSpaces = serializer.stringToBuffers('00 00 00 2a');
      expect(withSpaces[0], [0, 0, 0, 0x2a]);

      final withPrefix = serializer.stringToBuffers('0x2a');
      expect(withPrefix[0], [0x2a]);

      final oddLength = serializer.stringToBuffers('fff');
      expect(oddLength[0], [0x0f, 0xff]);

      final empty = serializer.stringToBuffers('');
      expect(empty[0], isEmpty);
    });

    test('validates separator constant', () {
      expect(ArgSerializer.argumentsSeparator, '@');
      const result = '2a@ff@00';
      final parts = result.split(ArgSerializer.argumentsSeparator);
      expect(parts, hasLength(3));
    });
  });

  group('Type Creation', () {
    test('creates primitive types', () {
      final u32Values = serializer.createTypedValues([42], ['u32']);
      expect(u32Values[0], isA<U32Value>());
      expect((u32Values[0] as U32Value).nativeValue, 42);

      final stringValues = serializer.createTypedValues(['hello'], ['string']);
      expect(stringValues[0], isA<StringValue>());
      expect((stringValues[0] as StringValue).nativeValue, 'hello');

      final boolValues = serializer.createTypedValues([true], ['bool']);
      expect(boolValues[0], isA<BooleanValue>());
      expect((boolValues[0] as BooleanValue).nativeValue, isTrue);
    });

    test('creates multiple values', () {
      final values = serializer.createTypedValues(
        [42, 'test', false],
        ['u32', 'string', 'bool'],
      );
      expect(values, hasLength(3));
      expect(values[0], isA<U32Value>());
      expect(values[1], isA<StringValue>());
      expect(values[2], isA<BooleanValue>());
    });

    test('handles BigInt types', () {
      final values = serializer.createTypedValues([BigInt.from(1000)], ['u64']);
      expect(values, hasLength(1));
      expect(values[0], isA<U64Value>());
    });

    test('validates input consistency', () {
      expect(
        () => serializer.createTypedValues([1, 2], ['u32']),
        throwsA(isA<AbiArgumentSerializationException>()),
      );

      expect(
        () => serializer.createTypedValues([1], ['invalid_type']),
        throwsA(isA<AbiArgumentSerializationException>()),
      );
    });
  });

  group('Validation', () {
    test('validates correct arguments', () {
      expect(
        serializer.validateArguments(
          [42, 'test', true],
          ['u32', 'string', 'bool'],
        ),
        isTrue,
      );
      expect(
        serializer.validateArguments([BigInt.from(1000)], ['u64']),
        isTrue,
      );
      expect(
        serializer.validateArguments([1, 2, 3], ['u8', 'u16', 'u32']),
        isTrue,
      );
    });

    test('rejects invalid inputs', () {
      expect(serializer.validateArguments([42], ['u32', 'string']), isFalse);
      expect(serializer.validateArguments([42], ['not_a_type']), isFalse);
    });
  });

  group('Data Classes', () {
    test('ParameterDefinition works correctly', () {
      final withName = ParameterDefinition(U32Type.type, 'amount');
      expect(withName.type, U32Type.type);
      expect(withName.name, 'amount');

      final withoutName = ParameterDefinition(StringType.type);
      expect(withoutName.type, StringType.type);
      expect(withoutName.name, isNull);
    });

    test('ValuesToStringResult works correctly', () {
      const result = ValuesToStringResult(
        argumentsString: '2a@ff@00',
        count: 3,
      );
      expect(result.argumentsString, '2a@ff@00');
      expect(result.count, 3);

      const empty = ValuesToStringResult(argumentsString: '', count: 0);
      expect(empty.argumentsString, isEmpty);
      expect(empty.count, 0);
    });
  });

  group('Exception Handling', () {
    test('AbiArgumentSerializationException works correctly', () {
      const simple = AbiArgumentSerializationException('test error');
      expect(simple.message, 'test error');
      expect(simple.cause, isNull);
      expect(simple.toString(), contains('test error'));

      final cause = Exception('root cause');
      final withCause = AbiArgumentSerializationException(
        'test error',
        cause: cause,
      );
      expect(withCause.message, 'test error');
      expect(withCause.cause, cause);
      expect(
        withCause.toString(),
        contains('AbiArgumentSerializationException'),
      );
    });
  });

  group('Edge Cases', () {
    test('handles boundary values', () {
      final zero = serializer.createTypedValues([0], ['u32']);
      expect((zero[0] as U32Value).nativeValue, 0);

      final max = serializer.createTypedValues([4294967295], ['u32']);
      expect((max[0] as U32Value).nativeValue, 4294967295);

      final emptyString = serializer.createTypedValues([''], ['string']);
      expect((emptyString[0] as StringValue).nativeValue, '');

      final large = BigInt.parse('9223372036854775807');
      final largeValue = serializer.createTypedValues([large], ['u64']);
      expect((largeValue[0] as U64Value).nativeValue, large);
    });

    test('type formulas are case sensitive', () {
      final values = serializer.createTypedValues([42], ['u32']);
      expect(values[0], isA<U32Value>());

      expect(
        () => serializer.createTypedValues([42], ['U32']),
        throwsA(isA<AbiArgumentSerializationException>()),
      );
    });
  });
}
