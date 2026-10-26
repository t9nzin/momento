/**
 * TypeScript mirror of the v1 screen schema. The server's Java records are the
 * source of truth; /schema/fixtures holds real examples of both.
 */

export const SCHEMA_VERSION = 1;

export interface NavigateAction {
  type: 'navigate';
  screenId: string;
  params?: Record<string, string>;
}

export interface RequestAction {
  type: 'request';
  method: string;
  path: string;
  /** Re-fetch the current screen once the request succeeds. */
  refresh?: boolean;
}

export type Action = NavigateAction | RequestAction;

export interface ColumnNode {
  type: 'column';
  id: string;
  props?: { spacing?: number };
  children: ComponentNode[];
  action?: Action;
}

export interface RowNode {
  type: 'row';
  id: string;
  props?: { spacing?: number };
  children: ComponentNode[];
  action?: Action;
}

export type TextStyle = 'title' | 'headline' | 'body' | 'caption';

export interface TextNode {
  type: 'text';
  id: string;
  props: { text: string; style?: TextStyle };
}

export interface ImageNode {
  type: 'image';
  id: string;
  props: { url: string; alt?: string; aspectRatio?: number };
}

export interface CardNode {
  type: 'card';
  id: string;
  props: { imageUrl?: string; title: string; subtitle?: string };
  action?: Action;
}

export interface GridNode {
  type: 'grid';
  id: string;
  props: { columns: number; itemsBinding: string };
  template: ComponentNode;
}

export interface ListNode {
  type: 'list';
  id: string;
  props: { itemsBinding: string };
  template: ComponentNode;
}

export interface ButtonNode {
  type: 'button';
  id: string;
  props: { label: string; style?: 'primary' | 'secondary' };
  action: Action;
}

export interface SpacerNode {
  type: 'spacer';
  id: string;
  props: { size: number };
}

export type ComponentNode =
  | ColumnNode
  | RowNode
  | TextNode
  | ImageNode
  | CardNode
  | GridNode
  | ListNode
  | ButtonNode
  | SpacerNode;

export type ComponentType = ComponentNode['type'];

export type NodeOfType<T extends ComponentType> = Extract<ComponentNode, { type: T }>;

export const COMPONENT_TYPES: readonly ComponentType[] = [
  'column',
  'row',
  'text',
  'image',
  'card',
  'grid',
  'list',
  'button',
  'spacer',
];

export interface Screen {
  schemaVersion: number;
  screenId: string;
  title: string;
  data: Record<string, unknown>;
  root: ComponentNode;
}
