import { useEffect, useState } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';

export type SessionState = {
  session: Session | null;
  /** 復元中かどうか。これを見ないと、復元前の一瞬だけ未ログイン扱いになってログイン画面が点滅する */
  loading: boolean;
};

/**
 * ログイン状態を保持する。
 * getSession でリロード時の復元を、onAuthStateChange で以後の変化（ログイン・ログアウト・
 * トークン更新）を受け取る。この 2 つが揃っていないとタブ間で状態がずれる。
 */
export function useSession(): SessionState {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;

    supabase.auth.getSession().then(({ data }) => {
      if (!active) return;
      setSession(data.session);
      setLoading(false);
    });

    const { data: listener } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      setLoading(false);
    });

    return () => {
      active = false;
      listener.subscription.unsubscribe();
    };
  }, []);

  return { session, loading };
}
