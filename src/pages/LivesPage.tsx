import { useState } from 'react';
import { useArchive } from '../components/ArchiveProvider';
import { LiveEditor } from '../components/LiveEditor';
import { Loading } from '../components/Loading';
import { deleteLive, type Live } from '../lib/api/lives';
import { formatDate } from '../lib/setlist';
import styles from './LivesPage.module.css';

/** 編集モーダルの状態。閉じている / 新規追加 / 既存の編集 の 3 通り */
type EditorState = { open: false } | { open: true; live: Live | null };

export function LivesPage() {
  const { lives, loading, error, reload } = useArchive();
  const [editor, setEditor] = useState<EditorState>({ open: false });
  const [openLiveId, setOpenLiveId] = useState<string | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  const handleDelete = async (live: Live) => {
    if (!confirm(`「${live.title}」を削除しますか？この操作は取り消せません。`)) return;
    setDeleteError(null);
    try {
      await deleteLive(live.id);
      setOpenLiveId(null);
      await reload();
    } catch (e) {
      console.error(e);
      setDeleteError('削除できませんでした。通信状況を確認してもう一度お試しください。');
    }
  };

  if (loading) return <Loading />;
  if (error) return <p className={styles.error} role="alert">{error}</p>;

  return (
    <section className={styles.section}>
      <button className={styles.add} onClick={() => setEditor({ open: true, live: null })}>
        ＋ ライブを追加
      </button>

      {deleteError && (
        <p className={styles.error} role="alert">
          {deleteError}
        </p>
      )}

      {lives.length === 0 ? (
        <p className={styles.empty}>最初のライブを追加すると、ここに並びます。</p>
      ) : (
        <div className={styles.sheets}>
          {lives.map((live) => {
            const open = openLiveId === live.id;
            return (
              <article key={live.id} className={styles.sheet}>
                <div className={styles.tape} />
                <button
                  className={styles.open}
                  onClick={() => setOpenLiveId(open ? null : live.id)}
                  aria-expanded={open}
                >
                  <span className={styles.date}>{formatDate(live.performedOn)}</span>
                  <span className={styles.name}>{live.title}</span>
                  {live.venue && <span className={styles.venue}>{live.venue}</span>}
                  {!open && (
                    <span className={styles.venue}>{live.songs.length}曲 ・ タップで開く</span>
                  )}
                </button>

                {open && (
                  <>
                    {live.songs.length === 0 ? (
                      <p className={styles.venue}>曲が登録されていません。</p>
                    ) : (
                      <ol className={styles.songs}>
                        {live.songs.map((song, index) => (
                          // 同じライブで同じ曲を 2 回演奏することがあるので、曲名ではなく曲順をキーにする
                          <li key={`${index}-${song}`}>{song}</li>
                        ))}
                      </ol>
                    )}
                    <div className={styles.row}>
                      <button onClick={() => setEditor({ open: true, live })}>編集</button>
                      <button className={styles.danger} onClick={() => void handleDelete(live)}>
                        削除
                      </button>
                    </div>
                  </>
                )}
              </article>
            );
          })}
        </div>
      )}

      {editor.open && (
        <LiveEditor
          live={editor.live}
          onCancel={() => setEditor({ open: false })}
          onSaved={() => {
            setEditor({ open: false });
            void reload();
          }}
        />
      )}
    </section>
  );
}
