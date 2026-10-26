import { createActionHandler, screenPath } from './actionHandler';

function setup() {
  const deps = {
    navigate: jest.fn(),
    request: jest.fn().mockResolvedValue(undefined),
    refresh: jest.fn(),
  };
  return { deps, handle: createActionHandler(deps) };
}

describe('createActionHandler', () => {
  it('maps navigate to a client-side route with params as the query string', async () => {
    const { deps, handle } = setup();

    await handle({ type: 'navigate', screenId: 'item-detail', params: { itemId: '3' } });

    expect(deps.navigate).toHaveBeenCalledWith('/screens/item-detail?itemId=3');
    expect(deps.request).not.toHaveBeenCalled();
  });

  it('maps request to a call followed by a refresh', async () => {
    const { deps, handle } = setup();

    await handle({ type: 'request', method: 'POST', path: '/api/items/3/favorite', refresh: true });

    expect(deps.request).toHaveBeenCalledWith('POST', '/api/items/3/favorite');
    expect(deps.refresh).toHaveBeenCalledTimes(1);
    expect(deps.request.mock.invocationCallOrder[0]).toBeLessThan(deps.refresh.mock.invocationCallOrder[0]);
  });

  it('skips the refresh when the action does not ask for one', async () => {
    const { deps, handle } = setup();

    await handle({ type: 'request', method: 'POST', path: '/x' });

    expect(deps.refresh).not.toHaveBeenCalled();
  });

  it('does not refresh when the request fails', async () => {
    const { deps, handle } = setup();
    deps.request.mockRejectedValue(new Error('boom'));

    await expect(handle({ type: 'request', method: 'POST', path: '/x', refresh: true })).rejects.toThrow('boom');
    expect(deps.refresh).not.toHaveBeenCalled();
  });
});

describe('screenPath', () => {
  it('omits the query string when there are no params', () => {
    expect(screenPath('gallery')).toBe('/screens/gallery');
  });

  it('encodes ids and params', () => {
    expect(screenPath('a b', { q: 'x&y' })).toBe('/screens/a%20b?q=x%26y');
  });
});
