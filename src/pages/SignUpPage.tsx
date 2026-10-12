import { useState, type FormEvent } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useSession } from '../hooks/useSession';
import { Loading } from '../components/Loading';
import { validatePassword } from '../lib/circle';
import styles from './AuthCard.module.css';

/**
 * 部員が自分でアカウントを作る画面。
 * サークルへの参加（招待コードの入力）は登録後の /join で行う。
 * アカウント作成とサークル参加を分けているのは、1 人が複数サークルに入れるようにするため。
 */
export function SignUpPage() {
  const { session, loading } = useSession();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  // メール確認が有効な Supabase プロジェクトでは、登録直後はログインできない
  const [needsConfirm, setNeedsConfirm] = useState(false);

  if (loading) return <Loading label="確認中…" />;
  if (session) return <Navigate to="/join" replace />;

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    const invalid = validatePassword(password);
    if (invalid) {
      setError(invalid.message);
      return;
    }

    setError(null);
    setSubmitting(true);
    const { data, error: signUpError } = await supabase.auth.signUp({ email, password });

    if (signUpError) {
      setError(
        signUpError.message.includes('already')
          ? 'このメールアドレスは登録済みです。ログイン画面からログインしてください。'
          : '登録できませんでした。メールアドレスの形式を確認して、もう一度お試しください。',
      );
      setSubmitting(false);
      return;
    }

    if (!data.session) {
      // 確認メールを送る設定のとき。ここで案内を出さないと「押したのに何も起きない」になる
      setNeedsConfirm(true);
      setSubmitting(false);
      return;
    }
    // セッションが返った場合は onAuthStateChange が反応し、上の Navigate で /join へ移動する
  };

  return (
    <div className={styles.page}>
      <form className={styles.card} onSubmit={handleSubmit}>
        <h1 className={styles.title}>部員登録</h1>
        <p className={styles.lead}>
          サークルのライブ記録アプリのアカウントを作ります。作成後に招待コードでサークルに参加します。
        </p>

        {needsConfirm ? (
          <>
            <p className={styles.notice} role="status">
              確認メールを送りました。メール内のリンクを開いてから、ログイン画面に進んでください。
            </p>
            <Link className={styles.link} to="/login">
              ログイン画面へ
            </Link>
          </>
        ) : (
          <>
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
              パスワード（6文字以上）
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="new-password"
                required
              />
            </label>

            {error && (
              <p className={styles.error} role="alert">
                {error}
              </p>
            )}

            <button className={styles.submit} type="submit" disabled={submitting}>
              {submitting ? '登録中…' : '登録する'}
            </button>

            <Link className={styles.link} to="/login">
              アカウントを持っている人はログイン
            </Link>
          </>
        )}
      </form>
    </div>
  );
}
