---
id: contributing
title: Contributing to abidock_mvx
---

[comment]: # (mx-abstract)

Guidelines for contributing code, documentation, and bug reports to the abidock_mvx project. This document covers the development workflow, quality standards, and how to submit effective pull requests.

[comment]: # (mx-context-auto)

## Overview

This guide covers expectations for code and documentation contributions.

[comment]: # (mx-context-auto)

## Contribution Workflow

### Step 1: Discuss first (when in doubt)

Open an issue or start a discussion for sizeable work so we can align on scope early.

### Step 2: Fork and branch

```bash
git clone https://github.com/<you>/abidock_mvx.git
cd abidock_mvx
git checkout -b feature/your-feature-name
```

Use descriptive branch names such as `feature/abi-decoder-v2` or `fix/wallet-timeout`.

### Step 3: Make focused commits

Each commit should:
- Compile successfully
- Pass all tests
- Explain the "why" in the commit message

### Step 4: Open a pull request

- Fill in the PR template completely
- Link related issues
- Describe validation steps

### Step 5: Review loop

Respond to feedback promptly. We squash-merge most changes.

[comment]: # (mx-context-auto)

## Filing Issues

### Bug reports

:::important
Before filing, confirm the bug reproduces on the latest `main` branch.
:::

Include in your report:
- Exact reproduction steps
- Logs and error messages
- Expected vs actual behavior
- Contract details (ABI, address, network) when the issue is protocol-specific

### Feature requests

- Explain the use case you want to support
- Outline the API/CLI surface you expect to touch
- Provide links to specs or MultiversX RFCs when applicable

[comment]: # (mx-context-auto)

## Development Setup

### Step 1: Clone and install dependencies

```bash
git clone https://github.com/<you>/abidock_mvx.git
cd abidock_mvx
dart pub get
```

### Step 2: Run the quality checks

```bash
dart format --output=none --set-exit-if-changed .  # [1]
dart analyze                                        # [2]
dart test                                           # [3]
```

Where:
- **[1]** Check formatting without modifying files
- **[2]** Run static analysis
- **[3]** Execute the full test suite

### Step 3: Validate code generation (if applicable)

If your changes affect the CLI or code generation:

```bash
dart run bin/abidock.dart assets/pair.abi.json example/cookbook/generated/pair Pair --full
```

Inspect the diff in `example/cookbook/generated/` to ensure correct output.

### Step 4: Update documentation

Rebuild snippets in `example/` and ensure any referenced commands are accurate.

[comment]: # (mx-context-auto)

## Quality Standards

| Requirement | Details |
| ----------- | ------- |
| Style | Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) and format with `dart format` |
| Functions | Prefer small, composable functions |
| API Changes | Avoid breaking changes without discussion |
| Tests | Add tests alongside features/fixes; use Arrange/Act/Assert pattern |
| Documentation | Document public APIs with dartdoc; update README and cookbooks when behavior changes |
| Changelog | Update `CHANGELOG.md` under the `Unreleased` heading |

[comment]: # (mx-context-auto)

## Pull Request Expectations

:::caution
CI must be green before requesting review.
:::

Your PR should include:
- Completed PR template with screenshots/terminal captures when UX changes
- Test coverage for new functionality
- Documentation updates if behavior changes
- Mention which testnet/mainnet endpoints were exercised (for network-related changes)

Large changes may require an architectural note in `PROJECT_STRUCTURE.md`.

[comment]: # (mx-context-auto)

## Communication Channels

| Channel | Purpose |
| ------- | ------- |
| GitHub Issues | Bugs, features, questions |
| Discussions | Design proposals, roadmap conversations |
| Security email | `security@multiversx.com` for vulnerabilities (do not open public issues) |

[comment]: # (mx-context-auto)

## Code of Conduct

We value respectful collaboration and clear engineering practices. By following this guide, we keep abidock_mvx dependable for every MultiversX developer.
