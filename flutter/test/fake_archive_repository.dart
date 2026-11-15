import 'package:live_setlist/api/archive_repository.dart';
import 'package:live_setlist/models/live.dart';

/// テスト用の偽物の ArchiveRepository。
///
/// 画面は ArchiveRepository（約束ごと）しか知らないので、Supabase の代わりにこれを渡せば
/// 通信せずに画面を動かせる。呼ばれた内容を記録しておき、テストで「正しく呼ばれたか」を確かめる。
class FakeArchiveRepository implements ArchiveRepository {
  FakeArchiveRepository({
    this.lives = const [],
    this.songs = const [],
    this.livesOfSong = const [],
  });

  List<Live> lives;
  List<SongStat> songs;
  List<LiveOfSong> livesOfSong;

  /// true にすると、一覧の取得が失敗する
  bool failFetch = false;

  /// 一覧を取得した回数（再読み込みされたかを確かめる）
  int fetchCount = 0;

  /// saveLive に渡された入力
  final List<LiveInput> savedInputs = [];

  /// deleteLive に渡された ID
  final List<String> deletedIds = [];

  @override
  Future<List<Live>> fetchLives() async {
    fetchCount++;
    if (failFetch) throw Exception('通信エラー（テスト用）');
    return lives;
  }

  @override
  Future<List<SongStat>> fetchSongStats() async {
    if (failFetch) throw Exception('通信エラー（テスト用）');
    return songs;
  }

  @override
  Future<List<LiveOfSong>> fetchLivesForSong(String songId) async {
    return livesOfSong;
  }

  @override
  Future<String> saveLive(LiveInput input) async {
    savedInputs.add(input);
    return input.id ?? 'new-live-id';
  }

  @override
  Future<void> deleteLive(String liveId) async {
    deletedIds.add(liveId);
  }
}
