// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../api/archive_repository.dart';
import '../logic/setlist.dart';
import '../models/live.dart';
import '../theme.dart';

/// ライブの追加・編集画面（下から出てくるシート）。
/// 保存できたら Navigator.pop(context, true) で閉じ、呼び出し元に「保存した」と伝える。
class LiveEditorSheet extends StatefulWidget {
  const LiveEditorSheet({
    super.key,
    required this.live,
    required this.repository,
  });

  /// 編集対象。新規追加なら null
  final Live? live;
  final ArchiveRepository repository;

  @override
  State<LiveEditorSheet> createState() => _LiveEditorSheetState();
}

class _LiveEditorSheetState extends State<LiveEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _venueController;
  late final TextEditingController _bulkController;

  /// 「1曲ずつ」モードの入力欄。1 曲に 1 つ
  late List<TextEditingController> _songControllers;

  late DateTime _performedOn;

  /// true なら「まとめて貼り付け」モード
  bool _bulk = false;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final live = widget.live;
    _titleController = TextEditingController(text: live?.title ?? '');
    _venueController = TextEditingController(text: live?.venue ?? '');
    _bulkController = TextEditingController(
      text: songTitlesToText(live?.songs ?? []),
    );
    _songControllers = _controllersFor(live?.songs ?? []);
    _performedOn = live == null
        ? DateTime.now()
        : DateTime.parse(live.performedOn);
  }

  /// 曲名のリストから入力欄を作る。空なら空欄を 1 つ用意して、すぐ打ち始められるようにする
  List<TextEditingController> _controllersFor(List<String> songs) {
    if (songs.isEmpty) return [TextEditingController()];
    return [for (final song in songs) TextEditingController(text: song)];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    _bulkController.dispose();
    for (final controller in _songControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 今のモードで入力されている曲名
  List<String> get _currentSongs => _bulk
      ? parseSongTitlesFromText(_bulkController.text)
      : normalizeSongTitles(_songControllers.map((c) => c.text));

  // モードを切り替えるときは、今の内容をもう一方に写してから切り替える（入力が消えないように）
  void _switchToSingle() {
    if (!_bulk) return;
    final songs = parseSongTitlesFromText(_bulkController.text);
    setState(() {
      for (final controller in _songControllers) {
        controller.dispose();
      }
      _songControllers = _controllersFor(songs);
      _bulk = false;
    });
  }

  void _switchToBulk() {
    if (_bulk) return;
    setState(() {
      _bulkController.text = songTitlesToText(
        _songControllers.map((c) => c.text),
      );
      _bulk = true;
    });
  }

  void _moveSong(int index, int direction) {
    final target = index + direction;
    if (target < 0 || target >= _songControllers.length) return;
    setState(() {
      final moving = _songControllers[index];
      _songControllers[index] = _songControllers[target];
      _songControllers[target] = moving;
    });
  }

  void _removeSong(int index) {
    setState(() => _songControllers.removeAt(index).dispose());
  }

  void _addSong() {
    setState(() => _songControllers.add(TextEditingController()));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _performedOn,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _performedOn = picked);
  }

  Future<void> _save() async {
    final performedOn = toIsoDate(_performedOn);
    final invalid = validateLiveInput(
      title: _titleController.text,
      performedOn: performedOn,
    );
    if (invalid != null) {
      setState(() => _error = invalid.message);
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.repository.saveLive(
        LiveInput(
          id: widget.live?.id,
          title: _titleController.text,
          performedOn: performedOn,
          venue: _venueController.text,
          songs: _currentSongs,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('保存失敗: $e');
      if (!mounted) return;
      setState(() {
        _error = '保存できませんでした。通信状況を確認して、もう一度「保存する」を押してください。';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // シートは白い紙なので、この中だけ明るい配色に切り替える
    final base = Theme.of(context);
    final lightTheme = base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: StageColors.ink,
        onPrimary: StageColors.paper,
        surface: StageColors.paper,
        onSurface: StageColors.ink,
        onSurfaceVariant: StageColors.ink,
        // 「1曲ずつ／まとめて貼り付け」の選ばれている側の色
        secondaryContainer: StageColors.ink,
        onSecondaryContainer: StageColors.paper,
        error: StageColors.warn,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: StageColors.ink,
        displayColor: StageColors.ink,
      ),
      // ↑↓✕ などのアイコンボタンも墨色にする
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: StageColors.ink),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(),
      ),
    );

    return Theme(
      data: lightTheme,
      // シートの土台は外側（紺の画面）の文字色を引き継ぐので、ここで文字色を墨色にし直す
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: StageColors.ink),
        child: Padding(
          // キーボードが出たら、その分だけ下に余白を入れて入力欄が隠れないようにする
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHead(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    maxLength: maxLiveTitleLength,
                    decoration: const InputDecoration(
                      labelText: 'ライブ名',
                      hintText: '例：定期ライブ vol.3',
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(formatDate(toIsoDate(_performedOn))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _venueController,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: '会場',
                            hintText: '例：下北沢〇〇',
                            counterText: '', // 文字数カウンターは出さない
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildModeSwitch(),
                  const SizedBox(height: 12),
                  if (_bulk) _buildBulkInput() else _buildSingleInputs(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: StageColors.warn),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: StageColors.ink,
                      foregroundColor: StageColors.paper,
                    ),
                    child: Text(_saving ? '保存中…' : '保存する'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHead() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'セットリスト',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.close),
          tooltip: '閉じる',
        ),
      ],
    );
  }

  /// 「1曲ずつ」と「まとめて貼り付け」の切り替え
  Widget _buildModeSwitch() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('1曲ずつ')),
        ButtonSegment(value: true, label: Text('まとめて貼り付け')),
      ],
      selected: {_bulk},
      showSelectedIcon: false,
      onSelectionChanged: (selected) {
        if (selected.first) {
          _switchToBulk();
        } else {
          _switchToSingle();
        }
      },
    );
  }

  Widget _buildBulkInput() {
    return TextField(
      controller: _bulkController,
      minLines: 8,
      maxLines: 12,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(hintText: '1行に1曲\n曲名A\n曲名B'),
    );
  }

  Widget _buildSingleInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _songControllers.length; i++)
          Padding(
            // 並べ替えたときに入力欄と中身の対応がずれないよう、
            // 入力欄（controller）そのものを key にする
            key: ObjectKey(_songControllers[i]),
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 24, child: Text('${i + 1}.')),
                Expanded(
                  child: TextField(
                    controller: _songControllers[i],
                    decoration: InputDecoration(hintText: '${i + 1}曲目'),
                  ),
                ),
                IconButton(
                  onPressed: () => _moveSong(i, -1),
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: '${i + 1}曲目を上へ',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () => _moveSong(i, 1),
                  icon: const Icon(Icons.arrow_downward),
                  tooltip: '${i + 1}曲目を下へ',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () => _removeSong(i),
                  icon: const Icon(Icons.close),
                  tooltip: '${i + 1}曲目を削除',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addSong,
            icon: const Icon(Icons.add),
            label: const Text('曲を追加'),
          ),
        ),
      ],
    );
  }
}
