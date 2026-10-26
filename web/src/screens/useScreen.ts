import { useCallback, useEffect, useState } from 'react';
import { fetchScreen } from '../api/client';
import type { ClientContext } from '../api/clientContext';
import type { Screen } from '../schema/types';

type State =
  | { status: 'loading'; screen?: undefined; error?: undefined }
  | { status: 'ready'; screen: Screen; error?: undefined }
  | { status: 'error'; screen?: Screen; error: Error };

/**
 * Fetches a screen and re-fetches when its inputs change or `refresh` is
 * called. A refresh keeps the current screen on display until the new one
 * arrives, so toggling a favourite doesn't flash a spinner.
 */
export function useScreen(screenId: string, params: Record<string, string>, context: ClientContext) {
  const [state, setState] = useState<State>({ status: 'loading' });
  const [refreshCount, setRefreshCount] = useState(0);
  const paramsKey = new URLSearchParams(params).toString();

  useEffect(() => {
    let cancelled = false;
    const requestParams = Object.fromEntries(new URLSearchParams(paramsKey));
    fetchScreen(screenId, requestParams, context)
      .then((screen) => !cancelled && setState({ status: 'ready', screen }))
      .catch((error: Error) => !cancelled && setState((prev) => ({ status: 'error', screen: prev.screen, error })));
    return () => {
      cancelled = true;
    };
  }, [screenId, paramsKey, context, refreshCount]);

  const refresh = useCallback(() => setRefreshCount((count) => count + 1), []);
  return { ...state, refresh };
}
