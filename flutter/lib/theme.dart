// 授業（Flutter 3.3x 系）と同じ import にそろえている。
// Flutter 3.47 以降では package:material_ui に移って「非推奨」の表示が出るが、動作は同じ。
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// 試作版（reference/prototype.jsx）の配色。React 版の src/styles/global.css と同じ値。
abstract final class StageColors {
  /// ステージの紺（背景）
  static const stage = Color(0xFF1F2A44);
  static const stage2 = Color(0xFF2B3A5C);

  /// セトリの紙
  static const paper = Color(0xFFF3F5F8);
  static const ink = Color(0xFF1C2233);

  /// ガムテープの黄（強調色）
  static const tape = Color(0xFFE8C547);
  static const mute = Color(0xFF8D9AB5);
  static const warn = Color(0xFFC8553D);
  static const venueText = Color(0xFF5B6479);
}

/// セトリ用の手書き風フォント（Klee One）。
TextStyle handwritten({double fontSize = 18, Color color = StageColors.ink}) {
  return TextStyle(
    fontFamily: 'KleeOne', // pubspec.yaml の fonts で登録した名前
    fontSize: fontSize,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.6,
  );
}

/// アプリ全体の見た目。
/// 部品ごとに色を指定するのではなく、ここで一括して決めておく（Material の Theme の仕組み）。
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: StageColors.tape,
      onPrimary: StageColors.ink,
      surface: StageColors.stage,
      onSurface: StageColors.paper,
      secondary: StageColors.mute,
      error: StageColors.warn,
    ),
    scaffoldBackgroundColor: StageColors.stage,
    // 本文は Zen Kaku Gothic New（pubspec.yaml の fonts で登録した名前）
    fontFamily: 'ZenKakuGothicNew',
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: StageColors.paper,
      displayColor: StageColors.paper,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: StageColors.tape,
        foregroundColor: StageColors.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
  );
}
