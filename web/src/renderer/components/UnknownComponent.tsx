import { useEffect } from 'react';
import styles from './UnknownComponent.module.css';

interface Props {
  type: string;
  id: string;
}

/**
 * Stand-in for a component type this client does not know. Keeps the rest of
 * the screen rendering and makes the gap visible rather than silent.
 */
export function UnknownComponent({ type, id }: Props) {
  useEffect(() => {
    console.warn(`[sdui] unknown component type "${type}" (id "${id}"); rendering fallback`);
  }, [type, id]);

  return (
    <div className={styles.unknown} role="note" data-sdui-type="unknown" data-sdui-id={id}>
      Unsupported component: {type}
    </div>
  );
}
