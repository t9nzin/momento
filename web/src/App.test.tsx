import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { App } from './App';
import { ROUTER_FUTURE_FLAGS } from './routerFutureFlags';
import { loadFixture } from './test/fixtures';
import { mockServer, screenCalls } from './test/mockServer';

/** A fake server that picks the gallery fixture the way the real one would. */
function galleryServer() {
  return mockServer(({ url, headers }) => {
    if (url.pathname !== '/api/screens/gallery') return undefined;
    const supported = headers['X-Supported-Components'].split(',');
    const variant = url.searchParams.get('variant') ?? 'A';
    const fixture = !supported.includes('grid')
      ? 'gallery-fallback.json'
      : variant === 'B'
        ? 'gallery-variant-b.json'
        : 'gallery-variant-a.json';
    return { body: loadFixture(fixture), headers: { 'X-Variant': variant } };
  });
}

function renderApp() {
  return render(
    <MemoryRouter initialEntries={['/']} future={ROUTER_FUTURE_FLAGS}>
      <App />
    </MemoryRouter>,
  );
}

beforeEach(() => localStorage.clear());

describe('App dev panel', () => {
  it('shows the variant the server served', async () => {
    galleryServer();
    renderApp();

    await waitFor(() => expect(screen.getByLabelText('Served variant')).toHaveTextContent('variant A'));
  });

  it('forces a variant through the query string', async () => {
    const { calls } = galleryServer();
    renderApp();
    await screen.findByRole('heading', { name: 'My keepsakes' });

    await userEvent.click(screen.getByText('Dev panel'));
    await userEvent.click(screen.getByRole('radio', { name: 'B' }));

    await waitFor(() => expect(screen.getAllByRole('listitem')).toHaveLength(8));
    expect(screenCalls(calls, 'gallery').at(-1)!.url.searchParams.get('variant')).toBe('B');
  });

  it('drops a component from the supported list and refetches, demoing the fallback', async () => {
    const { calls } = galleryServer();
    const { container } = renderApp();
    await screen.findByRole('heading', { name: 'My keepsakes' });

    await userEvent.click(screen.getByText('Dev panel'));
    await userEvent.click(screen.getByRole('checkbox', { name: 'grid' }));

    await waitFor(() => expect(container.querySelector('[data-sdui-type="grid"]')).toBeNull());
    expect(screenCalls(calls, 'gallery').at(-1)!.headers['X-Supported-Components']).toBe(
      'column,row,text,image,card,list,button,spacer',
    );
  });

  it('sends an edited user id and remembers it across reloads', async () => {
    const { calls } = galleryServer();
    const { unmount } = renderApp();
    await screen.findByRole('heading', { name: 'My keepsakes' });

    await userEvent.click(screen.getByText('Dev panel'));
    const input = screen.getByLabelText('User id');
    await userEvent.clear(input);
    await userEvent.type(input, 'grace');

    await waitFor(() => expect(screenCalls(calls, 'gallery').at(-1)!.headers['X-User-Id']).toBe('grace'));
    unmount();
    renderApp();
    await userEvent.click(screen.getByText('Dev panel'));
    expect(screen.getByLabelText('User id')).toHaveValue('grace');
  });
});
