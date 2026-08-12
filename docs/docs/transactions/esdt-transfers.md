---
id: esdt-transfers
title: ESDT Transfers
sidebar_position: 3
description: Send ESDT fungible tokens on MultiversX using encoded transaction data with proper token identifiers and amounts.
---

# ESDT Transfers

Transfer fungible ESDT tokens between addresses.

## What is ESDT?

ESDT (eStandard Digital Token) is MultiversX's native token standard. Unlike EGLD transfers, ESDT transfers use encoded data in the transaction.

## Simple ESDT Transfer

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  
  // Get account info
  final config = await provider.getNetworkConfig();
  final accountInfo = await provider.getAccount(account.address);
  
  // Token details
  final tokenIdentifier = 'USDC-c76f1f';
  final amount = BigInt.from(1000000); // 1 USDC (6 decimals)
  final recipient = Address.fromBech32('erd1...recipient...');
  
  // Build ESDT transfer data
  final data = 'ESDTTransfer@${_hexEncode(tokenIdentifier)}@${amount.toRadixString(16)}';
  
  // Create transaction
  final tx = Transaction(
    sender: account.address,
    receiver: recipient,
    value: Balance.zero(),
    nonce: accountInfo.nonce,
    gasLimit: GasLimit(500000),
    gasPrice: GasPrice(1000000000),
    chainId: ChainId(config.chainId),
    version: TransactionVersion(1),
    data: Uint8List.fromList(utf8.encode(data)),
  );
  
  final signature = await account.signTransaction(tx);
  final signed = tx.copyWith(newSignature: Signature.fromUint8List(signature));
  final hash = await provider.sendTransaction(signed);
  
  print('Sent: $hash');
}

String _hexEncode(String str) {
  return str.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join();
}
```

## Token Decimals

Different tokens have different decimal places:

| Token | Decimals | 1 Unit |
|-------|----------|--------|
| USDC | 6 | 1000000 |
| WEGLD | 18 | 1000000000000000000 |
| MEX | 18 | 1000000000000000000 |

```dart
// Helper function
BigInt tokenAmount(double amount, int decimals) {
  return BigInt.from(amount * pow(10, decimals));
}

// Usage
final oneUsdc = tokenAmount(1.0, 6);     // 1000000
final oneWegld = tokenAmount(1.0, 18);   // 1000000000000000000
```

## Check Token Balance

```dart
void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final address = Address.fromBech32('erd1...');
  
  // Get all ESDT tokens
  final tokens = await provider.getFungibleTokensOfAccount(address);
  
  for (final token in tokens) {
    print('${token.identifier}: ${token.balance}');
  }
  
  // Get specific token
  final usdcBalance = await provider.getTokenOfAccount(
    address,
    'USDC-c76f1f',
  );
  print('USDC Balance: ${usdcBalance.balance}');
}
```

## Transfer to Smart Contract

When sending ESDT to a contract with a function call, use `SmartContractController`:

```dart
void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  
  final config = await provider.getNetworkConfig();
  final networkAccount = await provider.getAccount(account.address);
  
  // Load contract ABI
  final abi = SmartContractAbi.fromJson(abiJson);
  final contractAddress = Address.fromBech32('erd1qqq...');
  
  final controller = SmartContractController(
    contractAddress: contractAddress,
    abi: abi,
    networkProvider: provider,
  );
  
  // Create ESDT transfer + contract call
  final tx = await controller.call(
    account: account,
    nonce: networkAccount.nonce,
    endpointName: 'deposit',
    arguments: [], // Function arguments if any (native Dart types)
    tokenTransfers: [
      TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'WEGLD-bd4d79',
        amount: BigInt.parse('500000000000000000'), // 0.5 WEGLD
      ),
    ],
    options: BaseControllerInput(gasLimit: GasLimit(15000000)),
  );
  
  final hash = await provider.sendTransaction(tx);
  print('Deposit: $hash');
}
```

For simple transfers without contract calls, use `TransfersController`:

```dart
final transfersController = TransfersController(
  chainId: ChainId(config.chainId),
);

final tx = await transfersController.createTransactionForTokenTransfer(
  account,
  networkAccount.nonce,
  TokenTransferInput(
    receiver: recipient,
    transfers: [
      TokenTransfer.fungible(
        tokenIdentifier: 'WEGLD-bd4d79',
        amount: BigInt.parse('500000000000000000'),
      ),
    ],
  ),
);
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';
import 'dart:math';

