import { useState, type FormEvent } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useSession } from '../hooks/useSession';
import { Loading } from '../components/Loading';
import styles from './AuthCard.module.css';

export function LoginPage() {
  const { session, loading } = useSession();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  if (loading) return <Loading label="確認中…" />;
  if (session) return <Navigate to="/" replace />;

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    setSubmitting(true);

    const { error: signInError } = await supabase.auth.signInWithPassword({ email, password });

    if (signInError) {
      // どちらが違うかは伝えない（存在するメールアドレスを当てられないようにするため）
      setError('メールアドレスかパスワードが違います。入力を確認してもう一度お試しください。');
      setSubmitting(false);
      return;
    }
    // 成功時は onAuthStateChange が session を更新し、上の Navigate で / へ移動する
  };

  return (
    <div className={styles.page}>
      <form className={styles.card} onSubmit={handleSubmit}>
        <h1 className={styles.title}>演奏した曲</h1>
        <p className={styles.lead}>サークルのライブのセットリストを記録するアプリです。</p>

        <label className={styles.label}>
          メールアドレス
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
            required
          />
        </label>

        <label className={styles.label}>
          パスワード
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
          />
        </label>

        {error && (
          <p className={styles.error} role="alert">
            {error}
          </p>
        )}

        <button className={styles.submit} type="submit" disabled={submitting}>
          {submitting ? 'ログイン中…' : 'ログイン'}
        </button>

        <Link className={styles.link} to="/signup">
          はじめての人はこちら（部員登録）
        </Link>
      </form>
    </div>
  );
}
