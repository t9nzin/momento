import type { ComponentType, NodeOfType } from '../schema/types';
import type { ReactNode } from 'react';

/**
 * What every registered component receives. Props are already resolved
 * against the current scope, children are already rendered, and `onAction`
 * is set only when the node has an action.
 */
export interface RendererProps<T extends ComponentType> {
  node: NodeOfType<T>;
  children?: ReactNode;
  onAction?: () => void;
}

export type ComponentRegistry = {
  [T in ComponentType]: React.ComponentType<RendererProps<T>>;
};
