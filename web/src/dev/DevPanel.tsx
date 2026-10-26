import { useId } from 'react';
import type { ClientContext, VariantChoice } from '../api/clientContext';
import { COMPONENT_TYPES, type ComponentType } from '../schema/types';
import styles from './DevPanel.module.css';

interface Props {
  context: ClientContext;
  servedVariant: string | null;
  onChange: (changes: Partial<ClientContext>) => void;
  onReset: () => void;
}

const VARIANTS: VariantChoice[] = ['auto', 'A', 'B'];

/**
 * Edits the context this client sends, so layout variants and capability
 * fallback can be demoed live without touching the server.
 */
export function DevPanel({ context, servedVariant, onChange, onReset }: Props) {
  const userIdInput = useId();

  function toggleComponent(type: ComponentType, enabled: boolean) {
    const next = enabled
      ? COMPONENT_TYPES.filter((t) => t === type || context.supportedComponents.includes(t))
      : context.supportedComponents.filter((t) => t !== type);
    onChange({ supportedComponents: next });
  }

  return (
    <details className={styles.panel}>
      <summary className={styles.summary}>
        Dev panel
        <span className={styles.badge} aria-label="Served variant">
          {servedVariant ? `variant ${servedVariant}` : '…'}
        </span>
      </summary>

      <div className={styles.body}>
        <label className={styles.field} htmlFor={userIdInput}>
          <span className={styles.label}>User id</span>
          <input
            id={userIdInput}
            className={styles.input}
            value={context.userId}
            onChange={(event) => onChange({ userId: event.target.value })}
          />
        </label>

        <fieldset className={styles.field}>
          <legend className={styles.label}>Variant</legend>
          <div className={styles.segmented}>
            {VARIANTS.map((variant) => (
              <label key={variant} className={styles.segment}>
                <input
                  type="radio"
                  name="variant"
                  value={variant}
                  checked={context.variant === variant}
                  onChange={() => onChange({ variant })}
                />
                <span>{variant === 'auto' ? 'Auto (by user id)' : variant}</span>
              </label>
            ))}
          </div>
        </fieldset>

        <fieldset className={styles.field}>
          <legend className={styles.label}>Supported components</legend>
          <div className={styles.checkboxes}>
            {COMPONENT_TYPES.map((type) => (
              <label key={type} className={styles.checkbox}>
                <input
                  type="checkbox"
                  checked={context.supportedComponents.includes(type)}
                  onChange={(event) => toggleComponent(type, event.target.checked)}
                />
                <code>{type}</code>
              </label>
            ))}
          </div>
        </fieldset>

        <button type="button" className={styles.reset} onClick={onReset}>
          Reset
        </button>
      </div>
    </details>
  );
}
