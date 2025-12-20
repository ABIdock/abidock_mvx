---
id: nft-transfers
title: NFT Transfers
sidebar_position: 4
description: Transfer NFTs and Semi-Fungible Tokens (SFTs) on MultiversX with proper nonce handling and multi-transfer support.
---

# NFT Transfers

Transfer NFTs and SFTs (Semi-Fungible Tokens) on MultiversX.

## NFT vs SFT

| Type | Nonce | Amount | Example |
|------|-------|--------|---------|
| **NFT** | Unique | Always 1 | Art, collectibles |
| **SFT** | Unique | Multiple | Game items, tickets |

## Simple NFT Transfer

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  
  final config = await provider.getNetworkConfig();
  final networkAccount = await provider.getAccount(account.address);
  
  // NFT details
  final collection = 'MYNFT-abc123';
  final nonce = 42; // NFT #42
  final recipient = Address.fromBech32('erd1...recipient...');
  
  // Create factory
  final factory = TransferTransactionsFactory(
    config: TransferTransactionsConfig(chainId: ChainId(config.chainId)),
  );
  
  // Build NFT transfer transaction
  final tx = factory.createTransactionForEsdtTransfer(
    sender: account.address,
    receiver: recipient,
    tokenTransfers: [
      TokenTransfer.nonFungible(
        tokenIdentifier: collection,
        nonce: nonce,
        amount: BigInt.one, // NFTs always have amount 1
      ),
    ],
  );
  
  // Set nonce and sign
  final txWithNonce = tx.copyWith(newNonce: networkAccount.nonce);
  final signer = UserSigner(account.secretKey);
  final signature = await signer.sign(txWithNonce.serializeForSigning());
  final signed = txWithNonce.copyWith(newSignature: Signature.fromUint8List(signature));
  
  final hash = await provider.sendTransaction(signed);
  print('Sent NFT: $hash');
}
```

:::note Receiver Address
For NFT transfers, the transaction receiver is your own address. The actual recipient is encoded in the transfer data.
:::

## SFT Transfer (Multiple Quantity)

```dart
// Transfer 5 copies of an SFT using TokenTransfer
final factory = TransferTransactionsFactory(
  config: TransferTransactionsConfig(chainId: ChainId(config.chainId)),
);

final tx = factory.createTransactionForEsdtTransfer(
  sender: account.address,
  receiver: recipient,
  tokenTransfers: [
    TokenTransfer.nonFungible(
      tokenIdentifier: 'MYSFT-def456',
      nonce: 10,
      amount: BigInt.from(5), // 5 copies
    ),
  ],
);
```

## Check NFT Balance

```dart
void main() async {
  final provider = GatewayNetworkProvider.devnet();
  final address = Address.fromBech32('erd1...');
  
  // Get all NFTs
  final nfts = await provider.getNonFungibleTokensOfAccount(address);
  
  for (final nft in nfts) {
    print('Collection: ${nft.collection}');
    print('Nonce: ${nft.nonce}');
    print('Name: ${nft.name}');
    print('Balance: ${nft.balance}');
    print('---');
  }
}
```

## NFT Transfer to Smart Contract

Send NFT to a contract with a function call using `SmartContractController`:

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
  
  // Create NFT transfer + contract call
  final tx = await controller.call(
    account: account,
    nonce: networkAccount.nonce,
    endpointName: 'stakeNft',
    arguments: [], // Optional function arguments (native Dart types)
    tokenTransfers: [
      TokenTransferValue.fromPrimitives(
        tokenIdentifier: 'MYNFT-abc123',
        amount: BigInt.one,
        nonce: BigInt.from(42),
      ),
    ],
    options: BaseControllerInput(gasLimit: GasLimit(15000000)),
  );
  
  final hash = await provider.sendTransaction(tx);
  print('Staked NFT: $hash');
}
```

## NFT Identifier Format

NFTs are identified by collection + nonce:

```
COLLECTION-hash-NONCE
     │        │    │
     │        │    └── Hex nonce (e.g., 2a = 42)
     │        └─────── 6 char random hex
     └──────────────── 3-10 char ticker

Example: MYNFT-abc123-2a = NFT #42 from MYNFT collection
```

```dart
// Parse NFT identifier
void parseNftId(String identifier) {
  final parts = identifier.split('-');
  final collection = '${parts[0]}-${parts[1]}'; // MYNFT-abc123
  final nonce = int.parse(parts[2], radix: 16); // 42
  
  print('Collection: $collection');
  print('Nonce: $nonce');
}
```

## Complete Example

```dart
import 'package:abidock_mvx/abidock_mvx.dart';

void main() async {
  print('=== NFT Transfer Demo ===\n');
  
  final provider = GatewayNetworkProvider.devnet();
  final account = await Account.fromMnemonic('your mnemonic...');
  final signer = UserSigner(account.secretKey);
  
  print('Sender: ${account.address.bech32}');
  
  // Get account info
  final config = await provider.getNetworkConfig();
  final networkAccount = await provider.getAccount(account.address);
  
  // List owned NFTs
  final nfts = await provider.getNonFungibleTokensOfAccount(account.address);
  
  if (nfts.isEmpty) {
    print('No NFTs found');
    return;
  }
  
  for (var i = 0; i < nfts.length && i < 5; i++) {
    final nft = nfts[i];
    print('  [$i] ${nft.collection}-${nft.nonce.toRadixString(16)}: ${nft.name}');
  }
  
  // Select first NFT for demo
  final selectedNft = nfts.first;
  final collection = selectedNft.collection;
  final nonce = BigInt.from(selectedNft.nonce);
  
  // Recipient
  final recipient = Address.fromBech32(
    'erd1spyavw0956vq68xj8y4tenjpq2wd5a9p2c6j8gsz7ztyrnpxrruqzu66jx'
  );
  
  print('  NFT: ${selectedNft.name}');
  print('  Collection: $collection');
  print('  Nonce: $nonce');
  print('  To: ${recipient.bech32.substring(0, 20)}...');
  
  // Build transfer using TransferTransactionsFactory
  final factory = TransferTransactionsFactory(
    config: TransferTransactionsConfig(chainId: ChainId(config.chainId)),
  );
  
  final tx = factory.createTransactionForEsdtTransfer(
    sender: account.address,
    receiver: recipient,
    tokenTransfers: [
      TokenTransfer.nonFungible(
        tokenIdentifier: collection,
        nonce: nonce.toInt(),
        amount: BigInt.one, // NFTs always have amount 1
      ),
    ],
  );
  
  // Set nonce and sign
  final txWithNonce = tx.copyWith(newNonce: networkAccount.nonce);
  final signature = await signer.sign(txWithNonce.serializeForSigning());
  final signed = txWithNonce.copyWith(newSignature: Signature.fromUint8List(signature));
  
  // Send
  final hash = await provider.sendTransaction(signed);
  
  // Wait
  final watcher = TransactionWatcher(networkProvider: provider);
  final result = await watcher.awaitCompleted(hash);
  
}
```

## Gas for NFT Transfers

| Operation | Gas Limit |
|-----------|-----------|
| Simple NFT transfer | 1,000,000 |
| NFT to contract | 1,000,000 + function gas |
| Multiple NFTs | 1,100,000 + 100,000 per NFT |

## Next Steps

- [Multi Transfers](/docs/transactions/multi-transfers) - Multiple tokens at once
- [ESDT Transfers](/docs/transactions/esdt-transfers) - Fungible tokens
- [Transaction Tracking](/docs/transactions/transaction-tracking) - Monitor status
