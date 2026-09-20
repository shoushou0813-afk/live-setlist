# 演奏した曲 — サークルのライブ演奏曲アーカイブ

サークルで出演したライブのセットリストを部員みんなで記録し、
**どの曲を何回・いつ・どのバンドが演奏したか**をすぐ振り返れる Web アプリです。
次のライブの曲を決めるとき「最近どの曲をやったか」「この曲は何回目か」が分からなくなる問題を解決します。

- 公開 URL：（Vercel にデプロイ後に記入）
- デモアカウント：メール `demo@example.com` ／ パスワード（作成後に記入）
- デモサークルの招待コード：`DEMO01`（別アカウントを作って参加すると、共同編集の様子を試せます）

（スクリーンショット：ログイン画面・サークル参加画面・曲一覧・ライブ一覧・編集モーダル）

## 主な機能

| 画面 | できること |
|---|---|
| ログイン `/login` | メール＋パスワードでログイン |
| 部員登録 `/signup` | 部員が自分でアカウントを作る（6文字以上のパスワード） |
| サークル `/join` | 招待コードでサークルに参加、または新しいサークルを作る（作成時に招待コードを発行） |
| 曲一覧 `/` | サークル全員の記録を合算した曲ごとの演奏回数（回数に比例したバー）と最終演奏日。演奏回数順／最近やった順／曲名順の並び替え、曲名での絞り込み。曲をタップするとその曲を演奏したライブが新しい順に開く |
| ライブ `/lives` | ライブをセトリ風カードで日付の新しい順に表示。カードを開くと曲順どおりのセットリスト、出演バンド名、登録者名、編集・削除 |
| ライブ編集（モーダル） | ライブ名・出演バンド・日付・会場と曲。曲は「1曲ずつ（並べ替え・削除可）」と「まとめて貼り付け（1行1曲）」を切り替えられる |

- 記録の持ち主は**個人ではなくサークル**です。所属している部員なら誰でも追加・編集・削除でき、
  代わりに「誰が登録したか」を各ライブに表示します（記録係が交代しても直せるようにするため）。
- 曲名は前後の空白を除き英字の大小を無視して同一判定します（`Blue Line` と `blue line` は同じ曲、
  `Blue Line ver.2` は別の曲）。判定はサークル単位なので、部員が別々に登録しても 1 曲にまとまります。
- 同じライブで同じ曲を 2 回演奏した場合も記録でき、演奏回数は `count(distinct live_id)` で
  数えるので二重計上されません。

## 使用技術と選んだ理由

| 分類 | 技術 | 理由 |
|---|---|---|
| フロント | React 18 / TypeScript（strict）/ Vite | 型で取得データの形を固定したかった。Vite は開発サーバーの起動が速い |
| ルーティング | React Router | ログイン必須の画面を `RequireAuth`、所属必須の画面を `RequireCircle` で 1 か所にまとめられる |
| 認証・DB | Supabase（Auth / Postgres / RLS） | 認証と DB が揃っていて、アクセス制御を **DB 側**に書けるのが決め手 |
| スタイル | 素の CSS（CSS Modules） | クラス名の衝突を気にせず、試作版の CSS をほぼそのまま移植できる |
| テスト | Vitest | UI から切り離した純粋関数だけを対象にしている |
| デプロイ | Vercel | GitHub と繋ぐだけで本番が出る。SPA の rewrite は `vercel.json` に記述 |

## DB 設計

```
auth.users (Supabase 管理)
   │ 1
   └──< circle_members   所属（中間テーブル）
          circle_id, user_id, display_name, role, joined_at
          PK (circle_id, user_id)
             │ n
             │ 1
        circles          サークル
          id, name, invite_code(UNIQUE), created_at
             │ 1
             ├──< lives          ライブ本体
             │      id, circle_id, created_by, title, performed_on, venue, band, created_at
             │        │ 1
             │        └──< setlist_items   曲順（中間テーブル）
             │               live_id, position, song_id, circle_id
             │               PK (live_id, position)
             │                     │ n
             └──< songs  ──────────┘ 1
                    id, circle_id, title, title_key(生成列), created_at
                    UNIQUE (circle_id, title_key)
```

設計で意識した点（詳細は [`docs/DB.md`](docs/DB.md)、SQL は [`supabase/schema.sql`](supabase/schema.sql)）：

- **持ち主をサークルにした**：部員ごとにデータを持つと「サークルで一番やっている曲」が出せない。
  `lives` / `songs` / `setlist_items` に `circle_id` を持たせ、所属していれば全員が同じ記録を
  見て直せるようにした。
