import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/setlist.dart';
import '../models/live.dart';
import 'archive_repository.dart';

/// ArchiveRepository を Supabase で実装したもの。
/// Supabase を呼ぶのはこのファイルだけにして、画面から直接 `from()` を呼ばない。
///
/// 他人のデータが見えないのは、ここで user_id を絞っているからではない。
/// DB 側の RLS（行ごとのアクセス制御）が「ログイン中の本人の行」しか返さないから。
/// アプリのコードを書き換えられても、他人の行は取れない。
class SupabaseArchiveRepository implements ArchiveRepository {
  SupabaseArchiveRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Live>> fetchLives() async {
    // setlist_items と songs も一緒に取り、通信を 1 回で済ませる
    final rows = await _client
        .from('lives')
        .select(
          'id, title, performed_on, venue, setlist_items(position, songs(title))',
        )
        .order('performed_on', ascending: false)
        .order('created_at', ascending: false);

    return rows.map(_liveFromRow).toList();
  }

  /// DB の 1 行（Map）を Live に変換する。
  Live _liveFromRow(Map<String, dynamic> row) {
    final items = (row['setlist_items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .toList();
    // 曲順（position）の並びで返ってくる保証はないので、ここで並べ直す
    items.sort(
      (a, b) => (a['position'] as int).compareTo(b['position'] as int),
    );

    return Live(
      id: row['id'] as String,
      title: row['title'] as String,
      performedOn: row['performed_on'] as String,
      venue: row['venue'] as String?,
      songs: items
          .map((item) => item['songs'] as Map<String, dynamic>?)
          .map((song) => song?['title'] as String? ?? '')
          .where((title) => title.isNotEmpty)
          .toList(),
    );
  }

  @override
  Future<List<SongStat>> fetchSongStats() async {
    // 集計は DB のビュー song_stats に任せる。
    // 全ライブを取ってきてアプリ側で数えると、ライブが増えるほど通信量が増えるため。
    final rows = await _client
        .from('song_stats')
        .select('id, title, play_count, last_played_on');

    return rows
        .map(
          (row) => SongStat(
            id: row['id'] as String,
            title: row['title'] as String,
            playCount: row['play_count'] as int,
            lastPlayedOn: row['last_played_on'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<List<LiveOfSong>> fetchLivesForSong(String songId) async {
    final rows = await _client
        .from('setlist_items')
        .select('lives(id, title, performed_on, venue)')
        .eq('song_id', songId);

    // 同じライブで同じ曲を 2 回演奏していると 2 行返るので、ライブの ID でまとめる
    final byLiveId = <String, LiveOfSong>{};
    for (final row in rows) {
      final live = row['lives'] as Map<String, dynamic>?;
      if (live == null) continue;
      final id = live['id'] as String;
      byLiveId[id] = LiveOfSong(
        id: id,
        title: live['title'] as String,
        performedOn: live['performed_on'] as String,
        venue: live['venue'] as String?,
      );
    }

    final lives = byLiveId.values.toList();
    lives.sort((a, b) => b.performedOn.compareTo(a.performedOn));
    return lives;
  }

  @override
  Future<String> saveLive(LiveInput input) async {
    // ライブ・曲・曲順を別々に送ると、途中で失敗したとき半端なデータが残る。
    // DB の関数 save_live は 1 つのトランザクション（全部成功か、全部なかったことにするか）
    // で保存するので、これを 1 回だけ呼ぶ。setlist_items へ直接 insert はしない。
    final liveId = await _client.rpc<dynamic>(
      'save_live',
      params: {
        'p_live_id': input.id,
        'p_title': input.title.trim(),
        'p_performed_on': input.performedOn,
        'p_venue': input.venue.trim(),
        'p_songs': normalizeSongTitles(input.songs),
      },
    );
    return liveId as String;
  }

  @override
  Future<void> deleteLive(String liveId) async {
    // setlist_items は DB の on delete cascade で一緒に消える。曲（songs）は残す。
    await _client.from('lives').delete().eq('id', liveId);
  }
}
