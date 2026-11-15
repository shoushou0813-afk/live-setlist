// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../api/archive_repository.dart';
import '../logic/setlist.dart';
import '../models/live.dart';
import '../theme.dart';
import '../widgets/message_view.dart';

/// 曲一覧タブ。演奏回数・最後に演奏した日を出し、並び替えと検索ができる。
/// 曲をタップすると、その曲を演奏したライブを開く。
class SongsScreen extends StatefulWidget {
  const SongsScreen({
    super.key,
    required this.songs,
    required this.repository,
    required this.onRefresh,
  });

  final List<SongStat> songs;
  final ArchiveRepository repository;
  final Future<void> Function() onRefresh;

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  String _query = '';
  SongSort _sort = SongSort.count;

  /// 開いている曲の ID（閉じていれば null）
  String? _openSongId;

  /// 開いている曲を演奏したライブ。読み込み中は null
  List<LiveOfSong>? _openLives;
  String? _openError;

  /// 曲をタップしたとき：同じ曲なら閉じ、別の曲なら開いて演奏したライブを取りに行く
  Future<void> _toggleSong(String songId) async {
    if (_openSongId == songId) {
      setState(() => _openSongId = null);
      return;
    }

    setState(() {
      _openSongId = songId;
      _openLives = null;
      _openError = null;
    });

    try {
      final lives = await widget.repository.fetchLivesForSong(songId);
      // 読み込み中に別の曲をタップされていたら、遅れて届いた結果は捨てる
      if (!mounted || _openSongId != songId) return;
      setState(() => _openLives = lives);
    } catch (e) {
      debugPrint('出演ライブの読み込み失敗: $e');
      if (!mounted || _openSongId != songId) return;
      setState(() => _openError = '読み込めませんでした。曲をもう一度タップしてください。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleSongs = sortSongs(filterSongs(widget.songs, _query), _sort);
    // バーの長さは絞り込み後ではなく全体の最大値を基準にして、検索しても長さが変わらないようにする
    final max = maxPlayCount(widget.songs);

    return Column(
      children: [
        _buildTools(),
        Expanded(
          // 下に引っ張ると再読み込み
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: _buildList(visibleSongs, max),
          ),
        ),
      ],
    );
  }

  /// 検索欄と並び替え
  Widget _buildTools() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: '曲名で探す',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<SongSort>(
            value: _sort,
            dropdownColor: StageColors.stage2,
            underline: const SizedBox.shrink(),
            items: [
              for (final sort in SongSort.values)
                DropdownMenuItem(value: sort, child: Text(sort.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _sort = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<SongStat> visibleSongs, int max) {
    // 空の状態でも下に引っ張って再読み込みできるよう、ListView の中にメッセージを置く
    if (widget.songs.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          MessageView(message: 'まだ曲がありません。\n「ライブ」タブからセットリストを追加してください。'),
        ],
      );
    }
    if (visibleSongs.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          MessageView(message: '「$_query」に一致する曲はありませんでした。'),
        ],
      );
    }

    // ListView.builder は画面に見えている行だけを作るので、曲が多くても重くならない
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: visibleSongs.length,
      itemBuilder: (context, index) {
        final song = visibleSongs[index];
        return _SongRow(
          song: song,
          max: max,
          isOpen: _openSongId == song.id,
          lives: _openLives,
          error: _openError,
          onTap: () => _toggleSong(song.id),
        );
      },
    );
  }
}

/// 曲 1 行分（開いていれば演奏したライブも出す）
class _SongRow extends StatelessWidget {
  const _SongRow({
    required this.song,
    required this.max,
    required this.isOpen,
    required this.lives,
    required this.error,
    required this.onTap,
  });

  final SongStat song;
  final int max;
  final bool isOpen;
  final List<LiveOfSong>? lives;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: StageColors.stage2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '最終 ${formatDate(song.lastPlayedOn)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: StageColors.mute,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 演奏回数に比例したバー
                  SizedBox(
                    width: 80,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: song.playCount / max,
                        minHeight: 8,
                        color: StageColors.tape,
                        backgroundColor: StageColors.stage2,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${song.playCount}回',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: StageColors.mute),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOpen) _buildLives(),
        ],
      ),
    );
  }

  Widget _buildLives() {
    const style = TextStyle(fontSize: 14, color: Color(0xFFC5CDE0));
    final Widget content;
    if (error != null) {
      content = Text(error!, style: const TextStyle(color: StageColors.warn));
    } else if (lives == null) {
      content = const Text('読み込み中…', style: style);
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final live in lives!)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${formatDate(live.performedOn)}  ',
                      style: const TextStyle(color: StageColors.mute),
                    ),
                    TextSpan(text: live.title),
                    if (live.venue != null) TextSpan(text: '（${live.venue}）'),
                  ],
                ),
                style: style,
              ),
            ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12),
      child: content,
    );
  }
}
