# 作業手順

各タスクの「完了条件」を満たしたらコミットして次へ。
チェックが付いているものは実装済み（コードはリポジトリに入っている）。

## 0. 準備（人がやる・未完了）
- [ ] Supabase で新規プロジェクト作成
- [ ] SQL Editor で `supabase/schema.sql` を実行
- [ ] Authentication > Sign In / Providers で「Allow new users to sign up」を**オン**
      （部員が自分でアカウントを作るため。サークルのデータは招待コードが無いと触れない）
- [ ] 部内だけで使うなら Authentication > Providers > Email の
      「Confirm email」をどうするか決める（オンなら確認メールのリンクを踏む必要がある）
- [ ] Authentication > Users でデモアカウントを作成（Auto Confirm）
      審査用に 2 人作ると「共同編集」が見せやすい
- [ ] `supabase/seed.sql` のメールをデモ用に書き換えて実行（招待コード `DEMO01` のサークルができる）
- [ ] Project Settings > API から URL と anon key を控える
- [ ] GitHub にリポジトリ作成

## 1. プロジェクト作成
- [x] Vite（react-ts）で作成、React Router・supabase-js・Vitest を追加
- [x] `.env.example`（キー名のみ）、`.gitignore` に `.env*`（`.env.example` は除外）
- [x] `src/lib/supabase.ts` でクライアント生成（環境変数が無ければ分かるエラーを出す）
- [ ] `supabase gen types typescript --project-id <id> > src/types/database.ts`
      （いまは schema.sql と同じ形を手書きしてある。プロジェクトを作ったら必ず生成し直す）
- [x] 試作版の CSS を CSS Modules に移植し、フォントを `index.html` で読み込む

## 2. ログインと部員登録
- [x] `useSession`：`getSession` と `onAuthStateChange` でログイン状態を保持
- [x] `RequireAuth`：未ログインなら `/login` へ。確認中はローディング表示
- [x] `LoginPage`：`signInWithPassword`。失敗時のメッセージ、送信中はボタン無効
- [x] `SignUpPage`：`signUp`。メール確認が必要な場合の案内も出す
- [x] ヘッダーにログアウト

## 3. サークル（参加・作成・切り替え）
- [x] `circles` / `circle_members` と RLS、RPC `create_circle` / `join_circle`
- [x] `lib/api/circles.ts`：所属一覧・部員名簿・作成・参加・表示名の変更
- [x] `CircleProvider`：いま見ているサークルを 1 か所で保持（選択は localStorage に記憶）
- [x] `RequireCircle`：どこにも所属していなければ `/join` へ
- [x] `JoinCirclePage`：招待コードで参加／サークルを作る。作成後に招待コードを表示
- [x] 入力チェック（表示名・サークル名・招待コード・パスワード）を純粋関数にして Vitest でテスト

## 4. データ取得・保存の関数
- [x] `lib/api/lives.ts`：`fetchLives(circleId)`（`setlist_items(position, songs(title))` を含めて
      取得し、曲順に並べて返す）、`saveLive()`（`rpc('save_live')`）、`deleteLive()`
- [x] `lib/api/songs.ts`：`fetchSongStats(circleId)`（`song_stats`）、`fetchLivesForSong(songId)`
- [x] 入力の整形（空行除去・trim）を純粋関数にして Vitest でテスト

## 5. ライブ画面
- [x] 試作版のカード表示と編集モーダルを移植し、保存・削除を API に接続
- [x] 出演バンド名の入力と表示、登録者名の表示
- [x] 保存後は一覧を再取得。保存中・失敗の表示

## 6. 曲一覧画面
- [x] 集計表示・並び替え・検索・タップで出演ライブ展開を移植
- [x] ヘッダーのサークル名・招待コード・ライブ本数・曲数・部員数

## 7. 他サークルから見えないことの確認
- [x] ローカル Postgres で RLS を検証（結果は `docs/DB.md` の「検証済みの動作」）
- [ ] 本番の Supabase で、別サークルのアカウントを作って自分のデータが一切出ないことを確認
- [ ] ブラウザの開発者ツールから `supabase.from('lives').select()` を叩いても
      他サークルの行が返らないことを確認
- [ ] 結果を README の「セキュリティ」に書く

## 8. 公開
- [ ] Vercel にインポート、環境変数を設定、SPA のため `vercel.json` で全パスを `index.html` に rewrite
- [ ] Supabase の Authentication > URL Configuration に本番 URL を追加
- [ ] **完了条件**：本番 URL でデモアカウントのログインと閲覧ができる

## 9. 仕上げ
- [ ] README に公開 URL・デモアカウント・スクリーンショットを入れる
- [ ] スマホ幅での表示確認、キーボード操作でフォーカスが見えるか確認
