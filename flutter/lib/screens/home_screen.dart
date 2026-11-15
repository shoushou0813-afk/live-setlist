// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../api/archive_repository.dart';
import '../models/live.dart';
import '../theme.dart';
import '../widgets/message_view.dart';
import 'lives_screen.dart';
import 'songs_screen.dart';

/// ログイン後のメイン画面。ヘッダーと「曲一覧」「ライブ」の 2 つのタブ。
///
/// ライブ一覧と曲の集計はここで 1 回だけ取得し、両方のタブに渡す。
/// ヘッダーの本数・曲数と 2 つのタブが同じデータを見るので、タブごとに取得すると
/// 「ライブを追加したのに曲一覧の回数が古いまま」のようなずれが起きるため。
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.onLogout,
  });

  final ArchiveRepository repository;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Live> _lives = [];
  List<SongStat> _songs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// ライブ一覧と曲の集計を取り直す。保存・削除のあとにも呼ぶ。
  /// 集計は DB のビューが計算するので、アプリ側で数え直すことはしない。
  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      // 2 つの通信を同時に始めて、両方終わるのを待つ（順番に待つより速い）
      final results = await Future.wait([
        widget.repository.fetchLives(),
        widget.repository.fetchSongStats(),
      ]);
      if (!mounted) return;
      setState(() {
        _lives = results[0] as List<Live>;
        _songs = results[1] as List<SongStat>;
        _loading = false;
      });
    } catch (e) {
      debugPrint('読み込み失敗: $e');
      if (!mounted) return;
      setState(() {
        _error = 'データを読み込めませんでした。\n通信状況を確認して、もう一度読み込んでください。';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: StageColors.stage,
          toolbarHeight: 84,
          titleSpacing: 16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '演奏した曲',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              Text(
                '${_lives.length}本のライブ ／ ${_songs.length}曲',
                style: const TextStyle(fontSize: 14, color: StageColors.mute),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: widget.onLogout,
              child: const Text(
                'ログアウト',
                style: TextStyle(color: StageColors.mute),
              ),
            ),
          ],
          bottom: const TabBar(
            labelColor: StageColors.paper,
            unselectedLabelColor: StageColors.mute,
            indicatorColor: StageColors.tape,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: '曲一覧'),
              Tab(text: 'ライブ'),
            ],
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_error != null) {
      return MessageView(message: _error!, onRetry: _reload);
    }
    return TabBarView(
      children: [
        SongsScreen(
          songs: _songs,
          repository: widget.repository,
          onRefresh: _reload,
        ),
        LivesScreen(
          lives: _lives,
          repository: widget.repository,
          onChanged: _reload,
        ),
      ],
    );
  }
}
