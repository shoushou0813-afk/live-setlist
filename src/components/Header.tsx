import { NavLink, useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useArchive } from './ArchiveProvider';
import { useCircle } from './CircleProvider';
import styles from './Header.module.css';

export function Header() {
  const { lives, songs } = useArchive();
  const { current, memberships, members, selectCircle } = useCircle();
  const navigate = useNavigate();

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
