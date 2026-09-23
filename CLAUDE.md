# CLAUDE.md — サークルのライブ演奏曲アーカイブ

## このプロジェクトについて
サークルで出演したライブのセットリストを部員みんなで登録し、演奏した曲を一覧・集計できるWebアプリ。
インターンの提出物（ポートフォリオ）にもする。
データの持ち主は個人ではなく**サークル**。部員は招待コードで参加し、所属していれば全員が同じ記録を
見て編集できる。他のサークルからは一切見えない。
曲ごとにPA・照明の設定メモも残せる（同じ曲でも会場・機材で設定が変わるため）ようにし、
PA班・照明班が次に同じ曲をやるときに参照できるようにしている。

- 画面と見た目の元ネタ: `reference/prototype.jsx`（Claudeアーティファクト版の試作。保存に `window.storage` を使っているが、本番では Supabase に置き換える）
- 仕様: `docs/SPEC.md`
- DB 設計: `docs/DB.md`、SQL: `supabase/schema.sql`
- 作業順: `docs/TASKS.md`（上から順に 1 タスクずつ進める）

## 技術スタック（変更しない）
- Vite + React 18 + TypeScript（strict）
- React Router
- Supabase（Auth: メール＋パスワード / Postgres / RLS）… `@supabase/supabase-js` v2
- スタイル: 素の CSS（CSS Modules）。試作版の配色・フォント（Zen Kaku Gothic New / Klee One、ステージ紺＋ガムテ黄）を引き継ぐ
- テスト: Vitest（ロジック部分のみ）
- デプロイ: Vercel

## 守ること
- **他のサークルのデータは絶対に見えない・触れない**こと。アクセス制御は RLS（DB 側）で行い、フロントの条件分岐だけに頼らない。所属判定は `is_circle_member()`（security definer）を使う（RLS の無限再帰を避けるため）。
- サークルの作成・参加は RPC（`create_circle` / `join_circle`）経由だけにする。`circles` に insert のポリシーは作らない。
- Supabase のキーは `.env.local` の `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` のみ。`service_role` キーはフロントに絶対置かない。`.env*` は git に入れない（`.env.example` だけコミット）。
- セットリスト保存は RPC `save_live` を使う（ライブ・曲・曲順を 1 トランザクションで保存するため）。フロントから `setlist_items` を個別に insert しない。
- 型は `supabase gen types typescript` で生成した `src/types/database.ts` を使う。`any` 禁止。
- ローディング・エラー・空の状態を必ず画面に出す。エラーメッセージは「何が起きたか＋どうすればいいか」。
- 1 タスク終わるごとに動作確認し、意味のある単位でコミットする（例: `feat: ログイン画面を追加`）。

## コードの書き方
- 読みやすさ優先。本人が面接で説明できるように、関数は小さく、名前は日本語話者にも意図が分かるように。
- Supabase 呼び出しは `src/lib/api/` にまとめ、コンポーネントから直接 `supabase.from()` を呼ばない。
- 重要な処理（認証ガード、RPC 呼び出し、集計）には「なぜそうしているか」を短いコメントで残す。

## 進め方のルール
- タスク開始時に、何を作るか・どのファイルを触るかを先に短く示してから実装する。
- 設計を変えたくなったら、実装前に理由を添えて提案する。
- タスク完了時に、変更点と「面接で聞かれそうなポイント」を 2〜3 行でまとめる。

## ディレクトリ構成（目標）
```
src/
  main.tsx / App.tsx        ルーティング
  lib/supabase.ts           クライアント生成
  lib/api/circles.ts        所属・部員名簿・サークル作成・参加
  lib/api/lives.ts          ライブ取得・保存・削除
  lib/api/songs.ts          曲一覧・曲ごとの出演ライブ
  hooks/useSession.ts       ログイン状態
  components/RequireAuth.tsx
  components/CircleProvider.tsx  いま見ているサークル（＋RequireCircle）
  pages/LoginPage.tsx
  pages/SignUpPage.tsx
  pages/JoinCirclePage.tsx
  pages/SongsPage.tsx
  pages/LivesPage.tsx
  components/LiveEditor.tsx
  types/database.ts         自動生成
supabase/schema.sql
supabase/seed.sql
```
