import { useEffect, useMemo } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { createActionHandler } from '../actions/actionHandler';
import { sendRequest } from '../api/client';
import type { ClientContext } from '../api/clientContext';
import { ActionProvider } from '../renderer/ActionContext';
import { ComponentRenderer } from '../renderer/ComponentRenderer';
import { useScreen } from './useScreen';
import styles from './ScreenPage.module.css';

interface Props {
  context: ClientContext;
}

/** Route `/screens/:screenId`: fetches the screen named in the URL and renders it. */
export function ScreenPage({ context }: Props) {
  const { screenId = 'gallery' } = useParams();
  const [searchParams] = useSearchParams();
  const params = useMemo(() => Object.fromEntries(searchParams), [searchParams]);
  const navigate = useNavigate();
  const { status, screen, error, refresh } = useScreen(screenId, params, context);

  const dispatch = useMemo(() => {
    const handle = createActionHandler({
      navigate,
      request: (method, path) => sendRequest(method, path, context),
      refresh,
    });
    return (action: Parameters<typeof handle>[0]) => {
      handle(action).catch((err: Error) => console.error('[sdui] action failed', err));
    };
  }, [navigate, context, refresh]);

  useEffect(() => {
    if (screen) document.title = `${screen.title} · Momento`;
  }, [screen]);

  if (status === 'loading') {
    return <p className={styles.status}>Loading…</p>;
  }
  if (!screen) {
    return (
      <p className={styles.status} role="alert">
        Couldn’t load “{screenId}”: {error?.message}
      </p>
    );
  }

  return (
    <ActionProvider value={dispatch}>
      {error && (
        <p className={styles.banner} role="alert">
          Showing the last good version. Refresh failed: {error.message}
        </p>
      )}
      <ComponentRenderer node={screen.root} scope={screen.data} />
    </ActionProvider>
  );
}