void main() async {
  print('=== ESDT Transfer Demo ===\n');
  
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  final signer = UserSigner(account.secretKey);
  
  print('Sender: ${account.address.bech32}');
  
  // Get account info
  final config = await provider.getNetworkConfig();
  final networkAccount = await provider.getAccount(account.address);
  
  // Check token balance
  final tokenId = 'WEGLD-bd4d79';
  
  try {
    final tokenBalance = await provider.getTokenOfAccount(
      account.address,
      tokenId,
    );
    final balanceValue = BigInt.parse(tokenBalance.balance);
    print('Balance: ${balanceValue.toDouble() / 1e18} WEGLD');
  } on NetworkException catch (e) {
    if (e.statusCode == 404) {
      print('Token not found or zero balance');
    } else {
      print('Network error: ${e.message}');
    }
    return;
  }
  
  // Transfer details
  final recipient = Address.fromBech32(
    'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx'
  );
  final amount = BigInt.parse('10000000000000000'); // 0.01 WEGLD
  
  // Build ESDT transfer using TransferTransactionsFactory
  final factory = TransferTransactionsFactory(
    config: TransferTransactionsConfig(chainId: ChainId(config.chainId)),
  );
  
  final tx = factory.createTransactionForEsdtTransfer(
    sender: account.address,
    receiver: recipient,
    tokenTransfers: [
      TokenTransfer.fungible(
        tokenIdentifier: tokenId,
        amount: amount,
      ),
    ],
  );
  
  print('  Token: $tokenId');
  print('  Amount: ${amount.toDouble() / 1e18} WEGLD');
  print('  To: ${recipient.bech32.substring(0, 20)}...');
  
  // Set nonce and sign transaction
  final txWithNonce = tx.copyWith(newNonce: networkAccount.nonce);
  final signature = await signer.sign(txWithNonce.serializeForSigning());
  final signed = txWithNonce.copyWith(newSignature: Signature.fromUint8List(signature));
  
  // Send
  final hash = await provider.sendTransaction(signed);
  
  // Wait for confirmation
  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(hash);
  
}
```

## Gas Estimation

`TransferTransactionsFactory` computes the gas limit for you. It sums two
terms:

```
gasLimit = (minGasLimit + gasLimitPerByte * data.length) + executionGas
```

with `minGasLimit = 50,000` and `gasLimitPerByte = 1,500` by default. The
execution term depends on the transfer protocol used:

| Operation | Execution gas | Total |
|-----------|---------------|-------|
| Single fungible ESDT (`ESDTTransfer`) | 300,000 | 350,000 + 1,500 x data bytes |
| Single NFT/SFT (`ESDTNFTTransfer`) | 1,000,000 | 1,050,000 + 1,500 x data bytes |
| Multi-transfer of N tokens (`MultiESDTNFTTransfer`) | 800,000 + 200,000 x N | 850,000 + 200,000 x N + 1,500 x data bytes |

Note that `createTransactionForEsdtTransfer` switches protocol on list length:
one entry uses the single-transfer path, two or more use
`MultiESDTNFTTransfer`.

Pass an explicit `gasLimit` to override the calculation entirely:

```dart
final transfersFactory = TransferTransactionsFactory(
  config: TransferTransactionsConfig(chainId: ChainId(config.chainId)),
);

final overriddenTx = transfersFactory.createTransactionForEsdtTransfer(
  sender: account.address,
  receiver: recipient,
  tokenTransfers: [
    TokenTransfer.fungible(
      tokenIdentifier: 'WEGLD-bd4d79',
      amount: BigInt.parse('10000000000000000'),
    ),
  ],
  gasLimit: GasLimit(600000), // skips the automatic calculation
);
```

When you attach tokens to a contract call, the endpoint's own execution cost
is on top of the transfer cost, so supply it through
`BaseControllerInput(gasLimit: ...)` -- `SmartContractController.call` requires
it.

## Next Steps

- [NFT Transfers](/docs/transactions/nft-transfers) - Transfer NFTs
- [Multi Transfers](/docs/transactions/multi-transfers) - Multiple tokens
- [Transaction Tracking](/docs/transactions/transaction-tracking) - Monitor status
