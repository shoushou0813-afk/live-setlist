// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../theme.dart';

/// 読み込み中の表示。
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = '読み込み中…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: StageColors.tape),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: StageColors.mute)),
        ],
      ),
    );
  }
}

/// エラーや「まだ何もない」ことを伝える表示。
/// onRetry を渡すと「もう一度読み込む」ボタンが出る。
class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: StageColors.mute, height: 1.6),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('もう一度読み込む')),
            ],
          ],
        ),
      ),
    );
  }
}
