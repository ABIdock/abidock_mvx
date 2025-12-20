import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'abidock_mvx',
  tagline: 'MultiversX Dart SDK - Smart Contract Interactions Made Easy',
  favicon: 'img/abidock.svg',

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Set the production url of your site here
  url: 'https://abidock-mvx.dev',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/',

  // GitHub pages deployment config.
  organizationName: 'ABIdock', // GitHub org/user name
  projectName: 'abidock_mvx', // Repository name

  onBrokenLinks: 'throw',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl:
            'https://github.com/ABIdock/abidock_mvx/tree/main/docs/',
        },
        blog: false, // Disable blog for now
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    // Social card for link sharing
    image: 'img/abidock_background.svg',
    colorMode: {
      defaultMode: 'dark',
      disableSwitch: false,
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'abidock_mvx',
      logo: {
        alt: 'abidock_mvx Logo',
        src: 'img/abidock.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Documentation',
        },
        {
          href: 'https://pub.dev/packages/abidock_mvx',
          label: 'pub.dev',
          position: 'right',
        },
        {
          href: 'https://github.com/ABIdock/abidock_mvx',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            {
              label: 'Getting Started',
              to: '/docs/',
            },
            {
              label: 'Installation',
              to: '/docs/getting-started/installation',
            },
            {
              label: 'Code Generation',
              to: '/docs/codegen/overview',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'MultiversX Docs',
              href: 'https://docs.multiversx.com',
            },
            {
              label: 'MultiversX Discord',
              href: 'https://discord.gg/multiversxbuilders',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'pub.dev',
              href: 'https://pub.dev/packages/abidock_mvx',
            },
            {
              label: 'GitHub',
              href: 'https://github.com/ABIdock/abidock_mvx',
            },
            {
              label: 'ABIdock GitHub',
              href: 'https://github.com/ABIdock',
            },
            {
              label: '𝕏 (Twitter)',
              href: 'https://x.com/0xAbidock',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} ABIdock, built on MultiversX blockchain.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.vsDark,
      additionalLanguages: ['dart', 'bash', 'json'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
