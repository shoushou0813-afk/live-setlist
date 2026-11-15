// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'widgets/message_view.dart';

/// Supabase の接続先。キーをコードに直接書かず、起動時に渡す。
/// `flutter run --dart-define-from-file=env.json` で env.json の値が入る。
/// （env.json は .gitignore 済み。キー名だけの env.example.json をコミットしている）
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  // runApp より前に await を使うときに必要な初期化
  WidgetsFlutterBinding.ensureInitialized();

  // 設定漏れのまま起動すると「真っ白で原因不明」になりがちなので、
  // 何をすればいいかを画面に出して止める
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: MessageView(
            message:
                '接続先が設定されていません。\n'
                'env.example.json をコピーして env.json を作り、Supabase の '
                'Project Settings > API にある URL と anon key を書いてから、\n'
                'flutter run --dart-define-from-file=env.json で起動してください。',
          ),
        ),
      ),
    );
    return;
  }

  // ここで前回のログイン状態も端末から復元される（終わるまで待つ）
  // anon key は新しい名前では publishable key（公開してよい鍵）と呼ばれる。中身は同じ
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);

  runApp(LiveSetlistApp(client: Supabase.instance.client));
}
