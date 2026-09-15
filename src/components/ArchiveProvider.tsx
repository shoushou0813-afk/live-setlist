import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import { fetchLives, type Live } from '../lib/api/lives';
import { fetchSongStats } from '../lib/api/songs';
import type { SongStat } from '../lib/setlist';

type ArchiveState = {
  lives: Live[];
  songs: SongStat[];
  loading: boolean;
  error: string | null;
  reload: () => Promise<void>;
};

const ArchiveContext = createContext<ArchiveState | null>(null);

/**
 * ライブ一覧と曲の集計をまとめて持つ。
 * ヘッダーの本数・曲数と 2 つの画面が同じデータを見るので、画面ごとに取得せず 1 か所にまとめ、
 * 保存・削除のあとは reload() で両方を取り直す（集計はビュー任せなので再計算はしない）。
 */
export function ArchiveProvider({ children }: { children: ReactNode }) {
  const [lives, setLives] = useState<Live[]>([]);
  const [songs, setSongs] = useState<SongStat[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    setError(null);
    try {
      const [nextLives, nextSongs] = await Promise.all([fetchLives(), fetchSongStats()]);
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
  }, []);

  useEffect(() => {
    void reload();
  }, [reload]);

  return (
    <ArchiveContext.Provider value={{ lives, songs, loading, error, reload }}>
      {children}
    </ArchiveContext.Provider>
  );
}

export function useArchive(): ArchiveState {
  const value = useContext(ArchiveContext);
  if (!value) throw new Error('useArchive は ArchiveProvider の中でのみ使えます');
  return value;
}
