# DB 設計

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

## 設計の理由（README・面接用）
- **曲を別テーブルにした**：ライブごとに曲名を文字列で持つと集計のたびに名寄せが必要になる。`songs` に分けて `title_key`（前後空白除去＋小文字化）で一意にし、同じ曲を 1 行にまとめた。
- **曲順は `position` で持つ**：主キーを `(live_id, position)` にして、同じライブで同じ順番が重複しないことを DB が保証する。同じ曲を 1 ライブで 2 回やっても記録できる（集計は `count(distinct live_id)`）。
- **全テーブルに `user_id`**：RLS のポリシーを単純に保つため。`default auth.uid()` なのでフロントから送らなくてよい。
- **`setlist_items` の RLS で所有者を二重チェック**：外部キーの検証は RLS を通らないので、他人の `live_id` / `song_id` を指定した紐づけを `with check` で拒否している。
- **保存は RPC `save_live`**：ライブ・曲・曲順を複数回に分けて送ると、途中で失敗したとき半端なデータが残る。関数にまとめて 1 トランザクションにした。`security invoker` なので RLS はそのまま効く。
- **集計はビュー `song_stats`**：`security_invoker = true` で呼び出したユーザーの RLS が効く。付けないと作成者（管理者）権限で動き、全員分が見えてしまう。
- **ライブ削除で曲は消さない**：どのライブにも出ていない曲はビューの内部結合で自然に一覧から消える。

## 表示名のルール
同じ曲とみなされた場合、最初に登録したときの表記（例：`曲b`）が表示名として残る。

## 検証済みの動作（ローカル Postgres で確認）
- 新規保存・更新（曲順の作り直し）・空行と前後空白の除去・大小文字の名寄せ
- 別ユーザーからはライブも集計も 0 件、更新・紐づけ・RPC による上書きはすべて拒否
- 未ログイン（anon）は `save_live` を実行できない
- `seed.sql` は 2 回実行しても同じ結果
