/// 画面で使うデータの形（モデル）。
/// DB の行（Map）をそのまま画面に渡すと、キーの打ち間違いが実行するまで分からない。
/// クラスにしておくと、間違いを書いた時点でエディタが教えてくれる。
library;

/// ライブ 1 本分。
class Live {
  const Live({
    required this.id,
    required this.title,
    required this.performedOn,
    required this.venue,
    required this.songs,
  });

  final String id;
  final String title;

  /// 演奏した日（YYYY-MM-DD）。DB の date 型をそのまま文字列で持つ。
  final String performedOn;

  /// 会場。任意入力なので null になりうる。
  final String? venue;

  /// 曲順（position）どおりに並べた曲名。
  final List<String> songs;
}

/// ある曲を演奏したライブ（曲一覧で曲をタップしたときに出す）。
class LiveOfSong {
  const LiveOfSong({
    required this.id,
    required this.title,
    required this.performedOn,
    required this.venue,
  });

  final String id;
  final String title;
  final String performedOn;
  final String? venue;
}

/// 曲ごとの集計（演奏回数・最後に演奏した日）。
class SongStat {
  const SongStat({
    required this.id,
    required this.title,
    required this.playCount,
    required this.lastPlayedOn,
  });

  final String id;
  final String title;
  final int playCount;
  final String lastPlayedOn;
}

/// 保存するときに送る入力。
class LiveInput {
  const LiveInput({
    required this.id,
    required this.title,
    required this.performedOn,
    required this.venue,
    required this.songs,
  });

  /// 新規なら null、更新なら対象のライブ ID。
  final String? id;
  final String title;
  final String performedOn;
  final String venue;
  final List<String> songs;
}
