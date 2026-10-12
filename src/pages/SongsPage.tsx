import { useMemo, useState } from 'react';
import { useArchive } from '../components/ArchiveProvider';
import { Loading } from '../components/Loading';
import { StageNotes } from '../components/StageNotes';
import { fetchSongHistory, type SongPerformance } from '../lib/api/songs';
import {
  filterSongs,
  formatDate,
  hasStageNotes,
  maxPlayCount,
  sortSongs,
  type SongSort,
} from '../lib/setlist';
import styles from './SongsPage.module.css';

/** 開いている曲の演奏記録（PA・照明の設定つき）。曲をタップしたときだけ取りに行く */
type OpenSong = {
  id: string;
  history: SongPerformance[] | null;
  error: string | null;
};

export function SongsPage() {
  const { songs, loading, error } = useArchive();
  const [query, setQuery] = useState('');
  const [sort, setSort] = useState<SongSort>('count');
  const [open, setOpen] = useState<OpenSong | null>(null);

  const visibleSongs = useMemo(
    () => sortSongs(filterSongs(songs, query), sort),
    [songs, query, sort],
  );
  // バーの長さは絞り込み後ではなく全体の最大値を基準にして、検索しても長さが変わらないようにする
  const max = useMemo(() => maxPlayCount(songs), [songs]);

  const toggleSong = async (songId: string) => {
    if (open?.id === songId) {
      setOpen(null);
      return;
    }
    setOpen({ id: songId, history: null, error: null });
    try {
      const history = await fetchSongHistory(songId);
      // 開いている間に別の曲をタップされていたら、遅れて届いた結果は捨てる
      setOpen((current) => (current?.id === songId ? { ...current, history } : current));
    } catch (e) {
      console.error(e);
      setOpen((current) =>
        current?.id === songId
          ? { ...current, error: '読み込めませんでした。もう一度タップしてください。' }
          : current,
      );
    }
  };

  if (loading) return <Loading />;
  if (error) return <p className={styles.error} role="alert">{error}</p>;

  return (
    <section className={styles.section}>
      <div className={styles.tools}>
        <label className={styles.search}>
          <span className={styles.icon} aria-hidden="true">
            🔍
          </span>
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="曲名で探す"
            aria-label="曲名で探す"
          />
        </label>
        <select
          value={sort}
          onChange={(e) => setSort(e.target.value as SongSort)}
          aria-label="並び替え"
        >
          <option value="count">演奏回数順</option>
          <option value="last">最近やった順</option>
          <option value="name">曲名順</option>
        </select>
      </div>

      {songs.length === 0 ? (
        <p className={styles.empty}>
          まだ曲がありません。「ライブ」タブからセットリストを追加してください。
        </p>
      ) : visibleSongs.length === 0 ? (
        <p className={styles.empty}>「{query}」に一致する曲はありませんでした。</p>
      ) : (
        <ul className={styles.songs}>
          {visibleSongs.map((song) => {
            const isOpen = open?.id === song.id;
            return (
              <li key={song.id}>
                <button
                  className={styles.songRow}
                  onClick={() => void toggleSong(song.id)}
                  aria-expanded={isOpen}
                >
                  <span className={styles.name}>
                    {song.title}
                    <span className={styles.last}>最終 {formatDate(song.lastPlayedOn)}</span>
                  </span>
                  <span className={styles.bar} aria-hidden="true">
                    <span style={{ width: `${(song.playCount / max) * 100}%` }} />
                  </span>
                  <span className={styles.count}>{song.playCount}回</span>
                </button>

                {isOpen && (
                  <div className={styles.where}>
                    {open.error ? (
                      <p role="alert">{open.error}</p>
                    ) : open.history === null ? (
                      <p>読み込み中…</p>
                    ) : (
                      <>
                        {/* 記録が 1 件も無いときは、どこで入力すればいいかまで案内する */}
                        {!open.history.some(hasStageNotes) && (
                          <p>
                            この曲にはまだPA・照明の記録がありません。ライブの編集画面の「PA・照明・手順」から残せます。
                          </p>
                        )}
                        <ul>
                          {open.history.map((performance, index) => (
                            <li key={`${performance.liveId}-${performance.position}`}>
                              <span className={styles.date}>
                                {formatDate(performance.performedOn)}
                              </span>
                              {/* 一番新しい演奏が次に同じ曲をやるときの手本になるので目印を付ける */}
                              {index === 0 && <span className={styles.latest}>前回</span>}
                              {performance.liveTitle}
                              {performance.venue && `（${performance.venue}）`}
                              {performance.band && (
                                <span className={styles.band}>{performance.band}</span>
                              )}
                              <StageNotes {...performance} tone="stage" />
                            </li>
                          ))}
                        </ul>
                      </>
                    )}
                  </div>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
