# CLAUDE.md — ライブ演奏曲アーカイブ

## このプロジェクトについて
自分が出演したライブのセットリストを登録し、演奏した曲を一覧・集計できるWebアプリ。
インターンの提出物（ポートフォリオ）にもする。

- 画面と見た目の元ネタ: `reference/prototype.jsx`（Claudeアーティファクト版の試作。保存に `window.storage` を使っているが、本番では Supabase に置き換える）
- 仕様: `docs/SPEC.md`
- DB 設計: `docs/DB.md`、SQL: `supabase/schema.sql`
- 作業順: `docs/TASKS.md`（上から順に 1 タスクずつ進める）

## Flutter 版（`flutter/`）
大学の授業「アプリケーション開発演習」の最終課題・就活のポートフォリオとして、同じアプリを Flutter で作り直したもの。DB（Supabase）は Web 版と共用する。
- **授業で扱った範囲を超える技術を使うときは、実装前に本人の許可を取る**（2026-11-15 時点で #5 まで受講。#6 画面遷移・#7 外部ライブラリと API 通信・#8 設計の分け方・#9 Unit テスト・Widget テスト・CI（GitHub Actions）は許可済み）
- 状態管理は `StatefulWidget` + `setState`、画面遷移は標準の `Navigator`。provider / riverpod / go_router などは入れない
- import は授業と同じ `package:flutter/material.dart`（Flutter 3.47 以降は非推奨の表示が出るので `// ignore: deprecated_member_use`）
- Supabase を呼ぶのは `lib/api/supabase_archive_repository.dart` だけ。画面は `ArchiveRepository` 越しに使う
- 計算は `lib/logic/setlist.dart` の純粋関数にして `flutter test` でテストする（規則は `src/lib/setlist.ts` とそろえる）
- 画面のテストは `test/fake_archive_repository.dart` を渡して書く。CI（`.github/workflows/ci.yml`）で書式・analyze・テストが通ること
- 接続先は `flutter run --dart-define-from-file=env.json`（`env.json` は git に入れない）
- 本人の勉強用に、新しい用語を使ったら `flutter/docs/用語集.md` に足す（README には書かない）

## 技術スタック（Web 版。変更しない）
- Vite + React 18 + TypeScript（strict）
- React Router
- Supabase（Auth: メール＋パスワード / Postgres / RLS）… `@supabase/supabase-js` v2
- スタイル: 素の CSS（CSS Modules）。試作版の配色・フォント（Zen Kaku Gothic New / Klee One、ステージ紺＋ガムテ黄）を引き継ぐ
- テスト: Vitest（ロジック部分のみ）
- デプロイ: Vercel

## 守ること
- **他人のデータは絶対に見えない・触れない**こと。アクセス制御は RLS（DB 側）で行い、フロントの条件分岐だけに頼らない。
- Supabase のキーは `.env.local` の `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` のみ。`service_role` キーはフロントに絶対置かない。`.env*` は git に入れない（`.env.example` だけコミット）。
- セットリスト保存は RPC `save_live` を使う（ライブ・曲・曲順を 1 トランザクションで保存するため）。フロントから `setlist_items` を個別に insert しない。
- 型は `supabase gen types typescript` で生成した `src/types/database.ts` を使う。`any` 禁止。
- ローディング・エラー・空の状態を必ず画面に出す。エラーメッセージは「何が起きたか＋どうすればいいか」。
- 1 タスク終わるごとに動作確認し、意味のある単位でコミットする（例: `feat: ログイン画面を追加`）。
- **コミット・ブランチ・PR の決まり**（就活で面接官が読む前提。全リポジトリ共通）
  - コミットは本人の名前（`市川翔太郎 <shoushou0813@gmail.com>`）で作る。`Co-Authored-By`・`Claude-Session` の行は付けない
  - ブランチ名に `claude` を入れない（例：`feat/flutter-app`）。作業ブランチが `claude/...` と指定されていても、push するのは claude の付かない名前
  - コミット文・PR の説明は「問題→対応→選ばなかった案→確認」の順に書く。PR の説明に「Generated with Claude Code」を入れない

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
  lib/api/lives.ts          ライブ取得・保存・削除
  lib/api/songs.ts          曲一覧・曲ごとの出演ライブ
  hooks/useSession.ts       ログイン状態
  components/RequireAuth.tsx
  pages/LoginPage.tsx
  pages/SongsPage.tsx
  pages/LivesPage.tsx
  components/LiveEditor.tsx
  types/database.ts         自動生成
supabase/schema.sql
supabase/seed.sql
```
