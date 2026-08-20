import 'package:flutter/material.dart';

abstract final class YallaColors {
  static const primary = Color(0xFF1EA7E0);
  static const primaryStrong = Color(0xFF0B7EB0);
  static const navy = Color(0xFF0E2A3B);
  static const surfaceAlt = Color(0xFFEAF6FC);
  static const gold = Color(0xFFE7A93E);
  static const success = Color(0xFF1F9D6B);
  static const danger = Color(0xFFD9534F);
}

ThemeData buildYallaTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: YallaColors.primary,
    brightness: brightness,
    primary: dark ? const Color(0xFF3FC1F0) : YallaColors.primaryStrong,
    surface: dark ? const Color(0xFF0F2836) : Colors.white,
    error: dark ? const Color(0xFFF27C73) : YallaColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'packages/yalla_cash_core/Almarai',
    colorScheme: scheme,
    scaffoldBackgroundColor:
        dark ? const Color(0xFF0F2836) : const Color(0xFFF7FBFD),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: dark ? const Color(0xFF123040) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: dark
              ? Colors.white.withValues(alpha: .10)
              : YallaColors.navy.withValues(alpha: .08),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF163647) : YallaColors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: dark
              ? Colors.white.withValues(alpha: .08)
              : YallaColors.navy.withValues(alpha: .07),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primary.withValues(alpha: .14),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: scheme.onSurface, fontSize: 11),
      ),
    ),
  );
}
