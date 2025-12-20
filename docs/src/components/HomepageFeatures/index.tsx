import type {ReactNode} from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  emoji: string;
  description: ReactNode;
};

const FeatureList: FeatureItem[] = [
  {
    title: 'Type-Safe ABI Binding',
    emoji: '🔗',
    description: (
      <>
        Generate strongly-typed Dart code from your MultiversX smart contract ABIs. 
        Full type safety with compile-time error checking.
      </>
    ),
  },
  {
    title: 'Zero Boilerplate',
    emoji: '⚡',
    description: (
      <>
        One command generates complete SDK bindings. No manual serialization, 
        no type conversion headaches—just clean, ready-to-use code.
      </>
    ),
  },
  {
    title: 'Complete Coverage',
    emoji: '📦',
    description: (
      <>
        Supports all MultiversX types including nested structs, enums, optionals, 
        BigUint, addresses, and complex managed types.
      </>
    ),
  },
];

function Feature({title, emoji, description}: FeatureItem) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center">
        <span className={styles.featureEmoji} role="img">{emoji}</span>
      </div>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): ReactNode {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
