import { useState } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { regenerateInviteCode } from '../lib/api/circles';
import { supabase } from '../lib/supabase';
import { useArchive } from './ArchiveProvider';
import { useCircle } from './CircleProvider';
import styles from './Header.module.css';

export function Header() {
  const { lives, songs } = useArchive();
  const { current, memberships, members, selectCircle, reloadCircles } = useCircle();
  const navigate = useNavigate();
  const [regenerating, setRegenerating] = useState(false);
  const [codeError, setCodeError] = useState<string | null>(null);

  // 招待コードが部外に漏れたときや、外した部員に入り直されたくないときに管理者が使う
  async function handleRegenerateCode(circleId: string) {
    const ok = window.confirm(
      '招待コードを作り直しますか？\nいまのコードは使えなくなります（すでに参加している部員には影響しません）。',
    );
    if (!ok) return;

    setRegenerating(true);
    setCodeError(null);
    try {
      await regenerateInviteCode(circleId);
      await reloadCircles();
    } catch (e) {
      console.error(e);
      setCodeError('招待コードを作り直せませんでした。通信状況を確認して、もう一度お試しください。');
    } finally {
      setRegenerating(false);
    }
  }

  return (
    <header className={styles.header}>
      <div className={styles.top}>
        <div>
          <h1 className={styles.title}>演奏した曲</h1>
          {current && (
            <p className={styles.circle}>
              {/* 複数のサークルに入っている人だけ切り替えを出す */}
              {memberships.length > 1 ? (
                <select
                  value={current.circleId}
                  onChange={(e) => selectCircle(e.target.value)}
                  aria-label="サークルを切り替え"
                >
                  {memberships.map((membership) => (
                    <option key={membership.circleId} value={membership.circleId}>
                      {membership.circleName}
                    </option>
                  ))}
                </select>
              ) : (
                current.circleName
              )}
              <span className={styles.code}>招待コード {current.inviteCode}</span>
              {/* ボタンは管理者にだけ出す。権限の判定そのものは DB 側の RPC が行う */}
              {current.role === 'admin' && (
                <button
                  className={styles.regenerate}
                  disabled={regenerating}
                  onClick={() => void handleRegenerateCode(current.circleId)}
                >
                  {regenerating ? '作り直し中…' : '作り直す'}
                </button>
              )}
            </p>
          )}
          {codeError && (
            <p className={styles.codeError} role="alert">
              {codeError}
            </p>
          )}
        </div>
        <button className={styles.logout} onClick={() => void supabase.auth.signOut()}>
          ログアウト
        </button>
      </div>
      <p className={styles.sub}>
        {lives.length}本のライブ ／ {songs.length}曲 ／ {members.length}人
        <button className={styles.join} onClick={() => navigate('/join')}>
          サークルを追加
        </button>
      </p>
      <nav className={styles.nav}>
        <NavLink to="/" end className={({ isActive }) => (isActive ? styles.on : undefined)}>
          曲一覧
        </NavLink>
        <NavLink to="/lives" className={({ isActive }) => (isActive ? styles.on : undefined)}>
          ライブ
        </NavLink>
      </nav>
    </header>
  );
}
