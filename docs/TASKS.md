# 作業手順

各タスクの「完了条件」を満たしたらコミットして次へ。

## 0. 準備（人がやる）
- [ ] Supabase で新規プロジェクト作成
- [ ] SQL Editor で `supabase/schema.sql` を実行
- [ ] Authentication > Sign In / Providers で「Allow new users to sign up」をオフ
- [ ] Authentication > Users で自分のアカウントとデモアカウントを作成（Auto Confirm）
- [ ] `supabase/seed.sql` のメールをデモ用に書き換えて実行
- [ ] Project Settings > API から URL と anon key を控える
- [ ] GitHub にリポジトリ作成

## 1. プロジェクト作成
- Vite（react-ts）で作成、React Router・supabase-js・Vitest を追加
- `.env.example`（キー名のみ）、`.gitignore` に `.env*`（`.env.example` は除外）
- `src/lib/supabase.ts` でクライアント生成（環境変数が無ければ分かるエラーを出す）
- `supabase gen types typescript --project-id <id> > src/types/database.ts`
- 試作版の CSS を CSS Modules に移植し、フォントを `index.html` で読み込む
- **完了条件**：`npm run dev` で空の画面が試作版の配色で出る

## 2. ログイン
- `useSession`：`getSession` と `onAuthStateChange` でログイン状態を保持
- `RequireAuth`：未ログインなら `/login` へ。確認中はローディング表示
- `LoginPage`：`signInWithPassword`。失敗時のメッセージ、送信中はボタン無効
- ヘッダーにログアウト
- **完了条件**：ログイン→`/`、ログアウト→`/login`、未ログインで `/lives` を開くと `/login`

## 3. データ取得・保存の関数
- `lib/api/lives.ts`：`fetchLives()`（`setlist_items(position, songs(title))` を含めて取得し、曲順に並べて返す）、`saveLive()`（`rpc('save_live')`）、`deleteLive()`
- `lib/api/songs.ts`：`fetchSongStats()`（`song_stats`）、`fetchLivesForSong(songId)`
- 入力の整形（空行除去・trim）を純粋関数にして Vitest でテスト
- **完了条件**：テストが通る。デモアカウントで取得結果をコンソール確認

## 4. ライブ画面
- 試作版のカード表示と編集モーダルを移植し、保存・削除を API に接続
- 保存後は一覧を再取得。保存中・失敗の表示
- **完了条件**：追加・編集・削除が再読み込み後も残る

## 5. 曲一覧画面
- 集計表示・並び替え・検索・タップで出演ライブ展開を移植
- ヘッダーのライブ本数・曲数
- **完了条件**：ライブを追加すると回数と最終日が変わる

## 6. 他人から見えないことの確認
- 別アカウントでログインし、自分のデータが一切出ないことを確認
- ブラウザの開発者ツールから `supabase.from('lives').select()` を叩いても他人の行が返らないことを確認
- 結果を README の「セキュリティ」に書く

## 7. 公開
- Vercel にインポート、環境変数を設定、SPA のため `vercel.json` で全パスを `index.html` に rewrite
- Supabase の Authentication > URL Configuration に本番 URL を追加
- **完了条件**：本番 URL でデモアカウントのログインと閲覧ができる

## 8. 仕上げ
- `docs/README_TEMPLATE.md` を元に README を書く（スクリーンショット・DB 図を入れる）
- スマホ幅での表示確認、キーボード操作でフォーカスが見えるか確認
