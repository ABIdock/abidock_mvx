---
id: multi-transfers
title: Multi Transfers
sidebar_position: 5
description: Send multiple ESDT tokens and NFTs in a single atomic MultiversX transaction for efficient batch transfers.
---

# Multi Transfers

Transfer multiple ESDT tokens and/or NFTs in a single transaction.

## Why Multi-Transfer?

| Approach | Transactions | Gas |
|----------|--------------|-----|
| Separate transfers | N | N × 500,000+ |
| Multi-transfer | 1 | ~1,100,000 + 100,000/token |

Benefits:
- **Atomic**: All transfers succeed or all fail
- **Efficient**: Single transaction fee
- **Required**: For multi-token contract calls

## Basic Multi-Transfer

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  
  final config = await provider.getNetworkConfig();
  final networkAccount = await provider.getAccount(account.address);
  
  final recipient = Address.fromBech32('erd1...recipient...');
  
  // Define tokens to transfer using TokenTransfer
  final tokens = [
    TokenTransfer.fungible(
      tokenIdentifier: 'WEGLD-bd4d79',
      amount: BigInt.parse('100000000000000000'), // 0.1 WEGLD
    ),
    TokenTransfer.fungible(
      tokenIdentifier: 'USDC-c76f1f',
      amount: BigInt.from(5000000), // 5 USDC
    ),
  ];
  
  // Create factory
  final factory = TransferTransactionsFactory(
    config: TransferTransactionsConfig(chainId: ChainId(config.chainId)),
  );
  
  // Build multi-transfer transaction
  final tx = factory.createTransactionForEsdtTransfer(
    sender: account.address,
    receiver: recipient,
    tokenTransfers: tokens,
  );
  
  // Set nonce and sign
  final txWithNonce = tx.copyWith(newNonce: networkAccount.nonce);
  final signer = UserSigner(account.secretKey);
  final signature = await signer.sign(txWithNonce.serializeForSigning());
  final signed = txWithNonce.copyWith(newSignature: Signature.fromUint8List(signature));
  
  final hash = await provider.sendTransaction(signed);
  print('Multi-transfer: $hash');
}
```

## Multi-Transfer with NFTs

Mix fungible and non-fungible tokens:

```dart
final tokens = [
  // Fungible token
  TokenTransfer.fungible(
    tokenIdentifier: 'WEGLD-bd4d79',
    amount: BigInt.parse('500000000000000000'), // 0.5 WEGLD
  ),
  // NFT (nonce required)
  TokenTransfer.nonFungible(
    tokenIdentifier: 'MYNFT-abc123',
    nonce: 42, // NFT nonce
    amount: BigInt.one, // NFTs always have amount 1
  ),
  // SFT (multiple copies)
  TokenTransfer.nonFungible(
    tokenIdentifier: 'MYSFT-def456',
    nonce: 10,
    amount: BigInt.from(5), // 5 copies
  ),
];

final factory = TransferTransactionsFactory(
  config: TransferTransactionsConfig(chainId: ChainId(config.chainId)),
);

