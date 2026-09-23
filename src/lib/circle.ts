/**
 * サークル参加まわりの入力チェックと整形。
 * Supabase にも React にも依存しない純粋関数だけを置き、Vitest で直接テストする。
 */

/**
 * 招待コードの整形。前後の空白を除き、大文字にそろえる。
 * 口頭やメモで共有されるものなので、小文字で打たれても通るようにしている
 * （DB 側の join_circle も同じ規則で照合する）。
 */
export function normalizeInviteCode(code: string): string {
  return code.trim().toUpperCase();
}

export type FieldError = { field: string; message: string };

/** 表示名のチェック。DB の check 制約（1〜30 文字）と同じ条件を画面側でも先に見る。 */
export function validateDisplayName(displayName: string): FieldError | null {
  const name = displayName.trim();
  if (name === '') {
    return { field: 'displayName', message: '名前を入力してください。部員名簿に表示されます。' };
  }
  if (name.length > 30) {
    return { field: 'displayName', message: '名前は30文字までです。' };
  }
  return null;
}

/** サークル名のチェック（1〜50 文字）。 */
export function validateCircleName(circleName: string): FieldError | null {
  const name = circleName.trim();
  if (name === '') {
    return { field: 'circleName', message: 'サークル名を入力してください。' };
  }
  if (name.length > 50) {
    return { field: 'circleName', message: 'サークル名は50文字までです。' };
  }
  return null;
}

/** 招待コードのチェック。DB の check 制約（英数字 6〜12 文字）と同じ条件。 */
export function validateInviteCode(code: string): FieldError | null {
  const normalized = normalizeInviteCode(code);
  if (normalized === '') {
    return { field: 'inviteCode', message: '招待コードを入力してください。' };
  }
  if (!/^[A-Z0-9]{6,12}$/.test(normalized)) {
    return {
      field: 'inviteCode',
      message: '招待コードは英数字6〜12文字です。サークルの管理者に確認してください。',
    };
  }
  return null;
}

/** パスワードのチェック。Supabase Auth の既定の最小文字数に合わせる。 */
export function validatePassword(password: string): FieldError | null {
  if (password.length < 6) {
    return { field: 'password', message: 'パスワードは6文字以上にしてください。' };
  }
  return null;
}
