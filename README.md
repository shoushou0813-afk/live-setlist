# 演奏した曲 — ライブ演奏曲アーカイブ

出演したライブのセットリストを記録し、**どの曲を何回・いつ演奏したか**をすぐ振り返れる Web アプリです。
バンドで次のライブの曲を決めるとき、「最近どの曲をやったか」が分からなくなる問題を解決します。

- 公開 URL：（Vercel にデプロイ後に記入）
- デモアカウント：メール `demo@example.com` ／ パスワード（作成後に記入）

（スクリーンショット：ログイン画面・曲一覧・ライブ一覧・編集モーダル）

## 主な機能

| 画面 | できること |
|---|---|
| ログイン `/login` | メール＋パスワードでログイン。本人のデータだけが見える |
| 曲一覧 `/` | 曲ごとの演奏回数（回数に比例したバー）と最終演奏日。演奏回数順／最近やった順／曲名順の並び替え、曲名での絞り込み。曲をタップするとその曲を演奏したライブが新しい順に開く |
| ライブ `/lives` | ライブをセトリ風カードで日付の新しい順に表示。カードを開くと曲順どおりのセットリスト、編集・削除 |
| ライブ編集（モーダル） | ライブ名・日付・会場と曲。曲は「1曲ずつ（並べ替え・削除可）」と「まとめて貼り付け（1行1曲）」を切り替えられる |

曲名は前後の空白を除き英字の大小を無視して同一判定します（`Blue Line` と `blue line` は同じ曲、
`Blue Line ver.2` は別の曲）。同じライブで同じ曲を 2 回演奏した場合も記録でき、
演奏回数は `count(distinct live_id)` で数えるので二重計上されません。

## 使用技術と選んだ理由

| 分類 | 技術 | 理由 |
|---|---|---|
| フロント | React 18 / TypeScript（strict）/ Vite | 型で取得データの形を固定したかった。Vite は開発サーバーの起動が速い |
| ルーティング | React Router | ログイン必須の画面を `RequireAuth` で 1 か所にまとめられる |
| 認証・DB | Supabase（Auth / Postgres / RLS） | 認証と DB が揃っていて、アクセス制御を **DB 側**に書けるのが決め手 |
| スタイル | 素の CSS（CSS Modules） | クラス名の衝突を気にせず、試作版の CSS をほぼそのまま移植できる |
| テスト | Vitest | UI から切り離した純粋関数だけを対象にしている |
| デプロイ | Vercel | GitHub と繋ぐだけで本番が出る。SPA の rewrite は `vercel.json` に記述 |

## DB 設計

```
auth.users (Supabase 管理)
   │ 1
   ├──< lives          ライブ本体
   │      id, user_id, title, performed_on, venue, created_at
   │        │ 1
   │        └──< setlist_items   曲順（中間テーブル）
   │               live_id, position, song_id, user_id
   │               PK (live_id, position)
   │                     │ n
   └──< songs  ──────────┘ 1
          id, user_id, title, title_key(生成列), created_at
          UNIQUE (user_id, title_key)
```

設計で意識した点（詳細は [`docs/DB.md`](docs/DB.md)、SQL は [`supabase/schema.sql`](supabase/schema.sql)）：

- **曲を別テーブルにした**：ライブごとに曲名を文字列で持つと、集計のたびに名寄せが必要になる。
  `songs` に分け、生成列 `title_key`（`lower(btrim(title))`）＋ `unique (user_id, title_key)` で
  同じ曲を 1 行にまとめた。
- **曲順は `position` で持ち、主キーを `(live_id, position)` にした**：同じライブで同じ順番が
  重複しないことを DB が保証する。
- **保存は RPC `save_live` を 1 回だけ呼ぶ**：ライブ・曲・曲順を別々に送ると、途中で失敗したときに
  半端なデータが残る。`security invoker` の関数にまとめて 1 トランザクションにした。
  フロントから `setlist_items` を直接 insert している箇所はない。
- **集計はビュー `song_stats`**：`security_invoker = true` を付けて、呼び出したユーザーの RLS が
  そのまま効くようにしている。付けないと作成者（管理者）権限で動き、全員分が見えてしまう。

## セキュリティ

- 全テーブルで RLS を有効にし、`auth.uid() = user_id` の行だけを読み書きできるようにしている。
- **外部キーの検証は RLS を通らない**ため、`setlist_items` のポリシーでは `with check` の中で
  「その `live_id` と `song_id` が本当に自分のものか」を `exists` で確認している。
  これがないと、他人のライブ ID を指定した紐づけが通ってしまう。
- 集計ビューは `security_invoker = true`。
- `save_live` は `anon` から `revoke` し、`authenticated` にだけ `grant` している。
- フロントの `RequireAuth` は**操作性のためのもの**で、データを守っているのは DB 側の RLS。
  この分岐をすり抜けても他人の行は返らない。
