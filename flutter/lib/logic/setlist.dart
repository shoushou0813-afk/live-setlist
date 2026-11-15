/// セットリスト入力の整形と、曲一覧の絞り込み・並び替え。
///
/// Supabase にも画面（Widget）にも依存しない「純粋関数」だけを置いている。
/// 純粋関数＝同じ入力なら必ず同じ結果を返し、外の状態を書き換えない関数。
/// そのため `flutter test` で、通信も画面も用意せずに直接テストできる（test/setlist_test.dart）。
///
/// 規則は React 版の src/lib/setlist.ts と同じにそろえてある。
library;

import '../models/live.dart';

/// 曲名のリストを保存できる形に整える：前後の空白を除き、空行は捨てる。
/// 同じ曲が 2 回あっても消さない（1 ライブで同じ曲を 2 回やることがあるため）。
List<String> normalizeSongTitles(Iterable<String> titles) {
  return titles
      .map((title) => title.trim())
      .where((title) => title.isNotEmpty)
      .toList();
}

/// 「まとめて貼り付け」のテキストを 1 行 1 曲として読む。
/// Windows の改行（\r\n）でも同じ結果になるようにしている。
List<String> parseSongTitlesFromText(String text) {
  return normalizeSongTitles(text.split(RegExp(r'\r?\n')));
}

/// 曲名のリストを「まとめて貼り付け」のテキストに戻す（入力モードの切り替え用）。
String songTitlesToText(Iterable<String> titles) {
  return normalizeSongTitles(titles).join('\n');
}

/// 同じ曲とみなすためのキー。前後の空白を除き、英字の大小を無視する。
/// DB 側の生成列 `songs.title_key`（lower(btrim(title))）と同じ規則。
String songTitleKey(String title) {
  return title.trim().toLowerCase();
}

/// ライブ名の上限文字数（DB の check 制約と同じ）。
const int maxLiveTitleLength = 100;

/// 入力チェックで引っかかった項目。
enum LiveField { title, performedOn }

/// 入力チェックの結果（どの項目が・なぜだめか）。
class ValidationError {
  const ValidationError(this.field, this.message);

  final LiveField field;
  final String message;

  // テストで「同じ内容のエラーか」を比べられるようにする
  @override
  bool operator ==(Object other) =>
      other is ValidationError &&
      other.field == field &&
      other.message == message;

  @override
  int get hashCode => Object.hash(field, message);
}

/// 保存前の入力チェック。問題がなければ null を返す。
/// DB でも同じ条件で弾かれるが、先に画面側で見ておくと通信せずにすぐ知らせられる。
ValidationError? validateLiveInput({
  required String title,
  required String performedOn,
}) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) {
    return const ValidationError(LiveField.title, 'ライブ名を入力してください。');
  }
  // Dart の length は絵文字などを 2 と数えるので、DB の char_length と同じ
  // 「文字の数」になるよう runes（Unicode の文字単位）で数える
  if (trimmed.runes.length > maxLiveTitleLength) {
    return const ValidationError(
      LiveField.title,
      'ライブ名は$maxLiveTitleLength文字までです。',
    );
  }
  if (performedOn.isEmpty) {
    return const ValidationError(LiveField.performedOn, '日付を入力してください。');
  }
  return null;
}

/// 曲一覧の並び順。
enum SongSort {
  count('演奏回数順'),
  last('最近やった順'),
  name('曲名順');

  const SongSort(this.label);

  /// 画面に出す名前
  final String label;
}

/// 曲名での絞り込み。大小文字は無視した部分一致。
List<SongStat> filterSongs(List<SongStat> songs, String query) {
  final keyword = query.trim().toLowerCase();
  if (keyword.isEmpty) return [...songs];
  return songs
      .where((song) => song.title.toLowerCase().contains(keyword))
      .toList();
}

/// 曲名どうしの比較。英字の大小を無視し、同じなら元の文字列で決める。
int _compareTitle(SongStat a, SongStat b) {
  final result = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  return result != 0 ? result : a.title.compareTo(b.title);
}

/// 並び替え。元のリストは書き換えず、新しいリストを返す。
/// 同点のときは曲名順にして、表示するたびに並びが変わらないようにする。
List<SongStat> sortSongs(List<SongStat> songs, SongSort sort) {
  final sorted = [...songs];
  switch (sort) {
    case SongSort.count:
      sorted.sort((a, b) {
        final byCount = b.playCount.compareTo(a.playCount);
        return byCount != 0 ? byCount : _compareTitle(a, b);
      });
    case SongSort.last:
      sorted.sort((a, b) {
        // YYYY-MM-DD は文字列のまま比べても日付順になる
        final byDate = b.lastPlayedOn.compareTo(a.lastPlayedOn);
        return byDate != 0 ? byDate : _compareTitle(a, b);
      });
    case SongSort.name:
      sorted.sort(_compareTitle);
  }
  return sorted;
}

/// 演奏回数バーの基準になる最大値。0 で割らないよう最低 1 を返す。
int maxPlayCount(List<SongStat> songs) {
  var max = 1;
  for (final song in songs) {
    if (song.playCount > max) max = song.playCount;
  }
  return max;
}

/// 日付（YYYY-MM-DD）を画面表示用の「2026/02/14」にする。
String formatDate(String isoDate) {
  return isoDate.replaceAll('-', '/');
}

/// DateTime を DB に送る形（YYYY-MM-DD）にする。
String toIsoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
