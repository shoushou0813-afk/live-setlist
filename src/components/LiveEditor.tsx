import { useEffect, useState } from 'react';
import { saveLive, type Live } from '../lib/api/lives';
import { parseSongTitlesFromText, songTitlesToText, validateLiveInput } from '../lib/setlist';
import styles from './LiveEditor.module.css';

type Props = {
  /** 編集対象。新規追加なら null */
  live: Live | null;
  onCancel: () => void;
  onSaved: () => void;
};

const today = () => new Date().toISOString().slice(0, 10);

export function LiveEditor({ live, onCancel, onSaved }: Props) {
  const [title, setTitle] = useState(live?.title ?? '');
  const [performedOn, setPerformedOn] = useState(live?.performedOn ?? today());
  const [venue, setVenue] = useState(live?.venue ?? '');
  // 1 曲ずつモード用。空欄が 1 つあると最初から打ち始められる
  const [songs, setSongs] = useState<string[]>(live?.songs.length ? [...live.songs] : ['']);
  const [bulk, setBulk] = useState(false);
  const [text, setText] = useState(() => songTitlesToText(live?.songs ?? []));
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // 入力モードを切り替えるときは、今表示している側の内容をもう一方に写してから切り替える
  const switchToSingle = () => {
    const parsed = parseSongTitlesFromText(text);
    setSongs(parsed.length ? parsed : ['']);
    setBulk(false);
  };
  const switchToBulk = () => {
    setText(songTitlesToText(songs));
    setBulk(true);
  };

  const updateSong = (index: number, value: string) =>
    setSongs(songs.map((song, i) => (i === index ? value : song)));

  const moveSong = (index: number, direction: -1 | 1) => {
    const target = index + direction;
    if (target < 0 || target >= songs.length) return;
    const next = [...songs];
    [next[index], next[target]] = [next[target], next[index]];
    setSongs(next);
  };

  // モーダルはキーボードだけでも閉じられるようにする
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onCancel();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [onCancel]);

  const handleSave = async () => {
    const songTitles = bulk ? parseSongTitlesFromText(text) : songs;
    const invalid = validateLiveInput({ title, performedOn, venue, songs: songTitles });
    if (invalid) {
      setError(invalid.message);
      return;
    }

    setError(null);
    setSaving(true);
    try {
      await saveLive({ id: live?.id ?? null, title, performedOn, venue, songs: songTitles });
      onSaved();
    } catch (e) {
      console.error(e);
      setError('保存できませんでした。通信状況を確認して、もう一度「保存する」を押してください。');
      setSaving(false);
    }
  };

  return (
    <div className={styles.modal} role="dialog" aria-modal="true" aria-label="セットリストの編集">
      <div className={styles.panel}>
        <div className={styles.head}>
          <h2>セットリスト</h2>
          <button onClick={onCancel} aria-label="閉じる">
            ✕
          </button>
        </div>

        <label className={styles.field}>
          ライブ名
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="例：定期ライブ vol.3"
            maxLength={100}
          />
        </label>

        <div className={styles.two}>
          <label className={styles.field}>
            日付
            <input
              type="date"
              value={performedOn}
              onChange={(e) => setPerformedOn(e.target.value)}
            />
          </label>
          <label className={styles.field}>
            会場
            <input
              value={venue}
              onChange={(e) => setVenue(e.target.value)}
              placeholder="例：下北沢〇〇"
              maxLength={100}
            />
          </label>
        </div>

        <div className={styles.mode}>
          <button className={bulk ? undefined : styles.on} onClick={switchToSingle}>
            1曲ずつ
          </button>
          <button className={bulk ? styles.on : undefined} onClick={switchToBulk}>
            まとめて貼り付け
          </button>
        </div>

        {bulk ? (
          <textarea
            rows={8}
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder={'1行に1曲\n曲名A\n曲名B'}
            aria-label="曲名（1行に1曲）"
          />
        ) : (
          <ol className={styles.edit}>
            {songs.map((song, index) => (
              // 並べ替え・削除で中身がずれるが、入力欄の同一性は「その位置」で判断してよい
              // eslint-disable-next-line react/no-array-index-key
              <li key={index}>
                <input
                  value={song}
                  onChange={(e) => updateSong(index, e.target.value)}
                  placeholder={`${index + 1}曲目`}
                  aria-label={`${index + 1}曲目`}
                />
                <button onClick={() => moveSong(index, -1)} aria-label={`${index + 1}曲目を上へ`}>
                  ↑
                </button>
                <button onClick={() => moveSong(index, 1)} aria-label={`${index + 1}曲目を下へ`}>
                  ↓
                </button>
                <button
                  onClick={() => setSongs(songs.filter((_, i) => i !== index))}
                  aria-label={`${index + 1}曲目を削除`}
                >
                  ✕
                </button>
              </li>
            ))}
            <button className={styles.more} onClick={() => setSongs([...songs, ''])}>
              ＋ 曲を追加
            </button>
          </ol>
        )}

        {error && (
          <p className={styles.error} role="alert">
            {error}
          </p>
        )}

        <button className={styles.save} onClick={() => void handleSave()} disabled={saving}>
          {saving ? '保存中…' : '保存する'}
        </button>
      </div>
    </div>
  );
}
