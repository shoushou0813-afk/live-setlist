import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { useSession } from '../hooks/useSession';
import { fetchMembers, fetchMyMemberships, type Member, type Membership } from '../lib/api/circles';
import { Loading } from './Loading';

/** 選んでいるサークルを覚えておくキー。複数サークルに入っている人向け */
const STORAGE_KEY = 'live-setlist:circle-id';

type CircleState = {
  /** ログイン中のユーザー ID（ライブの登録者が自分かどうかの判定に使う） */
  userId: string;
  /** 所属しているサークル全部 */
  memberships: Membership[];
  /** いま見ているサークル。1 つも所属していなければ null */
  current: Membership | null;
  /** いま見ているサークルの部員名簿（登録者名の表示に使う） */
  members: Member[];
  loading: boolean;
  error: string | null;
  selectCircle: (circleId: string) => void;
  /** 参加・作成・表示名の変更のあとに呼ぶ */
  reloadCircles: () => Promise<void>;
};

const CircleContext = createContext<CircleState | null>(null);

/**
 * 「いまどのサークルのデータを見ているか」を 1 か所で持つ。
 * ライブも曲も集計もサークル単位なので、各画面が別々に所属を調べに行かないようにまとめた。
 */
export function CircleProvider({ children }: { children?: ReactNode }) {
  const { session } = useSession();
  const userId = session?.user.id ?? '';

  const [memberships, setMemberships] = useState<Membership[]>([]);
  const [members, setMembers] = useState<Member[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(
    () => localStorage.getItem(STORAGE_KEY),
  );
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const reloadCircles = useCallback(async () => {
    if (!userId) return;
    setError(null);
    try {
      setMemberships(await fetchMyMemberships(userId));
    } catch (e) {
      console.error(e);
      setError('サークル情報を読み込めませんでした。通信状況を確認して再読み込みしてください。');
    } finally {
      setLoading(false);
    }
  }, [userId]);

  useEffect(() => {
    void reloadCircles();
  }, [reloadCircles]);

  // 保存していた ID がもう所属していないサークルのこともあるので、必ず所属の中から選び直す
  const current = useMemo(
    () => memberships.find((m) => m.circleId === selectedId) ?? memberships[0] ?? null,
    [memberships, selectedId],
  );

  useEffect(() => {
    if (current) localStorage.setItem(STORAGE_KEY, current.circleId);
  }, [current]);

  useEffect(() => {
    if (!current) {
      setMembers([]);
      return;
    }
    let active = true;
    fetchMembers(current.circleId)
      .then((next) => {
        if (active) setMembers(next);
      })
      .catch((e) => {
        // 名簿は「登録者名」の表示だけに使うので、失敗しても画面全体は止めない
        console.error(e);
        if (active) setMembers([]);
      });
    return () => {
      active = false;
    };
  }, [current]);

  const value: CircleState = {
    userId,
    memberships,
    current,
    members,
    loading,
    error,
    selectCircle: setSelectedId,
    reloadCircles,
  };

  return (
    <CircleContext.Provider value={value}>{children ?? <Outlet />}</CircleContext.Provider>
  );
}

export function useCircle(): CircleState {
  const value = useContext(CircleContext);
  if (!value) throw new Error('useCircle は CircleProvider の中でのみ使えます');
  return value;
}

/**
 * どのサークルにも入っていない人を /join（参加・作成）へ送る。
 * RequireAuth と同じく操作性のための誘導で、データを守っているのは RLS。
 */
export function RequireCircle({ children }: { children?: ReactNode }) {
  const { current, loading, error } = useCircle();

  if (loading) return <Loading label="サークルを確認中…" />;
  if (error) return <p role="alert">{error}</p>;
  if (!current) return <Navigate to="/join" replace />;

  return <>{children ?? <Outlet />}</>;
}
