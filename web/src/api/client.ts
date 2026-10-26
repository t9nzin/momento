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

export async function fetchScreen(
  screenId: string,
  params: Record<string, string>,
  context: ClientContext,
): Promise<Screen> {
  const query = new URLSearchParams(params).toString();
  const url = `${__API_BASE__}/api/screens/${encodeURIComponent(screenId)}${query ? `?${query}` : ''}`;
  const response = await fetch(url, { headers: contextHeaders(context) });
  if (!response.ok) throw await toApiError(response);
  return (await response.json()) as Screen;
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
