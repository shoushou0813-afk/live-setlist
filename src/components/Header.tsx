import { NavLink } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useArchive } from './ArchiveProvider';
import styles from './Header.module.css';

export function Header() {
  const { lives, songs } = useArchive();

  return (
    <header className={styles.header}>
      <div className={styles.top}>
        <h1 className={styles.title}>演奏した曲</h1>
        <button className={styles.logout} onClick={() => void supabase.auth.signOut()}>
          ログアウト
        </button>
      </div>
      <p className={styles.sub}>
        {lives.length}本のライブ ／ {songs.length}曲
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
