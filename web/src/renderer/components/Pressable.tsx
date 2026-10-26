import type { CSSProperties, ReactNode } from 'react';

interface Props {
  onPress?: () => void;
  className?: string;
  style?: CSSProperties;
  type: string;
  id: string;
  children: ReactNode;
}

/**
 * A container that becomes a real <button> when it has an action, so tappable
 * cards and columns are keyboard and screen-reader accessible.
 */
export function Pressable({ onPress, className, style, type, id, children }: Props) {
  const dataProps = { 'data-sdui-type': type, 'data-sdui-id': id };
  if (!onPress) {
    return (
      <div className={className} style={style} {...dataProps}>
        {children}
      </div>
    );
  }
  return (
    <button type="button" className={className} style={style} onClick={onPress} {...dataProps}>
      {children}
    </button>
  );
}
