import { Children } from 'react';
import type { RendererProps } from '../types';
import styles from './List.module.css';

export function List({ node, children }: RendererProps<'list'>) {
  return (
    <div className={styles.list} role="list" data-sdui-type="list" data-sdui-id={node.id}>
      {Children.map(children, (child) => (
        <div role="listitem">{child}</div>
      ))}
    </div>
  );
}
