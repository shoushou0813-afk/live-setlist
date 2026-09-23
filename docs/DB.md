# DB 設計

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
             │               live_id, position, song_id, circle_id, pa_note, lighting_note
             │               PK (live_id, position)
             │                     │ n
             └──< songs  ──────────┘ 1
                    id, circle_id, title, title_key(生成列), created_at
                    UNIQUE (circle_id, title_key)
```

## 設計の理由（README・面接用）
- **持ち主を「個人」ではなく「サークル」にした**：サークルで使うので、部員それぞれが自分のライブを
  持っていると「サークルで一番やっている曲」が出せない。`lives` / `songs` / `setlist_items` に
  `circle_id` を持たせ、所属している部員なら全員が同じ記録を見て直せるようにした。
- **曲を別テーブルにした**：ライブごとに曲名を文字列で持つと集計のたびに名寄せが必要になる。
  `songs` に分けて `title_key`（前後空白除去＋小文字化）で一意にし、同じ曲を 1 行にまとめた。
  一意制約を `(circle_id, title_key)` にしたので、部員が別々に登録しても 1 曲にまとまる。
- **曲順は `position` で持つ**：主キーを `(live_id, position)` にして、同じライブで同じ順番が
  重複しないことを DB が保証する。同じ曲を 1 ライブで 2 回やっても記録できる
  （集計は `count(distinct live_id)`）。
- **`created_by` は表示専用**：誰が登録したかは出すが、編集権限には使わない（記録係が交代しても
  直せるようにするため）。退部して `auth.users` から消えても記録を残したいので `on delete set null`。
- **所属判定を `security definer` の関数に切り出した**：`circle_members` のポリシーの中で
  `circle_members` を読むと無限再帰になる。`is_circle_member(circle_id)` は作成者権限で動くので
  RLS を通らず、返すのも「呼んだ本人が所属しているか」の真偽値だけなので情報は漏れない。
- **`setlist_items` の RLS で所属を二重チェック**：外部キーの検証は RLS を通らないので、
  他サークルの `live_id` / `song_id` を指定した紐づけを `with check` で拒否している。
- **`circles` に insert のポリシーを作らない**：ポリシーが無い操作は全部拒否されるので、
  サークルの作成経路は RPC `create_circle`（security definer）だけになる。
  招待コードの発行もそこで行う。
- **参加は RPC `join_circle`**：参加前は RLS で `circles` を select できない（＝コードの照合が
  できない）ので、照合と所属行の作成を security definer の関数の中でまとめて行う。
- **役割の昇格はトリガーで防ぐ**：RLS のポリシーからは変更前の値（OLD）が見えないため、
  `before update` トリガーで「role を変えられるのは管理者だけ」を保証している。
- **保存は RPC `save_live`**：ライブ・曲・曲順を複数回に分けて送ると、途中で失敗したとき半端な
  データが残る。関数にまとめて 1 トランザクションにした。`security invoker` なので、
  他サークルの ID を渡しても RLS がそのまま効いて弾かれる。
- **`save_live` の曲引数は `text[]` ではなく `jsonb`**：曲名だけでなく PA・照明メモも
  1 曲ずつ運ぶ必要があり、`text[]` だと 1 曲につき 1 つの値しか持てないため、
  `[{"title": "...", "pa_note": "...", "lighting_note": "..."}, ...]` の形にした。
- **PA・照明メモは `songs`（曲マスタ）ではなく `setlist_items`（曲順の行）に持たせた**：
  同じ曲でもライブごとに会場や機材で設定が変わる（例：屋外イベントだけ低音を上げる）ため、
  曲そのものではなく「このライブのこの曲」の単位でメモを残せるようにした。
- **集計はビュー `song_stats`**：`security_invoker = true` で呼び出したユーザーの RLS が効く。
  付けないと作成者（管理者）権限で動き、他サークルの集計まで見えてしまう。
- **ライブ削除で曲は消さない**：どのライブにも出ていない曲はビューの内部結合で自然に一覧から消える。

## 表示名のルール
同じ曲とみなされた場合、サークル内で最初に登録したときの表記（例：`曲b`）が表示名として残る。

## 招待コード
`[A-Z0-9]` の 6 文字。`0/O`・`1/I` のような紛らわしい文字は使わない。
入力時は大文字に直してから照合するので、小文字で打っても参加できる。

## 検証済みの動作（ローカル Postgres で確認）
`supabase/schema.sql` をローカルの PostgreSQL 16 に流し、`auth.uid()` を差し替えて確認した。

許可されること
- サークル作成（作成者が admin になる）、招待コードでの参加（小文字でも可）
- 部員 B が保存したライブを部員 A が編集でき、登録者は B のまま残る
- 空行・前後空白の除去、大小文字の名寄せ（3 行の入力が 2 曲になる）、曲順の作り直し
- 演奏回数が `count(distinct live_id)` で数えられている
- 一般部員でも自分の表示名は変更でき、管理者だけがサークル名を変更できる
- 曲ごとの PA・照明メモが `setlist_items` に保存され、300 文字以内なら通る。
  空白だけのメモは `null` になる。更新で曲を減らすと、それに合わせて曲順・メモも作り直される

拒否されること
- 別サークルの人から：ライブ・曲・集計・部員名簿・PA/照明メモがすべて 0 件、直接の update / delete も 0 件
- 別サークルの `circle_id` を指定した insert、他サークルの `live_id` / `song_id` の紐づけ
- 他サークルの ID を渡した `save_live`（「このサークルの部員ではありません」）
- 間違った招待コードでの参加（「招待コードが違います」）
- `circles` への直接 insert（作成は RPC だけ）
- 一般部員が自分を admin に昇格させること
- 未ログイン（anon）：行は 0 件、`save_live` / `create_circle` / `join_circle` は実行権限なし
- 300 文字を超える PA・照明メモ（DB の check 制約で拒否される）

そのほか
- `seed.sql` は 2 回実行しても同じ結果
