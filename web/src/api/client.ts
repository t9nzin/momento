import type { Screen } from '../schema/types';
import { contextHeaders, type ClientContext } from './clientContext';

export class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export interface ScreenResponse {
  screen: Screen;
  /** The layout variant the server served, from the X-Variant header. */
  variant: string | null;
}

export async function fetchScreen(
  screenId: string,
  params: Record<string, string>,
  context: ClientContext,
): Promise<ScreenResponse> {
  const query = new URLSearchParams(params);
  if (context.variant !== 'auto') query.set('variant', context.variant);
  const queryString = query.toString();
  const url = `${__API_BASE__}/api/screens/${encodeURIComponent(screenId)}${queryString ? `?${queryString}` : ''}`;
  const response = await fetch(url, { headers: contextHeaders(context) });
  if (!response.ok) throw await toApiError(response);
  return { screen: (await response.json()) as Screen, variant: response.headers.get('X-Variant') };
}

/** Calls an API path named by a `request` action. */
export async function sendRequest(method: string, path: string, context: ClientContext): Promise<void> {
  const response = await fetch(`${__API_BASE__}${path}`, { method, headers: contextHeaders(context) });
  if (!response.ok) throw await toApiError(response);
}

async function toApiError(response: Response): Promise<ApiError> {
  let detail = response.statusText;
  try {
    const body = (await response.json()) as { detail?: string };
    detail = body.detail ?? detail;
  } catch {
    // Not a problem+json body; keep the status text.
  }
  return new ApiError(response.status, detail || `Request failed with ${response.status}`);
}
