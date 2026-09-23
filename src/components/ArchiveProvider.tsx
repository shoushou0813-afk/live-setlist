import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import { Outlet } from 'react-router-dom';
import { fetchLives, type Live } from '../lib/api/lives';
import { fetchSongStats } from '../lib/api/songs';
import type { SongStat } from '../lib/setlist';
import { useCircle } from './CircleProvider';

type ArchiveState = {
  lives: Live[];
  songs: SongStat[];
  loading: boolean;
  error: string | null;
  reload: () => Promise<void>;
  /** user_id を部員の表示名に変える。退部済み・不明なら「不明」 */
  memberName: (userId: string | null) => string;
};

const ArchiveContext = createContext<ArchiveState | null>(null);

/**
 * いま見ているサークルのライブ一覧と曲の集計をまとめて持つ。
 * ヘッダーの本数・曲数と 2 つの画面が同じデータを見るので、画面ごとに取得せず 1 か所にまとめ、
 * 保存・削除のあとは reload() で両方を取り直す（集計はビュー任せなので再計算はしない）。
 */
export function ArchiveProvider({ children }: { children?: ReactNode }) {
  const { current, members } = useCircle();
  const circleId = current?.circleId ?? null;

  const [lives, setLives] = useState<Live[]>([]);
  const [songs, setSongs] = useState<SongStat[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!circleId) return;
    setError(null);
    try {
      const [nextLives, nextSongs] = await Promise.all([
        fetchLives(circleId),
        fetchSongStats(circleId),
      ]);
      setLives(nextLives);
      setSongs(nextSongs);
    } catch (e) {
      console.error(e);
      setError(
        'データを読み込めませんでした。通信状況を確認してページを再読み込みしてください。',
      );
    } finally {
      setLoading(false);
    }
  }, [circleId]);

  // サークルを切り替えたら前のサークルの内容を残さない
  useEffect(() => {
    setLives([]);
    setSongs([]);
    setLoading(true);
    void reload();
  }, [reload]);

  const memberName = useCallback(
    (userId: string | null) =>
      members.find((member) => member.userId === userId)?.displayName ?? '不明',
    [members],
  );

  return (
    <ArchiveContext.Provider value={{ lives, songs, loading, error, reload, memberName }}>
      {children ?? <Outlet />}
    </ArchiveContext.Provider>
  );
}

export function useArchive(): ArchiveState {
  const value = useContext(ArchiveContext);
  if (!value) throw new Error('useArchive は ArchiveProvider の中でのみ使えます');
  return value;
}
