import type { ReactNode } from 'react';
import { resolveBindings, resolvePath, withItem, type Scope } from '../schema/bindings';
import type { ComponentNode, ComponentType } from '../schema/types';
import { useActionDispatcher } from './ActionContext';
import { registry } from './registry';
import { UnknownComponent } from './components/UnknownComponent';
import type { RendererProps } from './types';

interface Props {
  node: ComponentNode;
  scope: Scope;
}

function isKnownType(type: string): type is ComponentType {
  return Object.prototype.hasOwnProperty.call(registry, type);
}

/**
 * Renders one node and, recursively, everything beneath it. This is the only
 * place that knows about scope, children and templates; registered components
 * just draw what they are given.
 */
export function ComponentRenderer({ node, scope }: Props) {
  const dispatch = useActionDispatcher();

  if (!isKnownType(node.type)) {
    return <UnknownComponent type={node.type} id={node.id} />;
  }

  const resolved = { ...node, props: resolveBindings(node.props, scope) } as ComponentNode;
  const action = 'action' in node ? node.action : undefined;
  const onAction = action ? () => dispatch(resolveBindings(action, scope)) : undefined;

  // The registry is keyed by type, so this lookup is always the matching component.
  const Component = registry[node.type] as React.ComponentType<RendererProps<ComponentType>>;
  return (
    <Component node={resolved} onAction={onAction}>
      {renderChildren(node, scope)}
    </Component>
  );
}

function renderChildren(node: ComponentNode, scope: Scope): ReactNode {
  if ('children' in node) {
    return node.children.map((child) => <ComponentRenderer key={child.id} node={child} scope={scope} />);
  }
  if ('template' in node) {
    const items = resolvePath(scope, node.props.itemsBinding);
    if (!Array.isArray(items)) {
      console.warn(`[sdui] ${node.type} "${node.id}": itemsBinding "${node.props.itemsBinding}" is not an array`);
      return null;
    }
    return items.map((item, index) => (
      <ComponentRenderer key={itemKey(item, index)} node={node.template} scope={withItem(scope, item)} />
    ));
  }
  return null;
}

function itemKey(item: unknown, index: number): string | number {
  const id = item !== null && typeof item === 'object' ? (item as { id?: unknown }).id : undefined;
  return typeof id === 'string' || typeof id === 'number' ? id : index;
}
