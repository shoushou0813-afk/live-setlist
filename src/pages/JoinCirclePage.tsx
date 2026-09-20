import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useCircle } from '../components/CircleProvider';
import { Loading } from '../components/Loading';
import { createCircle, joinCircle } from '../lib/api/circles';
import {
  validateCircleName,
  validateDisplayName,
  validateInviteCode,
} from '../lib/circle';
import styles from './AuthCard.module.css';

type Mode = 'join' | 'create';

/**
 * サークルに参加する（招待コード）か、新しく作る画面。
 * ログイン済みでどのサークルにも入っていない人は RequireCircle からここへ送られる。
 */
export function JoinCirclePage() {
  const { memberships, loading, reloadCircles, selectCircle } = useCircle();
  const navigate = useNavigate();

  const [mode, setMode] = useState<Mode>('join');
  const [displayName, setDisplayName] = useState('');
  const [inviteCode, setInviteCode] = useState('');
  const [circleName, setCircleName] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  // サークルを作ったときは、部員に配る招待コードをこの画面で見せる
  const [createdCode, setCreatedCode] = useState<string | null>(null);

  if (loading) return <Loading label="サークルを確認中…" />;

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();

    const invalid =
      validateDisplayName(displayName) ??
      (mode === 'join' ? validateInviteCode(inviteCode) : validateCircleName(circleName));
    if (invalid) {
      setError(invalid.message);
      return;
    }

    setError(null);
    setSubmitting(true);
    try {
      if (mode === 'join') {
        const circleId = await joinCircle(inviteCode, displayName);
        await reloadCircles();
        selectCircle(circleId);
        navigate('/', { replace: true });
      } else {
        const created = await createCircle(circleName, displayName);
        await reloadCircles();
        selectCircle(created.circleId);
        setCreatedCode(created.inviteCode);
      }
    } catch (e) {
      console.error(e);
      const message = e instanceof Error ? e.message : '';
      setError(
        message.includes('招待コードが違います')
          ? '招待コードが違います。サークルの管理者に確認して、もう一度入力してください。'
          : '処理できませんでした。通信状況を確認して、もう一度お試しください。',
      );
      setSubmitting(false);
    }
  };

  if (createdCode) {
    return (
      <div className={styles.page}>
        <div className={styles.card}>
          <h1 className={styles.title}>できました</h1>
          <p className={styles.lead}>この招待コードを部員に伝えると、同じ記録を共有できます。</p>
          <p className={styles.code}>{createdCode}</p>
          <p className={styles.note}>
            コードはあとからヘッダーでも確認できます。部員は「部員登録」でアカウントを作り、
            この画面の「招待コードで参加」にコードを入力します。
          </p>
          <button className={styles.submit} onClick={() => navigate('/', { replace: true })}>
            記録をはじめる
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className={styles.page}>
      <form className={styles.card} onSubmit={handleSubmit}>
        <h1 className={styles.title}>サークル</h1>
        <p className={styles.lead}>
          {memberships.length === 0
            ? 'まだどのサークルにも入っていません。招待コードで参加するか、新しく作ってください。'
            : '別のサークルに参加する、または新しく作ることができます。'}
        </p>

        <div className={styles.tabs}>
          <button
            type="button"
            className={mode === 'join' ? styles.on : undefined}
            onClick={() => setMode('join')}
          >
            招待コードで参加
          </button>
          <button
            type="button"
            className={mode === 'create' ? styles.on : undefined}
            onClick={() => setMode('create')}
          >
            サークルを作る
          </button>
        </div>

        <label className={styles.label}>
          サークルでの自分の名前
          <input
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            placeholder="例：田中（ギター）"
            maxLength={30}
            required
          />
        </label>

        {mode === 'join' ? (
          <label className={styles.label}>
            招待コード
            <input
              value={inviteCode}
              onChange={(e) => setInviteCode(e.target.value)}
              placeholder="例：DEMO01"
              maxLength={12}
              autoCapitalize="characters"
              required
            />
          </label>
        ) : (
          <label className={styles.label}>
            サークル名
            <input
              value={circleName}
              onChange={(e) => setCircleName(e.target.value)}
              placeholder="例：〇〇大学 軽音サークル"
              maxLength={50}
              required
            />
          </label>
        )}

        {error && (
          <p className={styles.error} role="alert">
            {error}
          </p>
        )}

        <button className={styles.submit} type="submit" disabled={submitting}>
          {submitting ? '送信中…' : mode === 'join' ? '参加する' : '作成する'}
        </button>

        {memberships.length > 0 ? (
          <button type="button" className={styles.link} onClick={() => navigate('/')}>
            記録に戻る
          </button>
        ) : (
          <button type="button" className={styles.link} onClick={() => void supabase.auth.signOut()}>
            ログアウト
          </button>
        )}
      </form>
    </div>
  );
}
