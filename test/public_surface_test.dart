/// Guards the package's public surface.
///
/// This file imports **only** `package:abidock_mvx/abidock_mvx.dart` — never a
/// `src/` path — and names at least one type from every subsystem. A type that
/// stops being re-exported from the barrel therefore breaks this test instead
/// of breaking a downstream build.
///
/// When you add a subsystem, add a group here. When a symbol here disappears,
/// decide deliberately: re-export it, or delete the assertion.
library;

import 'dart:typed_data';

import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

const String _aliceBech32 =
    'erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th';
const String _bobBech32 =
    'erd12m6dwylyqvz3282j857mldsdrfln476ww7k3kmpq0f0h7pvhl8qs4ucen5';
const String _pairContractBech32 =
    'erd1qqqqqqqqqqqqqpgqzw0d0tj25qme9e4ukverjjjqle6xamay0n4s5r0v9g';

void main() {
  group('core primitives', () {
    test('Address, Balance, Nonce, ChainId and Signature are reachable', () {
      final Address alice = Address.fromBech32(_aliceBech32);
      expect(alice.bech32, _aliceBech32);

      final Balance oneEgld = Balance.fromEgld(1);
      expect(oneEgld.value, BigInt.from(10).pow(18));

      const Nonce nonce = Nonce(7);
      expect(nonce.value, 7);

      const ChainId devnet = ChainId.devnet();
      expect(devnet.value, 'D');

      const Signature empty = Signature.empty();
      expect(empty.isEmpty, isTrue);
    });

    test('CodeMetadata decodes the account wire bitmap', () {
      const CodeMetadata metadata = CodeMetadata(
        isUpgradeable: true,
        isReadable: true,
      );
      expect(CodeMetadata.fromBytes(metadata.toBytes()), metadata);
    });

    test('token models and TokenComputer are reachable', () {
      final Token token = Token(identifier: 'FOO-abcdef');
      expect(token.nonce, BigInt.zero);

      const TokenIdentifier identifier = TokenIdentifier('FOO-abcdef');
      expect(identifier.isEgld, isFalse);

      final EgldOrEsdtTokenIdentifier egld = EgldOrEsdtTokenIdentifier.egld();
      expect(egld.value, egldIdentifier);

      const TokenComputer computer = TokenComputer();
      expect(computer.isFungible(token), isTrue);
    });

    test('Message and MessageComputer are reachable', () {
      final Message message = Message('Hello World'.codeUnits);
      const MessageComputer computer = MessageComputer();
      expect(computer.computeBytesForSigning(message), isNotEmpty);
    });
  });

  group('transactions', () {
    test('Transaction, TransactionComputer and status types are reachable', () {
      final Transaction transaction = Transaction(
        nonce: const Nonce(0),
        sender: Address.fromBech32(_aliceBech32),
        receiver: Address.fromBech32(_bobBech32),
        data: Uint8List(0),
        gasLimit: const GasLimit(50000),
        gasPrice: const GasPrice(1000000000),
        chainId: const ChainId.devnet(),
        version: const TransactionVersion(2),
        value: Balance.fromEgld(1),
      );
      expect(transaction.version.value, 2);

      const TransactionComputer computer = TransactionComputer();
      expect(computer.computeBytesForSigning(transaction), isNotEmpty);

      expect(TransactionStatus.success.isSuccessful, isTrue);
    });

    test('factory configs and factories are reachable', () {
      const TransactionsFactoryConfig config = TransactionsFactoryConfig(
        chainId: ChainId.devnet(),
      );
      expect(config.minGasLimit, 50000);

      final TransferTransactionsFactory transfers = TransferTransactionsFactory(
        config: const TransferTransactionsConfig(chainId: ChainId.devnet()),
      );
      expect(transfers.config.chainId.value, 'D');

      final TokenManagementTransactionsFactory tokens =
          TokenManagementTransactionsFactory(
            config: const TokenManagementConfig(chainId: ChainId.devnet()),
          );
      expect(tokens.config.chainId.value, 'D');

      final RelayedTransactionsFactory relayed = RelayedTransactionsFactory(
        const RelayedTransactionsConfig(chainId: ChainId.devnet()),
      );
      expect(relayed.config.chainId.value, 'D');

      final GovernanceTransactionsFactory governance =
          GovernanceTransactionsFactory(
            const GovernanceTransactionsConfig(chainId: ChainId.devnet()),
          );
      expect(governance.config.chainId.value, 'D');

      final MultisigTransactionsFactory multisig = MultisigTransactionsFactory(
        const MultisigTransactionsConfig(chainId: ChainId.devnet()),
      );
      expect(multisig.config.chainId.value, 'D');

      final StakingTransactionsFactory staking = StakingTransactionsFactory(
        const StakingTransactionsConfig(chainId: ChainId.devnet()),
      );
      expect(staking.config.chainId.value, 'D');

      final ValidatorsTransactionsFactory validators =
          ValidatorsTransactionsFactory(
            const ValidatorsTransactionsConfig(chainId: ChainId.devnet()),
          );
      expect(validators.config.chainId.value, 'D');

      final AccountTransactionsFactory accounts = AccountTransactionsFactory(
        const AccountTransactionsConfig(chainId: ChainId.devnet()),
      );
      expect(accounts.config.chainId.value, 'D');

      final DelegationTransactionsFactory delegation =
          DelegationTransactionsFactory(
            const DelegationTransactionsConfig(chainId: ChainId.devnet()),
          );
      expect(delegation.config.chainId.value, 'D');

      final SmartContractTransactionsFactory contracts =
          SmartContractTransactionsFactory(
            const SmartContractTransactionsConfig(chainId: ChainId.devnet()),
          );
      expect(contracts.config.chainId.value, 'D');
    });

    test('controllers are reachable', () {
      final TransfersController controller = TransfersController(
        chainId: const ChainId.devnet(),
      );
      expect(controller.factory, isA<TransferTransactionsFactory>());
    });

    test('outcome parsers are reachable', () {
      expect(const TokenManagementOutcomeParser(), isNotNull);
      expect(const DelegationOutcomeParser(), isNotNull);
      expect(const GovernanceOutcomeParser(), isNotNull);
      expect(const SmartContractOutcomeParser(), isNotNull);
    });
  });

  group('abi', () {
    test('primitive values and their types are reachable', () {
      expect(BigUIntValue(BigInt.from(42)).value, BigInt.from(42));
      expect(U64Value(BigInt.from(7)).value, BigInt.from(7));
      expect(U32Value(7).value, 7);
      expect(BooleanValue(true).value, isTrue);
      expect(StringValue('abc').value, 'abc');
      expect(TokenIdentifierValue('FOO-abcdef').identifier, 'FOO-abcdef');
      expect(AddressValue.fromBech32(_aliceBech32).nativeValue, _aliceBech32);
      expect(U8Type.type.name, isNotEmpty);
    });

    test('composite and collection values are reachable', () {
      final ListValue list = ListValue(ListType(U8Type.type), <TypedValue>[
        U8Value(1),
        U8Value(2),
      ]);
      expect(list.elements, hasLength(2));

      final OptionValue option = OptionValue.some(
        OptionType(U8Type.type),
        U8Value(3),
      );
      expect(option.isSome, isTrue);

      final VariadicValue variadic = VariadicValue(<TypedValue>[
        U8Value(1),
      ], itemType: U8Type.type);
      expect(variadic.items, hasLength(1));

      final Fields fields = Fields(<Field>[
        Field(name: 'a', value: U8Value(1)),
      ]);
      expect(fields.getByName('a').value, isA<U8Value>());
    });

    test('token payment struct types are reachable', () {
      final EsdtTokenPayment payment = EsdtTokenPayment(
        tokenIdentifier: const TokenIdentifier('FOO-abcdef'),
        tokenNonce: BigInt.zero,
        amount: BigInt.from(10),
      );
      final StructValue encoded = EsdtTokenPaymentType.toStructValue(payment);
      expect(EsdtTokenPaymentType.fromStructValue(encoded), payment);

      final EgldOrEsdtTokenPayment egldPayment = EgldOrEsdtTokenPayment(
        tokenIdentifier: EgldOrEsdtTokenIdentifier.egld(),
        tokenNonce: BigInt.zero,
        amount: BigInt.from(10),
      );
      final StructValue egldEncoded = EgldOrEsdtTokenPaymentType.toStructValue(
        egldPayment,
      );
      expect(
        EgldOrEsdtTokenPaymentType.fromStructValue(egldEncoded),
        egldPayment,
      );
    });

    test('codecs, serializers and the type parser are reachable', () {
      final BinaryCodec codec = BinaryCodec.withDefaults();
      expect(codec.encodeTopLevel(U8Value(1)), isNotEmpty);

      final ArgSerializer serializer = ArgSerializer();
      expect(serializer.valuesToStrings(<TypedValue>[U8Value(1)]), isNotEmpty);

      final AbiRegistry registry = AbiRegistry();
      expect(registry, isNotNull);

      expect(TypeFormulaParser.parseString('Option<u32>').name, 'Option');
    });

    test('smart contract query and address types are reachable', () {
      final SmartContractAddress contract = SmartContractAddress.fromBech32(
        _pairContractBech32,
      );
      expect(contract.bech32, _pairContractBech32);

      final SmartContractQuery query = SmartContractQuery.view(
        contract: contract,
        function: const SmartContractFunction('getAmountOut'),
      );
      expect(query.input.function.name, 'getAmountOut');

      expect(ReturnCode.ok.code, 'ok');
    });
  });

  group('infrastructure', () {
    test('network providers and their config are reachable', () {
      const NetworkProviderConfig config = NetworkProviderConfig(
        clientName: 'public-surface-test',
        retryPolicy: RetryPolicy.disabled(),
        throttlePolicy: ThrottlePolicy.disabled(),
        cachePolicy: ResponseCachePolicy.disabled(),
      );
      expect(config.clientName, 'public-surface-test');
      expect(UserAgent.build(clientName: 'x'), '${UserAgent.prefix}/x');

      expect(ApiNetworkProvider.devnet(), isA<NetworkProvider>());
      expect(GatewayNetworkProvider.devnet(), isA<NetworkProvider>());
    });

    test('guardian models are reachable', () {
      const GuardianData data = GuardianData(guarded: false);
      expect(data.guarded, isFalse);

      final Guardian guardian = Guardian(
        address: Address.fromBech32(_bobBech32),
        activationEpoch: 1,
        serviceUid: 'uid',
      );
      expect(guardian.activationEpoch, 1);
    });

    test('resilience primitives are reachable', () {
      final CircuitBreaker breaker = CircuitBreaker();
      expect(breaker.state, CircuitState.closed);

      final RetryHelper retry = RetryHelper(config: const RetryConfig());
      expect(retry.config.maxRetries, greaterThan(0));

      final RequestThrottle throttle = RequestThrottle(
        capacity: 1,
        refillPerSecond: 1,
      );
      expect(throttle.capacity, 1);
    });

    test('caching, pagination and batching are reachable', () {
      final CacheManager cache = CacheManager();
      expect(cache.defaultConfig, isA<CacheConfig>());

      final LRUCache<String, int> lru = LRUCache<String, int>(maxSize: 2);
      expect(lru.maxSize, 2);

      const PaginationParams page = PaginationParams(
        page: 1,
        size: 10,
        sortOrder: SortOrder.ascending,
      );
      expect(page.size, 10);

      const BatchConfig batch = BatchConfig();
      expect(batch.maxConcurrency, greaterThan(0));
    });

    test('logging is reachable', () {
      expect(ConsoleLogger(minLevel: LogLevel.error), isA<Logger>());
      expect(NullLogger(), isA<Logger>());
    });
  });

  group('entrypoints', () {
    test('every network entrypoint is reachable', () {
      expect(DevnetEntrypoint(), isA<NetworkEntrypoint>());
      expect(TestnetEntrypoint(), isA<NetworkEntrypoint>());
      expect(MainnetEntrypoint(), isA<NetworkEntrypoint>());
      expect(DevnetProxyEntrypoint(), isA<ProxyNetworkEntrypoint>());
      expect(TestnetProxyEntrypoint(), isA<ProxyNetworkEntrypoint>());
      expect(MainnetProxyEntrypoint(), isA<ProxyNetworkEntrypoint>());
      expect(EntrypointUrls.devnet, isNotEmpty);
    });
  });

  group('wallet', () {
    test('signer and verifier round-trip a message', () async {
      final Mnemonic mnemonic = Mnemonic.generate();
      final UserSecretKey secretKey = await mnemonic.deriveKey();
      final UserPublicKey publicKey = await secretKey.generatePublicKey();
      mnemonic.dispose();

      final Message message = Message(<int>[]);
      final Uint8List bytesToSign = const MessageComputer()
          .computeBytesForSigning(message);
      final Uint8List signature = await UserSigner(secretKey).sign(bytesToSign);
      expect(
        await UserVerifier(publicKey).verify(bytesToSign, signature),
        isTrue,
      );
    });

    test('validator signer, PEM entry and bech32 encoder are reachable', () {
      final ValidatorSigner validator = ValidatorSigner.custom(
        (Uint8List message) => Uint8List(96),
      );
      expect(validator, isA<ValidatorSigner>());

      final PemEntry entry = PemEntry(
        label: _aliceBech32,
        message: Uint8List(64),
      );
      expect(entry.toText(), contains('BEGIN PRIVATE KEY'));

      expect(const Bech32Encoder(hrp: 'erd'), isNotNull);
    });

    test('key derivation and encryption types are reachable', () {
      expect(ScryptKeyDerivationParams().n, 4096);
      expect(Randomness().salt, hasLength(32));
      expect(EncryptorVersion.v4.value, 4);
    });
  });

  group('utils', () {
    test('helpers used by generated code are reachable', () {
      expect(requireAs<int>(1, 'field'), 1);
      expect(optionalAs<int>(null, 'field'), isNull);
      expect(requireInt('2', 'field'), 2);
      expect(optionalInt(null, 'field'), isNull);
      expect(infer<BigInt>(BigInt.one), BigInt.one);
    });

    test('utility classes and exceptions are reachable', () {
      expect(HexUtils.bytesToHex(<int>[1, 255]), '01ff');
      expect(StringUtils.levenshteinDistance('a', 'b'), 1);
      expect(CollectionUtils.listEquals<int>(<int>[1], <int>[1]), isTrue);
      expect(JsonUtils.parseInt('3'), 3);
      expect(EventDeduplicator(), isNotNull);
      expect(const NetworkException('boom'), isA<AbidockException>());
      expect(
        const ValidationException(
          'boom',
          parameterName: 'p',
          invalidValue: 1,
          constraint: '> 1',
        ),
        isA<AbidockException>(),
      );
    });
  });
}
