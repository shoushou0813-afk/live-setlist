# 演奏した曲（Flutter 版）

出演したライブのセットリストを記録し、**どの曲を何回・いつ演奏したか**をすぐ振り返れるスマホアプリです。
バンドで次のライブの曲を決めるとき、「最近どの曲をやったか」が分からなくなる問題を解決します。

同じリポジトリの Web 版（React）と**同じ Supabase のデータベース**を使うので、スマホで登録したライブは Web 版にも出ます。

## 主な機能

| 画面 | できること |
|---|---|
| ログイン | メール＋パスワードでログイン。本人のデータだけが見える |
| 曲一覧タブ | 曲ごとの演奏回数（回数に比例したバー）と最後に演奏した日。演奏回数順／最近やった順／曲名順の並び替えと、曲名での絞り込み。曲をタップすると、その曲を演奏したライブが新しい順に開く |
| ライブタブ | ライブをセトリ風のカードで日付の新しい順に表示。カードを開くと曲順どおりのセットリストと、編集・削除 |
| ライブ編集（下から出る画面） | ライブ名・日付・会場と曲。曲は「1曲ずつ（並べ替え・削除）」と「まとめて貼り付け（1行1曲）」を切り替えられる |

下に引っ張ると再読み込みします。読み込み中・エラー・データがないときは、それぞれ画面に表示します。

## 動かし方

必要なもの：Flutter 3.35 以上、Supabase のプロジェクト（`../supabase/schema.sql` を実行済み）

```bash
cd flutter
flutter pub get
cp env.example.json env.json   # env.json に Supabase の URL と anon key を書く
flutter run --dart-define-from-file=env.json
```

- `env.json` は `.gitignore` 済み。キーをコードに直接書かないため、起動時に `--dart-define-from-file` で渡している
- 設定し忘れて起動すると、何をすればいいかを画面に表示する
- テスト：`flutter test`

## 使用技術と選んだ理由

| 分類 | 技術 | 理由 |
|---|---|---|
| アプリ | Flutter / Dart | 1 つのコードで Android と iOS の両方に出せる |
| 認証・DB | Supabase（`supabase_flutter`） | Web 版と同じ DB を使える。アクセス制御を DB 側（RLS）に書ける |
| 状態管理 | `StatefulWidget` と `setState` だけ | 画面は 2 つでデータも 2 種類なので、追加のライブラリを入れずに済む規模だと判断した |
| フォント | Zen Kaku Gothic New / Klee One を同梱 | 通信できないときも同じ見た目にするため（どちらも SIL Open Font License） |
| テスト | `flutter test` | 画面から切り離した計算の部分（純粋関数）を対象にしている |

## 設計

```
lib/
  main.dart                      起動。Supabase の初期化と、設定漏れの検知
  app.dart                       テーマと、ログイン状態による画面の出し分け（AuthGate）
  theme.dart                     配色・フォント
  models/live.dart               画面で使うデータの形（Live, SongStat など）
  logic/setlist.dart             入力の整形・絞り込み・並び替え（純粋関数。テスト対象）
  api/archive_repository.dart    データの取得・保存の約束ごと（abstract interface class）
  api/supabase_archive_repository.dart   上の約束を Supabase で実装したもの
  screens/                       ログイン・メイン（タブ）・曲一覧・ライブ
  widgets/                       編集画面・読み込み中／エラー表示
test/setlist_test.dart           logic/setlist.dart のテスト（24 件）
```

設計で意識した点：

- **画面は Supabase を直接呼ばない**：画面が知っているのは `ArchiveRepository`（取得・保存の約束ごと）だけで、
  Supabase を呼ぶのは `supabase_archive_repository.dart` だけ。画面と通信を分けたので、
  通信の中身を差し替えても画面を直さなくてよい。
- **計算は純粋関数にしてテストする**：曲名の整形・並び替えなどを `logic/setlist.dart` にまとめ、
  通信や画面を用意せずにテストできるようにした。規則は Web 版（`src/lib/setlist.ts`）とそろえている。
- **データの取得はメイン画面で 1 回**：ヘッダーの本数・曲数と 2 つのタブが同じデータを見るので、
  タブごとに取得せず、保存・削除のあとに両方を取り直す。
- **保存は DB の関数 `save_live` を 1 回だけ呼ぶ**：ライブ・曲・曲順を別々に送ると、途中で失敗したときに
  半端なデータが残る。DB 側で 1 つのトランザクションとして保存する。

DB の設計は [`../docs/DB.md`](../docs/DB.md)、SQL は [`../supabase/schema.sql`](../supabase/schema.sql)。

## セキュリティ

- 他人のデータが見えないのは、アプリで絞り込んでいるからではなく、DB の **RLS**（行ごとのアクセス制御）が
  ログイン中の本人の行しか返さないから。アプリのコードを書き換えられても他人の行は取れない。
- アプリに入れるのは anon key（公開してよい鍵）だけ。`service_role` キーはアプリに置かない。
- ログインに失敗したとき、メールアドレスとパスワードのどちらが違うかは表示しない
  （登録されているメールアドレスを当てられないようにするため）。
- 別の人がログインし直したときは、メイン画面を作り直して前の人のデータを残さない。

## 今後の改善

新規登録・パスワードリセット、曲名の統合・名前の変更、オフラインでの閲覧、CI（自動テスト）の追加
