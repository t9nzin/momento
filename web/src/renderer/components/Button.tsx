import type { RendererProps } from '../types';
import styles from './Button.module.css';

export function Button({ node, onAction }: RendererProps<'button'>) {
  const variant = node.props.style === 'secondary' ? styles.secondary : styles.primary;
  return (
    <button
      type="button"
      className={`${styles.button} ${variant}`}
      onClick={onAction}
      data-sdui-type="button"
      data-sdui-id={node.id}
    >
      {String(node.props.label)}
    </button>
  );
}