- ブラウザに渡すのは `anon key` のみ。`service_role` キーはフロントにも `.env.local` にも置かない。
  `.env*` は `.gitignore` 済み（`.env.example` だけコミット）。

### 別アカウントでの確認結果

（別アカウントでログインし、自分のデータが一切出ないこと、開発者ツールから
`supabase.from('lives').select()` を叩いても他人の行が返らないことを確認して記入する。
手順は [`docs/TASKS.md`](docs/TASKS.md) の「6. 他人から見えないことの確認」）

## 動かし方

### 1. Supabase 側の準備

1. Supabase で新規プロジェクトを作成
2. SQL Editor で [`supabase/schema.sql`](supabase/schema.sql) を実行
3. Authentication > Sign In / Providers で **Allow new users to sign up をオフ**（新規登録画面は作らない方針のため）
4. Authentication > Users で自分用とデモ用のアカウントを作成（Auto Confirm にチェック）
5. [`supabase/seed.sql`](supabase/seed.sql) の `v_email` をデモアカウントのメールに書き換えて実行
   （何度実行しても同じ状態になるよう、先にデモユーザーのデータを消してから入れている）
6. Project Settings > API から URL と anon key を控える

### 2. ローカルで起動

```sh
npm install
cp .env.example .env.local   # 控えた URL と anon key を書き込む
npm run dev
```

環境変数が未設定のときは「画面が真っ白」ではなく、何をどうすればいいかを書いた例外を出して止まります。

### 3. 型定義の生成

`src/types/database.ts` は本来自動生成するファイルです。Supabase プロジェクトを作ったら必ず生成し直してください。

```sh
npx supabase gen types typescript --project-id <project-id> > src/types/database.ts
```

### 4. デプロイ（Vercel）

1. Vercel にこのリポジトリをインポート
2. 環境変数 `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` を設定
3. SPA なので `/lives` を直接開いても 404 にならないよう、`vercel.json` で全パスを `index.html` に rewrite 済み
4. Supabase の Authentication > URL Configuration に本番 URL を追加

## スクリプト

- `npm run dev` — 開発サーバー
- `npm run build` — 型チェック（`tsc -b`）＋ 本番ビルド
- `npm run test` — Vitest（純粋関数の単体テスト 23 件）
- `npm run preview` — ビルド結果の確認

## ディレクトリ構成

```
src/
  main.tsx / App.tsx             ルーティングと画面の枠
  lib/supabase.ts                クライアント生成（環境変数チェック付き）
  lib/setlist.ts                 入力の整形・並び替え・絞り込み（純粋関数）
  lib/setlist.test.ts            その単体テスト
  lib/api/lives.ts               ライブの取得・保存・削除
  lib/api/songs.ts               曲の集計・曲ごとの出演ライブ
  hooks/useSession.ts            ログイン状態
  components/RequireAuth.tsx     認証ガード
  components/ArchiveProvider.tsx ライブと集計をまとめて保持
  components/Header.tsx          ヘッダー（本数・曲数・タブ・ログアウト）
  components/LiveEditor.tsx      編集モーダル
  pages/LoginPage.tsx / SongsPage.tsx / LivesPage.tsx
  types/database.ts              Supabase から自動生成
supabase/schema.sql              テーブル・RLS・ビュー・保存用関数
supabase/seed.sql                デモアカウント用サンプルデータ
docs/                            仕様・DB 設計・作業手順
```

コンポーネントから `supabase.from()` を直接呼ばず、Supabase の呼び出しは `src/lib/api/` に
まとめています。並び替え・絞り込み・入力の整形は Supabase にも React にも依存しない純粋関数にして、
Vitest から直接テストしています。

## 工夫した点・苦労した点

- **アクセス制御をフロントの条件分岐に持たせなかった**こと。最初は `RequireAuth` があれば十分だと
  思っていたが、開発者ツールから直接クエリを投げられる以上、守るべきは DB 側だと分かった。
- **外部キーは RLS を通らない**ことに気づくまで、`setlist_items` の `with check` を
  `auth.uid() = user_id` だけにしていた。これだと他人のライブ ID を自分の行として紐づけられてしまう。
- 保存を RPC 1 回にまとめたこと。ライブを insert → 曲を insert → 曲順を insert と 3 回に分けると、
  途中で失敗したときに曲順のないライブが残るため、DB 側の関数にまとめて 1 トランザクションにした。
- 曲順は `position` 順で返る保証がないため、取得後にフロント側で並べ直している。

## 今後の改善

- 曲の統合・名前変更（表記ゆれを後からまとめる）
- パスワードリセット
- セットリストの共有（公開リンク）
- 会場ごとの集計
