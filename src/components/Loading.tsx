import styles from './Loading.module.css';

export function Loading({ label = '読み込み中…' }: { label?: string }) {
  return (
    <p className={styles.loading} role="status">
      {label}
    </p>
  );
}
