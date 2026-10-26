import type { RendererProps } from '../types';
import styles from './Image.module.css';

export function Image({ node }: RendererProps<'image'>) {
  const { url, alt, aspectRatio } = node.props;
  return (
    <img
      className={styles.image}
      src={url}
      alt={alt ?? ''}
      loading="lazy"
      style={aspectRatio ? { aspectRatio: String(aspectRatio) } : undefined}
      data-sdui-type="image"
      data-sdui-id={node.id}
    />
  );
}
