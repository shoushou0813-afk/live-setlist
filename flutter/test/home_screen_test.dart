// 画面（Widget）のテスト。
// 通信の代わりに FakeArchiveRepository を渡し、画面を組み立てて操作し、表示を確かめる。
// 実行：flutter test
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_setlist/models/live.dart';
import 'package:live_setlist/screens/home_screen.dart';
import 'package:live_setlist/theme.dart';

import 'fake_archive_repository.dart';

const _lives = [
  Live(
    id: 'live-1',
    title: '定期ライブ vol.3',
    performedOn: '2026-06-20',
    venue: '下北沢ERA',
    songs: ['夜明けのバス', 'Blue Line'],
  ),
];

const _songs = [
  SongStat(
    id: 'song-1',
    title: '夜明けのバス',
    playCount: 4,
    lastPlayedOn: '2026-06-20',
  ),
  SongStat(
    id: 'song-2',
    title: 'Blue Line',
    playCount: 2,
    lastPlayedOn: '2026-06-20',
  ),
];

/// メイン画面を組み立てて、読み込みが終わるまで進める
Future<void> pumpHome(WidgetTester tester, FakeArchiveRepository repo) async {
  // スマホくらいの縦長の画面にする（初期値の 800×600 だと編集画面が入りきらない）
  tester.view.physicalSize = const Size(1200, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: HomeScreen(repository: repo, onLogout: () async {}),
    ),
  );
  // pumpAndSettle：アニメーションや非同期の処理が落ち着くまで画面を進める
  await tester.pumpAndSettle();
}

/// 「ライブ」タブに切り替える
Future<void> openLivesTab(WidgetTester tester) async {
  await tester.tap(find.text('ライブ'));
  await tester.pumpAndSettle();
}

void main() {
  group('曲一覧', () {
    testWidgets('読み込みが終わると、本数・曲数と曲の一覧が出る', (tester) async {
      await pumpHome(
        tester,
        FakeArchiveRepository(lives: _lives, songs: _songs),
      );

      expect(find.text('1本のライブ ／ 2曲'), findsOneWidget);
      expect(find.text('夜明けのバス'), findsOneWidget);
      expect(find.text('4回'), findsOneWidget);
      expect(find.text('最終 2026/06/20'), findsNWidgets(2));
    });

    testWidgets('読み込みに失敗するとエラーと再読み込みボタンが出て、押すと読み込み直す', (tester) async {
      final repo = FakeArchiveRepository(lives: _lives, songs: _songs)
        ..failFetch = true;
      await pumpHome(tester, repo);

      expect(find.textContaining('データを読み込めませんでした'), findsOneWidget);

      repo.failFetch = false; // 通信が回復した
      await tester.tap(find.text('もう一度読み込む'));
      await tester.pumpAndSettle();

      expect(find.text('夜明けのバス'), findsOneWidget);
      expect(repo.fetchCount, 2);
    });

    testWidgets('曲がないときは、何をすればいいかを出す', (tester) async {
      await pumpHome(tester, FakeArchiveRepository());

      expect(find.textContaining('まだ曲がありません'), findsOneWidget);
    });

    testWidgets('曲名で絞り込める。一致しなければそう伝える', (tester) async {
      await pumpHome(
        tester,
        FakeArchiveRepository(lives: _lives, songs: _songs),
      );

      await tester.enterText(find.byType(TextField), 'blue');
      await tester.pumpAndSettle();
      expect(find.text('Blue Line'), findsOneWidget);
      expect(find.text('夜明けのバス'), findsNothing);

      await tester.enterText(find.byType(TextField), 'ない曲');
      await tester.pumpAndSettle();
      expect(find.text('「ない曲」に一致する曲はありませんでした。'), findsOneWidget);
    });

    testWidgets('曲をタップすると、その曲を演奏したライブが出る', (tester) async {
      await pumpHome(
        tester,
        FakeArchiveRepository(
          lives: _lives,
          songs: _songs,
          livesOfSong: const [
            LiveOfSong(
              id: 'live-1',
              title: '定期ライブ vol.3',
              performedOn: '2026-06-20',
              venue: '下北沢ERA',
            ),
          ],
        ),
      );

      await tester.tap(find.text('夜明けのバス'));
      await tester.pumpAndSettle();

      expect(find.textContaining('定期ライブ vol.3（下北沢ERA）'), findsOneWidget);
    });
  });

  group('ライブ', () {
    testWidgets('カードをタップすると、曲順どおりのセットリストが出る', (tester) async {
      await pumpHome(
        tester,
        FakeArchiveRepository(lives: _lives, songs: _songs),
      );
      await openLivesTab(tester);

      expect(find.text('2曲 ・ タップで開く'), findsOneWidget);
      await tester.tap(find.text('定期ライブ vol.3'));
      await tester.pumpAndSettle();

      expect(find.text('1. 夜明けのバス'), findsOneWidget);
      expect(find.text('2. Blue Line'), findsOneWidget);
    });

    testWidgets('ライブ名を空にして保存すると、エラーを出して保存しない', (tester) async {
      final repo = FakeArchiveRepository(lives: _lives, songs: _songs);
      await pumpHome(tester, repo);
      await openLivesTab(tester);
      await tester.tap(find.text('定期ライブ vol.3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('編集'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'ライブ名'), '   ');
      await tester.tap(find.text('保存する'));
      await tester.pumpAndSettle();

      expect(find.text('ライブ名を入力してください。'), findsOneWidget);
      expect(repo.savedInputs, isEmpty);
    });

    testWidgets('まとめて貼り付けで追加すると、整えた曲名で保存し、一覧を取り直す', (tester) async {
      final repo = FakeArchiveRepository(lives: _lives, songs: _songs);
      await pumpHome(tester, repo);
      await openLivesTab(tester);

      await tester.tap(find.text('ライブを追加'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'ライブ名'), '新歓ライブ');
      await tester.tap(find.text('まとめて貼り付け'));
      await tester.pumpAndSettle();
      // 「まとめて貼り付け」の入力欄（複数行のもの）に、空行や余分な空白を混ぜて入れる
      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.maxLines == 12),
        '  曲A \n\n曲B\n',
      );
      await tester.tap(find.text('保存する'));
      await tester.pumpAndSettle();

      final saved = repo.savedInputs.single;
      expect(saved.id, isNull); // 新規なので ID はない
      expect(saved.title, '新歓ライブ');
      expect(saved.songs, ['曲A', '曲B']);
      expect(find.text('セットリスト'), findsNothing); // 編集画面は閉じた
      expect(repo.fetchCount, 2); // 最初の 1 回＋保存後の取り直し
    });

    testWidgets('削除は確認してから行う。「やめる」なら削除しない', (tester) async {
      final repo = FakeArchiveRepository(lives: _lives, songs: _songs);
      await pumpHome(tester, repo);
      await openLivesTab(tester);
      await tester.tap(find.text('定期ライブ vol.3'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('やめる'));
      await tester.pumpAndSettle();
      expect(repo.deletedIds, isEmpty);

      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除する'));
      await tester.pumpAndSettle();
      expect(repo.deletedIds, ['live-1']);
    });
  });
}
