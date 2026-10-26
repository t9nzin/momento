import { useCallback, useState } from 'react';
import { DEFAULT_CLIENT_CONTEXT, type ClientContext } from '../api/clientContext';
import { COMPONENT_TYPES } from '../schema/types';

const STORAGE_KEY = 'momento.sdui.clientContext';

function load(): ClientContext {
  try {
    const stored = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? 'null') as Partial<ClientContext> | null;
    if (!stored) return DEFAULT_CLIENT_CONTEXT;
    return {
      userId: stored.userId ?? DEFAULT_CLIENT_CONTEXT.userId,
      variant: stored.variant ?? DEFAULT_CLIENT_CONTEXT.variant,
      supportedComponents: (stored.supportedComponents ?? COMPONENT_TYPES).filter((type) =>
        COMPONENT_TYPES.includes(type),
      ),
    };
  } catch {
    return DEFAULT_CLIENT_CONTEXT;
  }
}

/**
 * The client context the dev panel edits, remembered across reloads. Each
 * change produces a new object, which is what makes screens refetch.
 */
export function useClientContext() {
  const [context, setContext] = useState<ClientContext>(load);

  const update = useCallback((changes: Partial<ClientContext>) => {
    setContext((current) => {
      const next = { ...current, ...changes };
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      } catch {
        // Storage can be unavailable (private mode); the panel still works for this session.
      }
      return next;
    });
  }, []);

  const reset = useCallback(() => update(DEFAULT_CLIENT_CONTEXT), [update]);

  return { context, update, reset };
}
