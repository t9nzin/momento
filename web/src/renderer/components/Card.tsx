import type { RendererProps } from '../types';
import { Pressable } from './Pressable';
import styles from './Card.module.css';

export function Card({ node, onAction }: RendererProps<'card'>) {
  const { imageUrl, title, subtitle } = node.props;
  return (
    <Pressable type="card" id={node.id} className={styles.card} onPress={onAction}>
      {imageUrl && <img className={styles.media} src={imageUrl} alt="" loading="lazy" />}
      <span className={styles.body}>
        <span className={styles.title}>{String(title)}</span>
        {subtitle !== undefined && subtitle !== '' && <span className={styles.subtitle}>{String(subtitle)}</span>}
      </span>
    </Pressable>
  );
}
