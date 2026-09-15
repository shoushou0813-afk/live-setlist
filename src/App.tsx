import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { ArchiveProvider } from './components/ArchiveProvider';
import { Header } from './components/Header';
import { RequireAuth } from './components/RequireAuth';
import { LivesPage } from './pages/LivesPage';
import { LoginPage } from './pages/LoginPage';
import { SongsPage } from './pages/SongsPage';
import styles from './App.module.css';

/** ログインが必要な画面の共通の枠（ヘッダー＋データ供給） */
function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <RequireAuth>
      <ArchiveProvider>
        <div className={styles.app}>
          <Header />
          {children}
        </div>
      </ArchiveProvider>
    </RequireAuth>
  );
}

export function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route
          path="/"
          element={
            <AppLayout>
              <SongsPage />
            </AppLayout>
          }
        />
        <Route
          path="/lives"
          element={
            <AppLayout>
              <LivesPage />
            </AppLayout>
          }
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