- **曲を別テーブルにした**：ライブごとに曲名を文字列で持つと、集計のたびに名寄せが必要になる。
  `songs` に分け、生成列 `title_key`（`lower(btrim(title))`）＋ `unique (circle_id, title_key)` で
  同じ曲を 1 行にまとめた。
- **曲順は `position` で持ち、主キーを `(live_id, position)` にした**：同じライブで同じ順番が
  重複しないことを DB が保証する。
- **所属判定は `security definer` の関数**：`circle_members` のポリシーの中で `circle_members` を
  読むと無限再帰になるため、`is_circle_member(circle_id)` に切り出した。返すのは「呼んだ本人が
  所属しているか」の真偽値だけ。
- **保存は RPC `save_live` を 1 回だけ呼ぶ**：ライブ・曲・曲順を別々に送ると、途中で失敗したときに
  半端なデータが残る。`security invoker` の関数にまとめて 1 トランザクションにした。
  フロントから `setlist_items` を直接 insert している箇所はない。
- **集計はビュー `song_stats`**：`security_invoker = true` を付けて、呼び出したユーザーの RLS が
  そのまま効くようにしている。付けないと作成者（管理者）権限で動き、全サークル分が見えてしまう。

## セキュリティ

- 全テーブルで RLS を有効にし、**所属しているサークルの行だけ**を読み書きできるようにしている。
- **外部キーの検証は RLS を通らない**ため、`setlist_items` のポリシーでは `with check` の中で
  「その `live_id` と `song_id` が本当に同じサークルのものか」を `exists` で確認している。
  これがないと、他サークルのライブ ID を指定した紐づけが通ってしまう。
- **サークルの作成経路は RPC だけ**：`circles` に insert のポリシーを作っていないので、
  直接の insert は拒否される（ポリシーが無い操作は全部拒否）。
- **参加は RPC `join_circle`**：参加前は RLS で `circles` を読めないため、招待コードの照合も
  `security definer` の関数の中で行う。コードが違えば所属行は作られない。
- **役割の昇格はトリガーで防止**：RLS のポリシーからは変更前の値が見えないので、
  `before update` トリガーで「role を変えられるのは管理者だけ」を保証している。
- 集計ビューは `security_invoker = true`。
- `save_live` / `create_circle` / `join_circle` は `anon` から `revoke` し、
  `authenticated` にだけ `grant` している。
- フロントの `RequireAuth` / `RequireCircle` は**操作性のためのもの**で、データを守っているのは
  DB 側の RLS。この分岐をすり抜けても他サークルの行は返らない。
- ブラウザに渡すのは `anon key` のみ。`service_role` キーはフロントにも `.env.local` にも置かない。
  `.env*` は `.gitignore` 済み（`.env.example` だけコミット）。

### ローカル Postgres での検証結果

`supabase/schema.sql` をローカルの PostgreSQL 16 に流し、`auth.uid()` を差し替えて
「別サークルの人」「未ログイン」から何ができるかを 1 つずつ確かめた。

拒否されることの例（すべてエラーまたは 0 件）：

| 試したこと | 結果 |
|---|---|
| 別サークルから `lives` / `songs` / `song_stats` / `circle_members` を select | すべて 0 件 |
| 別サークルのライブを直接 update / delete | 0 件（対象行が見えない） |
| 別サークルの `circle_id` を指定して `lives` を insert | `new row violates row-level security policy` |
| 自分のサークルの箱に他サークルの `live_id` / `song_id` を紐づけ | 同上（`setlist_items`） |
| 他サークルの ID を渡して `save_live` | `このサークルの部員ではありません` |
| 間違った招待コードで `join_circle` | `招待コードが違います` |
| `circles` に直接 insert | `new row violates row-level security policy` |
| 一般部員が自分を admin に昇格 | `役割を変更できるのは管理者だけです` |
| 未ログイン（anon）で `save_live` / `create_circle` / `join_circle` | `permission denied for function` |

（本番の Supabase でも別アカウントで同じ確認をして、ここに追記する。
手順は [`docs/TASKS.md`](docs/TASKS.md) の「7. 他サークルから見えないことの確認」）

## 動かし方

### 1. Supabase 側の準備

1. Supabase で新規プロジェクトを作成
2. SQL Editor で [`supabase/schema.sql`](supabase/schema.sql) を実行
3. Authentication > Sign In / Providers で **Allow new users to sign up をオン**
   （部員が自分でアカウントを作るため。サークルのデータは招待コードを知らないと触れない）
