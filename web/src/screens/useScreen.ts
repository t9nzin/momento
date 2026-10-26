import { useCallback, useEffect, useState } from 'react';
import { fetchScreen, type ScreenResponse } from '../api/client';
import type { ClientContext } from '../api/clientContext';

type State =
  | { status: 'loading'; response?: undefined; error?: undefined }
  | { status: 'ready'; response: ScreenResponse; error?: undefined }
  | { status: 'error'; response?: ScreenResponse; error: Error };

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
      .then((response) => !cancelled && setState({ status: 'ready', response }))
      .catch((error: Error) => !cancelled && setState((prev) => ({ status: 'error', response: prev.response, error })));
    return () => {
      cancelled = true;
    };
  }, [screenId, paramsKey, context, refreshCount]);

  const refresh = useCallback(() => setRefreshCount((count) => count + 1), []);
  return {
    status: state.status,
    screen: state.response?.screen,
    variant: state.response?.variant ?? null,
    error: state.error,
    refresh,
  };
}
