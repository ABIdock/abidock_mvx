import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

void main() {
  group('VariadicBuilder', () {
    test('should create and build variadics with values', () {
      final builder = VariadicBuilder<U32Type>(U32Type.type);
      expect(builder.isEmpty, true);
      expect(builder.count, 0);

      final variadic = builder.add(10).add(20).add(30).build();
      expect(variadic.length, 3);
      expect(variadic[0].nativeValue, 10);
      expect(variadic[1].nativeValue, 20);
      expect(variadic[2].nativeValue, 30);
      expect(builder.count, 3);
    });

    test('should support different types and typed values', () {
      final u64Variadic = VariadicBuilder<U64Type>(U64Type.type)
          .add(100)
          .build();
      expect(u64Variadic.itemType, U64Type.type);

      final stringVariadic = VariadicBuilder<StringType>(StringType.type)
          .addTyped(StringValue('hello'))
          .addTyped(StringValue('world'))
          .build();
      expect(stringVariadic.itemType, StringType.type);
      expect(stringVariadic.length, 2);

      expect(
        () =>
            VariadicBuilder<U32Type>(U32Type.type)
                .addTyped(U64Value(BigInt.from(10))),
        throwsArgumentError,
      );
    });

    test('should support bulk operations and clear', () {
      final builder = VariadicBuilder<U32Type>(U32Type.type);
      final variadic = builder.addAll([10, 20, 30]).addAllTyped([
        U32Value(40),
        U32Value(50),
      ]).build();

      expect(variadic.length, 5);
      expect(variadic.items.map((v) => v.nativeValue).toList(), [
        10,
        20,
        30,
        40,
        50,
      ]);

      builder.clear();
      expect(builder.isEmpty, true);
      expect(builder.count, 0);
    });

    test('should create counted variadics and extension methods', () {
      final countedVariadic = VariadicBuilder<U32Type>(U32Type.type)
          .add(10)
          .buildCounted();
      expect(countedVariadic.isCounted, true);

      final builder = VariadicBuilder<U32Type>(U32Type.type);
      final pushed = builder.push(42);
      expect(pushed.nativeValue, 42);

      final conditional = VariadicBuilder<U32Type>(U32Type.type)
          .addIf(true, 10)
          .addIf(false, 20)
          .repeat(30, 2)
          .build();
      expect(conditional.items.map((v) => v.nativeValue).toList(), [
        10,
        30,
        30,
      ]);
    });

    test('should handle real-world scenarios with addresses and tokens', () {
      final recipients = VariadicBuilder<AddressType>(AddressType.type)
          .add('erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th')
          .add('erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx')
          .build();
      expect(recipients.length, 2);
      expect(recipients.itemType, AddressType.type);

      final amounts = VariadicBuilder<BigUIntType>(BigUIntType.type)
          .add(BigInt.from(1000000))
          .add(BigInt.from(2000000))
          .build();
      expect(amounts.length, 2);
      expect(amounts[0].nativeValue, BigInt.from(1000000));

      final empty = VariadicBuilder<U32Type>(U32Type.type).build();
      expect(empty.isEmpty, true);
    });
  });
}
