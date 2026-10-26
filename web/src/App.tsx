import { useState } from 'react';
import { Link, Navigate, Route, Routes } from 'react-router-dom';
import { DevPanel } from './dev/DevPanel';
import { useClientContext } from './dev/useClientContext';
import { ScreenPage } from './screens/ScreenPage';
import styles from './App.module.css';

export function App() {
  const { context, update, reset } = useClientContext();
  const [servedVariant, setServedVariant] = useState<string | null>(null);

  return (
    <div className={styles.shell}>
      <header className={styles.header}>
        <Link to="/screens/gallery" className={styles.brand}>
          momento
        </Link>
        <DevPanel context={context} servedVariant={servedVariant} onChange={update} onReset={reset} />
      </header>
      <main className={styles.main}>
        <Routes>
          <Route path="/" element={<Navigate to="/screens/gallery" replace />} />
          <Route
            path="/screens/:screenId"
            element={<ScreenPage context={context} onVariantServed={setServedVariant} />}
          />
        </Routes>
      </main>
    </div>
  );
}
