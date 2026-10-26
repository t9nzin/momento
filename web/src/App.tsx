import { Link, Navigate, Route, Routes } from 'react-router-dom';
import { DEFAULT_CLIENT_CONTEXT } from './api/clientContext';
import { ScreenPage } from './screens/ScreenPage';
import styles from './App.module.css';

export function App() {
  return (
    <div className={styles.shell}>
      <header className={styles.header}>
        <Link to="/screens/gallery" className={styles.brand}>
          momento
        </Link>
      </header>
      <main className={styles.main}>
        <Routes>
          <Route path="/" element={<Navigate to="/screens/gallery" replace />} />
          <Route path="/screens/:screenId" element={<ScreenPage context={DEFAULT_CLIENT_CONTEXT} />} />
        </Routes>
      </main>
    </div>
  );
}
