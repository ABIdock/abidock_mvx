import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

/**
 * abidock_mvx Documentation Sidebar
 * Comprehensive sidebar structure for MultiversX Dart SDK documentation
 */
const sidebars: SidebarsConfig = {
  docsSidebar: [
    'intro',
    {
      type: 'category',
      label: 'Getting Started',
      collapsed: false,
      items: [
        'getting-started/installation',
        'getting-started/quick-start',
        'getting-started/configuration',
      ],
    },
    {
      type: 'category',
      label: 'Wallet Management',
      items: [
        'wallet/overview',
        'wallet/mnemonic-wallets',
        'wallet/pem-wallets',
        'wallet/keystore-wallets',
        'wallet/signing-transactions',
      ],
    },
    {
      type: 'category',
      label: 'Transactions',
      items: [
        'transactions/overview',
        'transactions/egld-transfers',
        'transactions/esdt-transfers',
        'transactions/nft-transfers',
        'transactions/multi-transfers',
        'transactions/token-management',
        'transactions/delegation-staking',
        'transactions/account-management',
        'transactions/transaction-tracking',
        'transactions/outcome-parsers',
        'transactions/nonce-manager',
        'transactions/decoding-transactions',
      ],
    },
    {
      type: 'category',
      label: 'Smart Contracts',
      items: [
        'smart-contracts/overview',
        'smart-contracts/loading-abi',
        'smart-contracts/queries',
        'smart-contracts/interactions',
        'smart-contracts/deploy-upgrade',
        'smart-contracts/relayed-transactions',
      ],
    },
    {
      type: 'category',
      label: 'ABI Types',
      collapsed: false,
      items: [
        'abi-types/overview',
        'abi-types/primitive-types',
        'abi-types/collection-types',
        'abi-types/composite-types',
        'abi-types/special-types',
        'abi-types/mixed-nested-types',
      ],
    },
    {
      type: 'category',
      label: 'Code Generation',
      items: [
        'codegen/overview',
        'codegen/cli-commands',
        'codegen/generated-code',
        'codegen/customization',
      ],
    },
    {
      type: 'category',
      label: 'Network',
      items: [
        'network/providers',
        'network/network-configuration',
        'network/websocket-events',
      ],
    },
    {
      type: 'category',
      label: 'Cookbook',
      items: [
        'cookbook/overview',
        'cookbook/token-swap',
        'cookbook/relayed-transaction',
        'cookbook/egld-transfer',
        'cookbook/websocket-events',
      ],
    },
    {
      type: 'category',
      label: 'Advanced',
      items: [
        'advanced/custom-serialization',
        'advanced/error-handling',
        'advanced/infrastructure',
        'advanced/best-practices',
        'advanced/cookbook-breakdown',
      ],
    },
  ],
};

export default sidebars;
