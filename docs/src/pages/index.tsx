import type {ReactNode} from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './index.module.css';

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero', styles.heroBanner)}>
      <div className="container">
        <div className={styles.logoContainer}>
          <img 
            src="/img/abidock.svg" 
            alt="abidock logo" 
            className={styles.heroLogo}
          />
          <img 
            src="/img/flutter_logo.svg" 
            alt="Flutter logo" 
            className={styles.flutterLogo}
          />
        </div>
        <Heading as="h1" className={styles.heroTitle}>
          {siteConfig.title}
        </Heading>
        <p className={styles.heroSubtitle}>{siteConfig.tagline}</p>
        <div className={styles.buttons}>
          <Link
            className="button button--primary button--lg"
            to="/docs/">
            Get Started
          </Link>
          <Link
            className="button button--secondary button--lg"
            to="/docs/getting-started/installation">
            Installation Guide
          </Link>
        </div>
      </div>
    </header>
  );
}

function FeatureSection() {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          <div className={clsx('col col--4')}>
            <div className={styles.featureCard}>
              <Heading as="h3">Type-Safe ABI</Heading>
              <p>
                Full type-safe smart contract interactions with automatic ABI parsing and code generation.
              </p>
            </div>
          </div>
          <div className={clsx('col col--4')}>
            <div className={styles.featureCard}>
              <Heading as="h3">Easy Integration</Heading>
              <p>
                Simple API for querying contracts, building transactions, and managing wallets.
              </p>
            </div>
          </div>
          <div className={clsx('col col--4')}>
            <div className={styles.featureCard}>
              <Heading as="h3">Code Generation</Heading>
              <p>
                Generate type-safe Dart bindings from your smart contract ABI with a single CLI command.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export default function Home(): ReactNode {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title="MultiversX Dart SDK"
      description="Type-safe MultiversX smart contract interactions in Dart. Build dApps with ease using abidock_mvx.">
      <HomepageHeader />
      <main>
        <FeatureSection />
      </main>
    </Layout>
  );
}
