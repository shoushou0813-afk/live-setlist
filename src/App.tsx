import { BrowserRouter, Navigate, Outlet, Route, Routes } from 'react-router-dom';
import { ArchiveProvider } from './components/ArchiveProvider';
import { CircleProvider, RequireCircle } from './components/CircleProvider';
import { Header } from './components/Header';
import { RequireAuth } from './components/RequireAuth';
import { JoinCirclePage } from './pages/JoinCirclePage';
import { LivesPage } from './pages/LivesPage';
import { LoginPage } from './pages/LoginPage';
import { SignUpPage } from './pages/SignUpPage';
import { SongsPage } from './pages/SongsPage';
import styles from './App.module.css';

/** ログインが必要な画面の枠。所属サークルの情報をここで 1 回だけ読む */
function AuthedLayout() {
  return (
    <RequireAuth>
      <CircleProvider />
    </RequireAuth>
  );
}

/**
 * サークルのデータを見る画面の枠（ヘッダー＋データ供給）。
 * 曲一覧とライブを行き来してもここは作り直されないので、タブを切り替えるたびに
 * 取得し直さずに済む。
 */
function CircleLayout() {
  return (
    <RequireCircle>
      <ArchiveProvider>
        <div className={styles.app}>
          <Header />
          <Outlet />
        </div>
      </ArchiveProvider>
    </RequireCircle>
  );
}

export function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/signup" element={<SignUpPage />} />
        <Route element={<AuthedLayout />}>
          <Route path="/join" element={<JoinCirclePage />} />
          <Route element={<CircleLayout />}>
            <Route path="/" element={<SongsPage />} />
            <Route path="/lives" element={<LivesPage />} />
          </Route>
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
