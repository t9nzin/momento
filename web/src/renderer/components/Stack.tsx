import type { CSSProperties } from 'react';
import type { RendererProps } from '../types';
import { Pressable } from './Pressable';
import styles from './Stack.module.css';

function spacingStyle(spacing: number | undefined): CSSProperties {
  return { '--spacing': spacing ?? 0 } as CSSProperties;
}

export function Column({ node, children, onAction }: RendererProps<'column'>) {
  return (
    <Pressable type="column" id={node.id} className={styles.column} style={spacingStyle(node.props?.spacing)} onPress={onAction}>
      {children}
    </Pressable>
  );
}

export function Row({ node, children, onAction }: RendererProps<'row'>) {
  return (
    <Pressable type="row" id={node.id} className={styles.row} style={spacingStyle(node.props?.spacing)} onPress={onAction}>
      {children}
    </Pressable>
  );
}
