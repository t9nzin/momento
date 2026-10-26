import type { CSSProperties } from 'react';
import type { RendererProps } from '../types';
import styles from './Grid.module.css';

export function Grid({ node, children }: RendererProps<'grid'>) {
  const style = { '--columns': Math.max(1, node.props.columns) } as CSSProperties;
  return (
    <div className={styles.grid} style={style} data-sdui-type="grid" data-sdui-id={node.id}>
      {children}
    </div>
  );
}
