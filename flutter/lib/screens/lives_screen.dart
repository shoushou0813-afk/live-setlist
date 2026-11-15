// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../api/archive_repository.dart';
import '../logic/setlist.dart';
import '../models/live.dart';
import '../theme.dart';
import '../widgets/live_editor_sheet.dart';
import '../widgets/message_view.dart';

/// ライブタブ。ライブをセトリ風のカードで日付の新しい順に並べる。
class LivesScreen extends StatefulWidget {
  const LivesScreen({
    super.key,
    required this.lives,
    required this.repository,
    required this.onChanged,
  });

  final List<Live> lives;
  final ArchiveRepository repository;

  /// 保存・削除のあとに呼ぶ（一覧と集計を取り直す）
  final Future<void> Function() onChanged;

  @override
  State<LivesScreen> createState() => _LivesScreenState();
}

class _LivesScreenState extends State<LivesScreen> {
  /// 開いているカードのライブ ID
  String? _openLiveId;

  /// 編集画面を下から出す。保存されたら一覧を取り直す。
  /// live が null なら新規追加。
  Future<void> _openEditor(Live? live) async {
    // showModalBottomSheet は、画面を閉じるときに Navigator.pop で渡した値を返す
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // キーボードが出ても隠れないよう、高さを中身に合わせる
      backgroundColor: StageColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) =>
          LiveEditorSheet(live: live, repository: widget.repository),
    );
    if (saved == true) await widget.onChanged();
  }

  Future<void> _delete(Live live) async {
    // 取り消せない操作なので、確認のダイアログを出す
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ライブを削除'),
        content: Text('「${live.title}」を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('やめる'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: StageColors.warn),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.repository.deleteLive(live.id);
      if (!mounted) return;
      setState(() => _openLiveId = null);
      await widget.onChanged();
    } catch (e) {
      debugPrint('削除失敗: $e');
      if (!mounted) return;
      // 画面下に一時的なメッセージを出す
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('削除できませんでした。通信状況を確認してもう一度お試しください。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onChanged,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _openEditor(null),
              icon: const Icon(Icons.add),
              label: const Text('ライブを追加'),
            ),
          ),
          const SizedBox(height: 24),
          if (widget.lives.isEmpty)
            const MessageView(message: '最初のライブを追加すると、ここに並びます。')
          else
            for (var i = 0; i < widget.lives.length; i++)
              _SetlistCard(
                live: widget.lives[i],
                // 紙を少しずつ傾けて、壁に貼ったセトリのように見せる（試作版と同じ）
                tilt: i.isEven ? -0.010 : 0.012,
                isOpen: _openLiveId == widget.lives[i].id,
                onTap: () {
                  final id = widget.lives[i].id;
                  setState(() => _openLiveId = _openLiveId == id ? null : id);
                },
                onEdit: () => _openEditor(widget.lives[i]),
                onDelete: () => _delete(widget.lives[i]),
              ),
        ],
      ),
    );
  }
}

/// セトリ風のカード 1 枚分
class _SetlistCard extends StatelessWidget {
  const _SetlistCard({
    required this.live,
    required this.tilt,
    required this.isOpen,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Live live;

  /// 傾き（ラジアン）
  final double tilt;
  final bool isOpen;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const venueStyle = TextStyle(fontSize: 13, color: StageColors.venueText);

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Transform.rotate(
        angle: tilt,
        // Stack で紙の上にガムテープを重ねる
        child: Stack(
          clipBehavior: Clip.none, // テープが紙からはみ出しても切らない
          children: [
            Material(
              color: StageColors.paper,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        formatDate(live.performedOn),
                        style: const TextStyle(
                          fontSize: 13,
                          color: StageColors.venueText,
                        ),
                      ),
                      Text(live.title, style: handwritten(fontSize: 22)),
                      if (live.venue != null)
                        Text(live.venue!, style: venueStyle),
                      if (!isOpen)
                        Text(
                          '${live.songs.length}曲 ・ タップで開く',
                          style: venueStyle,
                        ),
                      if (isOpen) ..._buildOpened(venueStyle),
                    ],
                  ),
                ),
              ),
            ),
            // ガムテープ
            Positioned(
              top: -9,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 70,
                  height: 20,
                  color: StageColors.tape.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOpened(TextStyle venueStyle) {
    return [
      const SizedBox(height: 12),
      if (live.songs.isEmpty)
        Text('曲が登録されていません。', style: venueStyle)
      else
        // 同じ曲を 2 回演奏することがあるので、曲名ではなく曲順（何番目か）で並べる
        for (var i = 0; i < live.songs.length; i++)
          Text('${i + 1}. ${live.songs[i]}', style: handwritten()),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('編集'),
              style: OutlinedButton.styleFrom(
                foregroundColor: StageColors.ink,
                side: const BorderSide(color: StageColors.ink, width: 1.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('削除'),
              style: OutlinedButton.styleFrom(
                foregroundColor: StageColors.warn,
                side: const BorderSide(color: StageColors.warn, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    ];
  }
}
