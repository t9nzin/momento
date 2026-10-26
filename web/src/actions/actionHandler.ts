import type { Action } from '../schema/types';

export interface ActionDeps {
  navigate: (path: string) => void;
  request: (method: string, path: string) => Promise<void>;
  refresh: () => void;
}

export function screenPath(screenId: string, params: Record<string, string> = {}): string {
  const query = new URLSearchParams(params).toString();
  return `/screens/${encodeURIComponent(screenId)}${query ? `?${query}` : ''}`;
}

/**
 * Turns schema actions into client behaviour. Dependencies are injected so the
 * mapping can be tested without a router or network.
 */
export function createActionHandler({ navigate, request, refresh }: ActionDeps) {
  return async function handle(action: Action): Promise<void> {
    switch (action.type) {
      case 'navigate':
        navigate(screenPath(action.screenId, action.params));
        return;
      case 'request':
        await request(action.method, action.path);
        if (action.refresh) refresh();
        return;
      default: {
        const unknown: never = action;
        console.warn('[sdui] ignoring unknown action', unknown);
      }
    }
  };
}
