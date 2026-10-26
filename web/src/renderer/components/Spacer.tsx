import type { RendererProps } from '../types';

export function Spacer({ node }: RendererProps<'spacer'>) {
  return <div aria-hidden style={{ flex: 'none', width: node.props.size, height: node.props.size }} data-sdui-type="spacer" data-sdui-id={node.id} />;
}
