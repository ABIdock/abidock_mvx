/// Regression tests for `multi<...>` expansion in [ArgumentEncoder].
///
/// A `multi<A,B>` argument occupies one top-level wire slot per member. The
/// encoder reached from the smart-contract controller previously had no branch
/// for [MultiValueValue], so the value fell through to the plain-value path and
/// its members were concatenated into a single slot. The contract then received
/// one argument where it expected two, with no error raised anywhere.
///
/// [ArgSerializer] always expanded correctly, so the two encoders disagreed;
/// these tests assert both against the same literal expectation.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// `WEGLD-bd4d79` as ASCII hex, the first member's top-level encoding.
const String wegldHex = '5745474c442d626434643739';

/// `10` as a top-level BigUint: minimal big-endian bytes.
const String tenHex = '0a';

void main() {
  MultiValueValue buildMulti() {
    final MultiValueType type = MultiValueType(2, <AbiType>[
      TokenIdentifierType.type,
      BigUIntType.type,
    ]);
    return MultiValueValue(type, <TypedValue>[
      TokenIdentifierValue('WEGLD-bd4d79'),
      BigUIntValue(BigInt.from(10)),
    ]);
  }

  ArgumentEncoder buildEncoder() => ArgumentEncoder(
    serializer: ArgSerializer(),
    resolver: EndpointResolver(const SmartContractAbi.empty()),
  );

  group('ArgumentEncoder expands multi<...> into one slot per member', () {
    test('a two-member multi produces two slots', () {
      final List<String> encoded = buildEncoder().encodeTypedValues(
        <TypedValue>[buildMulti()],
      );

      expect(encoded, equals(<String>[wegldHex, tenHex]));
    });

    test('members are not concatenated into a single slot', () {
      final List<String> encoded = buildEncoder().encodeTypedValues(
        <TypedValue>[buildMulti()],
      );

      expect(encoded, hasLength(2));
      expect(encoded.first, isNot(contains(tenHex)));
    });

    test('agrees with ArgSerializer for the same value', () {
      final List<String> viaSerializer = ArgSerializer()
          .valuesToString(<TypedValue>[buildMulti()])
          .argumentsString
          .split('@');
      final List<String> viaEncoder = buildEncoder().encodeTypedValues(
        <TypedValue>[buildMulti()],
      );

      expect(viaEncoder, equals(viaSerializer));
    });

    test('a multi nested inside a variadic expands member by member', () {
      final MultiValueValue first = buildMulti();
      final VariadicValue variadic = VariadicValue(<TypedValue>[
        first,
        buildMulti(),
      ], itemType: first.type);

      final List<String> encoded = buildEncoder().encodeTypedValues(
        <TypedValue>[variadic],
      );

      expect(encoded, equals(<String>[wegldHex, tenHex, wegldHex, tenHex]));
    });
  });
}