4. Authentication > Users でデモ用のアカウントを作成（Auto Confirm にチェック）。
   2 人作ると共同編集の様子を見せられる
5. [`supabase/seed.sql`](supabase/seed.sql) の `v_email1` / `v_email2` をデモアカウントのメールに
   書き換えて実行（招待コード `DEMO01` のデモサークルができる。何度実行しても同じ状態になる）
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

## 部員への配り方（運用）

1. 誰か 1 人が `/signup` でアカウントを作り、`/join` の「サークルを作る」でサークルを登録する
2. 表示された招待コードを部員に伝える（ヘッダーにも常に出ている）
3. 部員は `/signup` でアカウントを作り、`/join` の「招待コードで参加」にコードと自分の名前を入力する
4. あとは誰がライブを追加しても、全員の画面に反映される

## スクリプト

- `npm run dev` — 開発サーバー
- `npm run build` — 型チェック（`tsc -b`）＋ 本番ビルド
- `npm run test` — Vitest（純粋関数の単体テスト 37 件）
- `npm run preview` — ビルド結果の確認

## ディレクトリ構成

```
src/
  main.tsx / App.tsx             ルーティングと画面の枠
  lib/supabase.ts                クライアント生成（環境変数チェック付き）
  lib/setlist.ts                 セトリ入力の整形・並び替え・絞り込み（純粋関数）
  lib/circle.ts                  サークル参加まわりの入力チェック（純粋関数）
  lib/setlist.test.ts / circle.test.ts  その単体テスト
  lib/api/circles.ts             サークルの所属・作成・参加・部員名簿
  lib/api/lives.ts               ライブの取得・保存・削除
  lib/api/songs.ts               曲の集計・曲ごとの出演ライブ
  hooks/useSession.ts            ログイン状態
  components/RequireAuth.tsx     認証ガード
  components/CircleProvider.tsx  いま見ているサークル（＋所属ガード RequireCircle）
  components/ArchiveProvider.tsx ライブと集計をまとめて保持
  components/Header.tsx          ヘッダー（サークル名・招待コード・件数・タブ・ログアウト）
  components/LiveEditor.tsx      編集モーダル
  pages/LoginPage.tsx / SignUpPage.tsx / JoinCirclePage.tsx / SongsPage.tsx / LivesPage.tsx
  types/database.ts              Supabase から自動生成
supabase/schema.sql              テーブル・RLS・ビュー・RPC
supabase/seed.sql                デモサークルのサンプルデータ
docs/                            仕様・DB 設計・作業手順
```

コンポーネントから `supabase.from()` を直接呼ばず、Supabase の呼び出しは `src/lib/api/` に
まとめています。並び替え・絞り込み・入力の整形は Supabase にも React にも依存しない純粋関数にして、
Vitest から直接テストしています。

## 工夫した点・苦労した点

- **アクセス制御をフロントの条件分岐に持たせなかった**こと。最初は `RequireAuth` があれば十分だと
  思っていたが、開発者ツールから直接クエリを投げられる以上、守るべきは DB 側だと分かった。
- **共有範囲を「個人」から「サークル」に広げるときが一番の設計変更だった**。テーブルの `user_id` を
  `circle_id` に置き換えるだけでなく、「参加前はサークルの行が見えないので招待コードを照合できない」
  という問題が出て、参加処理を `security definer` の RPC にまとめることで解決した。
- **RLS のポリシーが自分自身を参照して無限再帰する**問題。`circle_members` のポリシーの中で
  `circle_members` を読んでいたため、所属判定を `security definer` の関数に切り出した。
- **外部キーは RLS を通らない**ことに気づくまで、`setlist_items` の `with check` を所属判定だけに
  していた。これだと他サークルのライブ ID を自分のサークルの行として紐づけられてしまう。
- 保存を RPC 1 回にまとめたこと。ライブを insert → 曲を insert → 曲順を insert と 3 回に分けると、
  途中で失敗したときに曲順のないライブが残るため、DB 側の関数にまとめて 1 トランザクションにした。
- 曲順は `position` 順で返る保証がないため、取得後にフロント側で並べ直している。

## 今後の改善

- バンドのマスタ化（いまは自由入力。バンド別の集計を出せるようにしたい）
- 曲の統合・名前変更（表記ゆれを後からまとめる）
- 部員の管理画面（管理者が退部者を消す、役割を変える）
- パスワードリセット
- セットリストの共有（公開リンク）
- 会場ごとの集計