final tx = factory.createTransactionForEsdtTransfer(
  sender: account.address,
  receiver: recipient,
  tokenTransfers: tokens,
);
```

## Multi-Transfer to Smart Contract

Use `SmartContractController` for sending tokens with contract calls:

```dart
void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  
  final config = await provider.getNetworkConfig();
  final networkAccount = await provider.getAccount(account.address);
  
  // Load contract ABI
  final abi = SmartContractAbi.fromJson(abiJson);
  final contractAddress = SmartContractAddress.fromBech32('erd1qqq...');
  
  final controller = SmartContractController(
    contractAddress: contractAddress,
    abi: abi,
    networkProvider: provider,
  );
  
  // Create transaction with token transfers
  final tx = await controller.call(
    account: account,
    nonce: networkAccount.nonce,
    endpointName: 'addLiquidity',
    arguments: [
      // Arguments as native Dart types - NativeSerializer handles conversion
      BigInt.parse('490000000000000000'), // minAmountA
      BigInt.from(490000000),             // minAmountB  
    ],
    tokenTransfers: [
      TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'WEGLD-bd4d79',
        amount: BigInt.parse('500000000000000000'),
      ),
      TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'USDC-c76f1f',
        amount: BigInt.from(500000000),
      ),
    ],
    options: BaseControllerInput(gasLimit: GasLimit(25000000)),
  );
  
  final hash = await provider.sendTransaction(tx);
  print('Multi-transfer to contract: $hash');
}
```

## Using SmartContractController

The controller handles multi-transfers automatically:

```dart
final tx = await controller.call(
  account: account,
  nonce: networkAccount.nonce,
  endpointName: 'addLiquidity',
  arguments: [
    minAmountA,
    minAmountB,
  ],
  tokenTransfers: [
    TokenTransferValue.fromPrimitives(
      tokenIdentifier: 'WEGLD-bd4d79',
      amount: amountA,
    ),
    TokenTransferValue.fromPrimitives(
      tokenIdentifier: 'USDC-c76f1f',
      amount: amountB,
    ),
  ],
  options: BaseControllerInput(gasLimit: GasLimit(25000000)),
);
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  print('=== Multi-Transfer Demo ===\n');
  
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  final signer = UserSigner(account.secretKey);
  
  print('Sender: ${account.address.bech32}');
  
  final config = await provider.getNetworkConfig();
  final networkAccount = await provider.getAccount(account.address);
  
  // Check balances
  final accountTokens = await provider.getFungibleTokensOfAccount(account.address);
  for (final token in accountTokens.take(5)) {
    print('  ${token.identifier}: ${token.balance}');
  }
  
  // Recipient
  final recipient = Address.fromBech32(
    'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx'
  );
  
  // Select tokens to send using TokenTransfer
  final transfers = <TokenTransfer>[];
  
  for (final token in accountTokens.take(2)) {
    // Send 1% of each token
    final tokenBalance = BigInt.parse(token.balance);
    final sendAmount = tokenBalance ~/ BigInt.from(100);
    if (sendAmount > BigInt.zero) {
      if (token.nonce > 0) {
        // NFT/SFT
        transfers.add(TokenTransfer.nonFungible(
          tokenIdentifier: token.identifier,
          nonce: token.nonce,
          amount: sendAmount,
        ));
      } else {
        // Fungible
        transfers.add(TokenTransfer.fungible(
          tokenIdentifier: token.identifier,
          amount: sendAmount,
        ));
      }
    }
  }
  
  if (transfers.isEmpty) {
    return;
  }
  
  print('To: ${recipient.bech32.substring(0, 20)}...');
  
  // Use TransferTransactionsFactory
  final factory = TransferTransactionsFactory(
    config: TransferTransactionsConfig(chainId: ChainId(config.chainId)),
  );
  
  final tx = factory.createTransactionForEsdtTransfer(
    sender: account.address,
    receiver: recipient,
    tokenTransfers: transfers,
  );
  
  // Set nonce and sign
  final txWithNonce = tx.copyWith(newNonce: networkAccount.nonce);
  final signature = await signer.sign(txWithNonce.serializeForSigning());
  final signed = txWithNonce.copyWith(newSignature: Signature.fromUint8List(signature));
  
  
  final hash = await provider.sendTransaction(signed);
  print('Sent! Hash: $hash');
  
  // Wait
  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(hash);
  
}
```

## Gas Calculation

```dart
int calculateMultiTransferGas({
  required int tokenCount,
  String? functionName,
  int argumentCount = 0,
}) {
  var gas = 1100000; // Base
  gas += tokenCount * 100000; // Per token
  
  if (functionName != null) {
    gas += 5000000; // Contract call base
    gas += argumentCount * 50000; // Per argument
  }
  
  return gas;
}
```

## Next Steps

- [Transaction Tracking](/docs/transactions/transaction-tracking) - Monitor status
- [Smart Contracts](/docs/smart-contracts/overview) - Contract interactions
- [EGLD Transfers](/docs/transactions/egld-transfers) - Native transfers
