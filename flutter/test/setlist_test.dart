// lib/logic/setlist.dart の純粋関数のテスト。
// React 版の src/lib/setlist.test.ts と同じ内容を確かめている。
// 実行：flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:live_setlist/logic/setlist.dart';
import 'package:live_setlist/models/live.dart';

void main() {
  group('normalizeSongTitles', () {
    test('前後の空白を除き、空文字を捨てる', () {
      expect(normalizeSongTitles(['  夜明けのバス ', '', '   ', 'Blue Line']), [
        '夜明けのバス',
        'Blue Line',
      ]);
    });

    test('同じ曲を 2 回演奏した場合は重複を残す', () {
      expect(normalizeSongTitles(['Blue Line', 'Blue Line']), [
        'Blue Line',
        'Blue Line',
      ]);
    });
  });

  group('parseSongTitlesFromText', () {
    test('1 行 1 曲として読み、空行を無視する', () {
      expect(parseSongTitlesFromText('曲A\n\n  曲B  \n'), ['曲A', '曲B']);
    });

    test('CRLF の改行でも同じ結果になる', () {
      expect(parseSongTitlesFromText('曲A\r\n曲B'), ['曲A', '曲B']);
    });

    test('空文字なら空のリスト', () {
      expect(parseSongTitlesFromText(''), isEmpty);
    });
  });

  group('songTitlesToText', () {
    test('入力モードを往復しても中身が変わらない', () {
      final text = songTitlesToText(['曲A', '', ' 曲B ']);
      expect(text, '曲A\n曲B');
      expect(parseSongTitlesFromText(text), ['曲A', '曲B']);
    });
  });

  group('songTitleKey', () {
    test('前後の空白と英字の大小を無視する（DB の title_key と同じ規則）', () {
      expect(songTitleKey('  Blue Line '), 'blue line');
      expect(songTitleKey('BLUE LINE'), songTitleKey('blue line'));
    });

    test('表記ゆれは別の曲として扱う', () {
      expect(songTitleKey('Blue Line'), isNot(songTitleKey('Blue Line ver.2')));
    });
  });

  group('validateLiveInput', () {
    test('必須が埋まっていれば null', () {
      expect(
        validateLiveInput(title: '定期ライブ', performedOn: '2026-02-14'),
        isNull,
      );
    });

    test('ライブ名が空白だけならエラー', () {
      expect(
        validateLiveInput(title: '   ', performedOn: '2026-02-14'),
        const ValidationError(LiveField.title, 'ライブ名を入力してください。'),
      );
    });

    test('ライブ名が 100 文字を超えるとエラー（DB の check 制約と同じ）', () {
      expect(
        validateLiveInput(title: 'あ' * 101, performedOn: '2026-02-14')?.field,
        LiveField.title,
      );
      expect(
        validateLiveInput(title: 'あ' * 100, performedOn: '2026-02-14'),
        isNull,
      );
    });

    test('絵文字も 1 文字として数える', () {
      // '🎸'.length は 2 だが、DB の char_length では 1 文字
      expect(
        validateLiveInput(title: '🎸' * 100, performedOn: '2026-02-14'),
        isNull,
      );
    });

    test('日付が空ならエラー', () {
      expect(
        validateLiveInput(title: '定期ライブ', performedOn: '')?.field,
        LiveField.performedOn,
      );
    });
  });

  const songs = [
    SongStat(
      id: '1',
      title: '夜明けのバス',
      playCount: 4,
      lastPlayedOn: '2026-06-20',
    ),
    SongStat(
      id: '2',
      title: 'Blue Line',
      playCount: 4,
      lastPlayedOn: '2026-06-20',
    ),
    SongStat(
      id: '3',
      title: 'Coffee & Rain',
      playCount: 2,
      lastPlayedOn: '2026-02-14',
    ),
    SongStat(
      id: '4',
      title: 'Summer Static',
      playCount: 1,
      lastPlayedOn: '2026-06-20',
    ),
  ];

  List<String> titlesOf(List<SongStat> list) =>
      list.map((s) => s.title).toList();

  group('filterSongs', () {
    test('空の検索語なら全件', () {
      expect(filterSongs(songs, '   '), hasLength(4));
    });

    test('大小文字を無視して部分一致する', () {
      expect(titlesOf(filterSongs(songs, 'blue')), ['Blue Line']);
    });

    test('日本語でも部分一致する', () {
      expect(titlesOf(filterSongs(songs, 'バス')), ['夜明けのバス']);
    });
  });

  group('sortSongs', () {
    test('演奏回数順。同数なら曲名順で並びを安定させる', () {
      expect(titlesOf(sortSongs(songs, SongSort.count)), [
        'Blue Line',
        '夜明けのバス',
        'Coffee & Rain',
        'Summer Static',
      ]);
    });

    test('最近やった順', () {
      expect(sortSongs(songs, SongSort.last)[3].title, 'Coffee & Rain');
    });

    test('曲名順', () {
      expect(titlesOf(sortSongs(songs, SongSort.name)), [
        'Blue Line',
        'Coffee & Rain',
        'Summer Static',
        '夜明けのバス',
      ]);
    });

    test('元のリストを書き換えない', () {
      final original = [...songs];
      sortSongs(original, SongSort.name);
      expect(titlesOf(original), titlesOf(songs));
    });
  });

  group('maxPlayCount', () {
    test('最大の演奏回数を返す', () {
      expect(maxPlayCount(songs), 4);
    });

    test('曲が 0 件でも 1 を返す（バーの長さの計算で 0 で割らないため）', () {
      expect(maxPlayCount([]), 1);
    });
  });

  group('日付', () {
    test('YYYY-MM-DD を YYYY/MM/DD にする', () {
      expect(formatDate('2026-02-14'), '2026/02/14');
    });

    test('DateTime を YYYY-MM-DD にする（1 桁の月日は 0 で埋める）', () {
      expect(toIsoDate(DateTime(2026, 2, 4)), '2026-02-04');
    });
  });
}
