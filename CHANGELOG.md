# Changelog

All notable changes to `abidock_mvx` are documented here. We follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) and the structure recommended by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.0.0-beta.2] – 2025-12-20

### Fixed
- Fixed dangling library doc comments in codegen files.
- Updated package description to meet pub.dev length requirements.
- Replaced `flutter_lints` with `lints` for pure Dart compatibility.

## [1.0.0-beta.1] – 2025-12-08

### Added
- First public release of the MultiversX Dart/Flutter SDK and CLI.
- Wallet tooling covering mnemonic, PEM, and keystore workflows.
- Transaction builders for EGLD, ESDT, NFT, SFT, and MetaESDT transfers.
- High-level smart-contract controller with ABI-driven calls, queries and events.
- Gateway and REST network providers plus WebSocket event streams.
- ABI codecs for primitives, collections, composites, and protocol-specific special types.
- Code generator capable of scaffolding controllers, DTOs, and tests from ABI files.
- Cookbook examples and wallet walkthroughs demonstrating real integrations.
- 900+ automated tests spanning core types, infrastructure, serializers, and integration scenarios.

[1.0.0-beta.2]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.0.0-beta.2
[1.0.0-beta.1]: https://github.com/ABIdock/abidock_mvx/releases/tag/v1.0.0-beta.1
