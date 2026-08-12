---
id: intro
title: Introduction
sidebar_position: 1
slug: /
description: MultiversX SDK for Dart and Flutter - wallet management, smart contracts, transactions, and ABI encoding.
---

# Introduction

**MultiversX SDK for Dart & Flutter**

`abidock_mvx` is a Dart SDK for interacting with the MultiversX blockchain. It covers wallet management, smart contract interactions, transaction building, and ABI encoding.

## Key Features

### Entrypoints
- One object per network: `DevnetEntrypoint`, `TestnetEntrypoint`, `MainnetEntrypoint`
- Gateway counterparts for direct node access
- Cached provider plus pre-configured factories and controllers

### Wallet Management
- Create and manage wallets from mnemonics, PEM files, or keystores
- HD wallet derivation following BIP39/BIP44 standards
- Secure signing of transactions and messages

### Smart Contract Interactions
- Load and parse ABI files
- Type-safe contract queries
- Execute smart contract calls with proper encoding

### ABI Type System
- Support for all MultiversX ABI types
- Automatic serialization/deserialization
- Fluent builders for complex types (Structs, Enums, Tuples)

### Code Generation CLI
- Generate type-safe Dart code from ABI files
- Interactive and batch modes
- Customizable output

### Transaction Management
- EGLD, ESDT, and NFT transfers
- Multi-token transfers
- Transaction tracking and waiting

### Network Integration
- Gateway and API providers
- WebSocket event streaming
- Multiple network support (Mainnet, Devnet, Testnet)

## Get Started

- [**Installation**](/docs/getting-started/installation) - Add abidock_mvx to your project
- [**Quick Start**](/docs/getting-started/quick-start) - Create and send a transaction
- [**Entrypoints**](/docs/network/entrypoints) - Connect to a network in one line
- [**Wallet Guide**](/docs/wallet/overview) - Create and manage wallets
- [**Smart Contracts**](/docs/smart-contracts/overview) - Interact with contracts
- [**Cookbook**](/docs/cookbook/overview) - Runnable examples
