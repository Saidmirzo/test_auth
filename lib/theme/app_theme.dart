import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0B1020);
  static const surface = Color(0xFF151C2E);
  static const surfaceAlt = Color(0xFF1D2740);
  static const border = Color(0xFF2C3A5A);
  static const primary = Color(0xFF6EA8FE);
  static const primaryStrong = Color(0xFF3D8BFF);
  static const text = Color(0xFFF4F7FF);
  static const muted = Color(0xFF9AA8C7);
  static const facebook = Color(0xFF1877F2);
  static const danger = Color(0xFFFF6B6B);
}

class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.primaryStrong,
      surface: AppColors.surface,
      error: AppColors.danger,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: const TextStyle(color: AppColors.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
