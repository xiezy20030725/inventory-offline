import 'package:flutter/material.dart';

/// 设计规范：与首页设计稿一致的设计 Token
class AppColors {
  static const primary = Color(0xFF2F6BFF);
  static const navyDeep = Color(0xFF0C1C3D);
  static const navy = Color(0xFF16294F);
  static const bg = Color(0xFFEEF1F6);
  static const card = Colors.white;
  static const itemBg = Color(0xFFF6F7FA);
  static const textDark = Color(0xFF1A2233);
  static const textSub = Color(0xFF8A94A6);
  static const line = Color(0xFFECEEF3);

  static const blue = Color(0xFF2F6BFF);
  static const blueBg = Color(0xFFE8F0FE);
  static const green = Color(0xFF21B573);
  static const greenBg = Color(0xFFE7F6EE);
  static const red = Color(0xFFF0483E);
  static const redBg = Color(0xFFFDEBEA);
  static const orange = Color(0xFFFF9F2E);
  static const orangeBg = Color(0xFFFFF3E2);
  static const indigo = Color(0xFF5B6CFF);

  /// 头部深蓝渐变（状态栏+标题区域）
  static const headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B1936), Color(0xFF122A55), Color(0xFF9FB0CC), Color(0xFFEEF1F6)],
    stops: [0.0, 0.55, 0.85, 1.0],
  );
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: AppColors.textDark,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textDark),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.itemBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(64, 44),
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
  );
}
