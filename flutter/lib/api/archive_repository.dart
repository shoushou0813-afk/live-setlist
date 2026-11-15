import '../models/live.dart';

/// データの取得・保存の「約束ごと」だけを決めたもの。
///
/// 画面はこの abstract interface class だけを知っていて、中身が Supabase かどうかは知らない。
/// （授業の演習 2-F の `abstract interface class Reserve` と同じ考え方）
/// こうしておくと、通信の中身を差し替えても画面のコードを直さなくてよい。
abstract interface class ArchiveRepository {
  /// ライブ一覧を日付の新しい順で返す。
  Future<List<Live>> fetchLives();

  /// 曲ごとの演奏回数・最後に演奏した日を返す。
  Future<List<SongStat>> fetchSongStats();

  /// ある曲を演奏したライブを新しい順で返す。
  Future<List<LiveOfSong>> fetchLivesForSong(String songId);

  /// ライブ本体・曲・曲順をまとめて保存し、ライブの ID を返す。
  Future<String> saveLive(LiveInput input);

  /// ライブを削除する（曲順も一緒に消える。曲そのものは残す）。
  Future<void> deleteLive(String liveId);
}
