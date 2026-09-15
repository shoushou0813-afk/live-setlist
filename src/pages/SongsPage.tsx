import { useMemo, useState } from 'react';
import { useArchive } from '../components/ArchiveProvider';
import { Loading } from '../components/Loading';
import { fetchLivesForSong, type LiveOfSong } from '../lib/api/songs';
import { filterSongs, formatDate, maxPlayCount, sortSongs, type SongSort } from '../lib/setlist';
import styles from './SongsPage.module.css';

/** 開いている曲の「演奏したライブ」。曲をタップしたときだけ取りに行く */
type OpenSong = {
  id: string;
  lives: LiveOfSong[] | null;
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
    setOpen({ id: songId, lives: null, error: null });
    try {
      const lives = await fetchLivesForSong(songId);
      // 開いている間に別の曲をタップされていたら、遅れて届いた結果は捨てる
      setOpen((current) => (current?.id === songId ? { ...current, lives } : current));
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
                    ) : open.lives === null ? (
                      <p>読み込み中…</p>
                    ) : (
                      <ul>
                        {open.lives.map((live) => (
                          <li key={live.id}>
                            <span className={styles.date}>{formatDate(live.performedOn)}</span>
                            {live.title}
                            {live.venue && `（${live.venue}）`}
                          </li>
                        ))}
                      </ul>
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
