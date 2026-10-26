import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes, useLocation } from 'react-router-dom';
import { DEFAULT_CLIENT_CONTEXT } from '../api/clientContext';
import { ROUTER_FUTURE_FLAGS } from '../routerFutureFlags';
import type { Screen } from '../schema/types';
import { loadFixture } from '../test/fixtures';
import { mockServer, screenCalls } from '../test/mockServer';
import { ScreenPage } from './ScreenPage';

function LocationProbe() {
  const location = useLocation();
  return <output data-testid="location">{location.pathname + location.search}</output>;
}

function renderAt(path: string) {
  return render(
    <MemoryRouter initialEntries={[path]} future={ROUTER_FUTURE_FLAGS}>
      <Routes>
        <Route path="/screens/:screenId" element={<ScreenPage context={DEFAULT_CLIENT_CONTEXT} />} />
      </Routes>
      <LocationProbe />
    </MemoryRouter>,
  );
}

/** Item detail whose favourite label flips after the POST, like the real server. */
function detailServer() {
  let favorite = true;
  return mockServer(({ method, url }) => {
    if (method === 'GET' && url.pathname === '/api/screens/gallery') return { body: loadFixture('gallery-variant-a.json') };
    if (method === 'GET' && url.pathname === '/api/screens/item-detail') {
      const detail: Screen = loadFixture('item-detail.json');
      const label = favorite ? '♥ Favourite' : '♡ Add to favourites';
      return { body: JSON.parse(JSON.stringify(detail).replace('♥ Favourite', label)) };
    }
    if (method === 'POST' && url.pathname === '/api/items/1/favorite') {
      favorite = !favorite;
      return { body: {} };
    }
    return undefined;
  });
}

describe('ScreenPage', () => {
  it('sends the client context headers with every screen request', async () => {
    const { calls } = detailServer();
    renderAt('/screens/gallery');

    await screen.findByRole('heading', { name: 'My keepsakes' });

    expect(calls[0].url.href).toBe('http://api.test/api/screens/gallery');
    expect(calls[0].headers).toEqual({
      'X-User-Id': 'web-demo-user',
      'X-Platform': 'web',
      'X-Schema-Version': '1',
      'X-Supported-Components': 'column,row,text,image,card,grid,list,button,spacer',
    });
  });

  it('navigates from a gallery card to its item detail screen', async () => {
    const { calls } = detailServer();
    renderAt('/screens/gallery');

    await userEvent.click(await screen.findByRole('button', { name: /Ticket stub/ }));

    expect(await screen.findByText('Kept since 2016')).toBeInTheDocument();
    expect(screen.getByTestId('location')).toHaveTextContent('/screens/item-detail?itemId=1');
    expect(screenCalls(calls, 'item-detail')[0].url.searchParams.get('itemId')).toBe('1');
  });

  it('runs a request action then refreshes the screen', async () => {
    const { calls } = detailServer();
    renderAt('/screens/item-detail?itemId=1');

    await userEvent.click(await screen.findByRole('button', { name: '♥ Favourite' }));

    expect(await screen.findByRole('button', { name: '♡ Add to favourites' })).toBeInTheDocument();
    expect(calls.map((call) => `${call.method} ${call.url.pathname}`)).toEqual([
      'GET /api/screens/item-detail',
      'POST /api/items/1/favorite',
      'GET /api/screens/item-detail',
    ]);
  });

  it('shows the server error when a screen cannot be loaded', async () => {
    mockServer(() => ({ status: 404, body: { detail: "No screen with id 'nope'" } }));
    renderAt('/screens/nope');

    expect(await screen.findByRole('alert')).toHaveTextContent("No screen with id 'nope'");
  });

  it('keeps the last good screen when a refresh fails', async () => {
    const error = jest.spyOn(console, 'error').mockImplementation(() => {});
    let detailRequests = 0;
    mockServer(({ method, url }) => {
      if (method === 'GET' && url.pathname === '/api/screens/item-detail') {
        detailRequests += 1;
        return detailRequests === 1
          ? { body: loadFixture('item-detail.json') }
          : { status: 500, body: { detail: 'down' } };
      }
      if (method === 'POST') return { body: {} };
      return undefined;
    });
    renderAt('/screens/item-detail?itemId=1');

    await userEvent.click(await screen.findByRole('button', { name: '♥ Favourite' }));

    await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent('Refresh failed: down'));
    expect(screen.getByText('Kept since 2016')).toBeInTheDocument();
    error.mockRestore();
  });
});
