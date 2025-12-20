library;

import 'package:abidock_mvx/abidock_mvx.dart';

const testMnemonic =
    'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';

Future<IAccount> createAliceAccount() async {
  final mnemonic = Mnemonic.fromString(testMnemonic);
  final secretKey = await mnemonic.deriveKey(addressIndex: 0);
  return Account.fromSecretKey(secretKey);
}

Future<IAccount> createBobAccount() async {
  final mnemonic = Mnemonic.fromString(testMnemonic);
  final secretKey = await mnemonic.deriveKey(addressIndex: 1);
  return Account.fromSecretKey(secretKey);
}

Future<UserSigner> createAliceSigner() async {
  final mnemonic = Mnemonic.fromString(testMnemonic);
  final secretKey = await mnemonic.deriveKey(addressIndex: 0);
  return UserSigner.fromSecretKey(secretKey);
}

Future<UserSigner> createBobSigner() async {
  final mnemonic = Mnemonic.fromString(testMnemonic);
  final secretKey = await mnemonic.deriveKey(addressIndex: 1);
  return UserSigner.fromSecretKey(secretKey);
}

const mockPairAbiJson = '''{
  "name": "Pair",
  "constructor": {
    "inputs": [
      {"name": "first_token_id", "type": "TokenIdentifier"},
      {"name": "second_token_id", "type": "TokenIdentifier"}
    ],
    "outputs": []
  },
  "endpoints": [
    {
      "name": "getReserve",
      "mutability": "readonly",
      "inputs": [{"name": "token_id", "type": "TokenIdentifier"}],
      "outputs": [{"type": "BigUint"}]
    },
    {
      "name": "swapTokensFixedInput",
      "mutability": "mutable",
      "payableInTokens": ["*"],
      "inputs": [
        {"name": "token_out", "type": "TokenIdentifier"},
        {"name": "amount_out_min", "type": "BigUint"}
      ],
      "outputs": [{"type": "EsdtTokenPayment"}]
    },
    {
      "name": "addLiquidity",
      "mutability": "mutable",
      "payableInTokens": ["*"],
      "inputs": [
        {"name": "first_token_amount_min", "type": "BigUint"},
        {"name": "second_token_amount_min", "type": "BigUint"}
      ],
      "outputs": [
        {"type": "EsdtTokenPayment"},
        {"type": "EsdtTokenPayment"},
        {"type": "EsdtTokenPayment"}
      ]
    }
  ],
  "events": [
    {
      "identifier": "swap",
      "inputs": [
        {"name": "token_in", "type": "TokenIdentifier", "indexed": true},
        {"name": "token_out", "type": "TokenIdentifier", "indexed": true},
        {"name": "caller", "type": "Address", "indexed": true},
        {"name": "amount_in", "type": "BigUint"},
        {"name": "amount_out", "type": "BigUint"}
      ]
    },
    {
      "identifier": "addLiquidity",
      "inputs": [
        {"name": "caller", "type": "Address", "indexed": true},
        {"name": "first_token_amount", "type": "BigUint"},
        {"name": "second_token_amount", "type": "BigUint"},
        {"name": "lp_token_amount", "type": "BigUint"}
      ]
    },
    {
      "identifier": "removeLiquidity",
      "inputs": [
        {"name": "caller", "type": "Address", "indexed": true},
        {"name": "first_token_amount", "type": "BigUint"},
        {"name": "second_token_amount", "type": "BigUint"},
        {"name": "lp_token_amount", "type": "BigUint"}
      ]
    },
    {
      "identifier": "updateReserves",
      "inputs": [
        {"name": "first_token_reserve", "type": "BigUint"},
        {"name": "second_token_reserve", "type": "BigUint"}
      ]
    }
  ],
  "types": {
    "EsdtTokenPayment": {
      "type": "struct",
      "fields": [
        {"name": "token_identifier", "type": "TokenIdentifier"},
        {"name": "token_nonce", "type": "u64"},
        {"name": "amount", "type": "BigUint"}
      ]
    },
    "State": {
      "type": "enum",
      "variants": [
        {"name": "Inactive", "discriminant": 0},
        {"name": "Active", "discriminant": 1},
        {"name": "PartialActive", "discriminant": 2}
      ]
    }
  }
}''';
