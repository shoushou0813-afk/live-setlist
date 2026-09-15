import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useSession } from '../hooks/useSession';
import { Loading } from './Loading';

/**
 * 未ログインなら /login へ送る認証ガード。
 * これは操作性のためのもので、データを守っているのは DB 側の RLS。
 * この分岐をすり抜けても他人の行は返らない。
 */
export function RequireAuth({ children }: { children: ReactNode }) {
  const { session, loading } = useSession();
  const location = useLocation();

  if (loading) return <Loading label="確認中…" />;
  if (!session) return <Navigate to="/login" replace state={{ from: location.pathname }} />;

  return <>{children}</>;
}
