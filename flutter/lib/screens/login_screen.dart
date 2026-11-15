// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

/// ログイン画面。新規登録はない（アカウントは Supabase のダッシュボードで作る）。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final GoTrueClient auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 入力欄の中身を読み書きするためのもの。使い終わったら dispose で片付ける
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'メールアドレスとパスワードを入力してください。');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true; // 二重送信を防ぐためボタンを押せなくする
    });

    try {
      await widget.auth.signInWithPassword(email: email, password: password);
      // 成功したら AuthGate が状態の変化を受け取り、メイン画面に切り替える
    } on AuthException {
      // どちらが違うかは伝えない（登録されているメールアドレスを当てられないようにするため）
      _showError('メールアドレスかパスワードが違います。入力を確認してもう一度お試しください。');
    } catch (_) {
      _showError('通信できませんでした。電波の良い場所でもう一度お試しください。');
    }
  }

  void _showError(String message) {
    // await の間に画面が閉じられていたら setState しない
    if (!mounted) return;
    setState(() {
      _error = message;
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '演奏した曲',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ライブのセットリストを記録するアプリです。',
                    style: TextStyle(color: StageColors.mute),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'メールアドレス'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true, // 入力した文字を伏せる
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(labelText: 'パスワード'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: StageColors.warn),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    // null を渡すとボタンが押せなくなる
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? 'ログイン中…' : 'ログイン'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
