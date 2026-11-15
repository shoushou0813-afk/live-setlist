// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api/supabase_archive_repository.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

class LiveSetlistApp extends StatelessWidget {
  const LiveSetlistApp({super.key, required this.client});

  final SupabaseClient client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '演奏した曲',
      theme: buildAppTheme(),
      // 日付選択のカレンダーなどを日本語にする
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      // ignore: deprecated_member_use
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AuthGate(client: client),
    );
  }
}

/// ログインしているかどうかで、ログイン画面とメイン画面を出し分ける。
///
/// onAuthStateChange は「ログイン・ログアウト・トークン更新」のたびに値が届く Stream。
/// StreamBuilder で受け取ると、値が届くたびに build し直される。
/// これは画面の出し分けのためのもので、データを守っているのは DB 側の RLS。
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.client});

  final SupabaseClient client;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // main.dart の Supabase.initialize で復元が済んでいるので、
        // 起動直後でも currentSession をそのまま見てよい（ログイン画面が一瞬出ることがない）
        final session = client.auth.currentSession;
        if (session == null) {
          return LoginScreen(auth: client.auth);
        }
        // key にユーザー ID を入れて、別の人がログインしたら画面を作り直す。
        // 前の人のデータが画面に残らないようにするため。
        return HomeScreen(
          key: ValueKey(session.user.id),
          repository: SupabaseArchiveRepository(client),
          onLogout: () => client.auth.signOut(),
        );
      },
    );
  }
}
