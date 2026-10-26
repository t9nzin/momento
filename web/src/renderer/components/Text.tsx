import type { RendererProps } from '../types';
import styles from './Text.module.css';

const ELEMENT_BY_STYLE = { title: 'h1', headline: 'h2', body: 'p', caption: 'p' } as const;

export function Text({ node }: RendererProps<'text'>) {
  const style = node.props.style ?? 'body';
  const Element = ELEMENT_BY_STYLE[style] ?? 'p';
  return (
    <Element className={`${styles.text} ${styles[style] ?? ''}`} data-sdui-type="text" data-sdui-id={node.id}>
      {String(node.props.text)}
    </Element>
  );
}
