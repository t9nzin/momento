import type { Screen } from '../schema/types';

export interface RecordedCall {
  method: string;
  url: URL;
  headers: Record<string, string>;
}

type Route = (call: RecordedCall) => { status?: number; body: unknown } | undefined;

/**
 * Replaces global fetch with a tiny router so page-level tests can exercise
 * real request flows. Every call is recorded for assertions.
 */
export function mockServer(route: Route) {
  const calls: RecordedCall[] = [];
  const fetchMock = jest.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
    const call: RecordedCall = {
      method: init.method ?? 'GET',
      url: new URL(String(input)),
      headers: (init.headers ?? {}) as Record<string, string>,
    };
    calls.push(call);
    const result = route(call) ?? { status: 404, body: { detail: `No mock for ${call.method} ${call.url.pathname}` } };
    const status = result.status ?? 200;
    return {
      ok: status >= 200 && status < 300,
      status,
      statusText: String(status),
      json: async () => result.body,
    } as Response;
  });
  global.fetch = fetchMock as typeof fetch;
  return { calls, fetchMock };
}

export function screenCalls(calls: RecordedCall[], screenId: string): RecordedCall[] {
  return calls.filter((call) => call.method === 'GET' && call.url.pathname === `/api/screens/${screenId}`);
}

export type { Screen };
