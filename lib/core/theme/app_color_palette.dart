import 'package:flutter/material.dart';

enum AppColorPalette {
  daybreak('晴空', '晴空蓝与阳光黄'),
  tokyoNight('东京', 'Tokyo Night'),
  everforest('森林', 'Everforest');

  const AppColorPalette(this.shortLabel, this.label);

  final String shortLabel;
  final String label;

  AppPaletteColors colors(Brightness brightness) {
    return switch ((this, brightness)) {
      (AppColorPalette.daybreak, Brightness.light) =>
        AppPaletteColors.daybreakLight,
      (AppColorPalette.daybreak, Brightness.dark) =>
        AppPaletteColors.daybreakDark,
      (AppColorPalette.tokyoNight, Brightness.light) =>
        AppPaletteColors.tokyoNightLight,
      (AppColorPalette.tokyoNight, Brightness.dark) =>
        AppPaletteColors.tokyoNightDark,
      (AppColorPalette.everforest, Brightness.light) =>
        AppPaletteColors.everforestLight,
      (AppColorPalette.everforest, Brightness.dark) =>
        AppPaletteColors.everforestDark,
    };
  }
}

@immutable
class AppPaletteColors {
  const AppPaletteColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.tertiary,
    required this.background,
    required this.surface,
    required this.card,
    required this.container,
    required this.containerHigh,
    required this.text,
    required this.muted,
    required this.border,
    required this.error,
    required this.success,
    required this.warning,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color tertiary;
  final Color background;
  final Color surface;
  final Color card;
  final Color container;
  final Color containerHigh;
  final Color text;
  final Color muted;
  final Color border;
  final Color error;
  final Color success;
  final Color warning;

  static const daybreakLight = AppPaletteColors(
    primary: Color(0xFF356AE6),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE3EAFF),
    onPrimaryContainer: Color(0xFF132C63),
    secondary: Color(0xFFF0B429),
    tertiary: Color(0xFF2BAE83),
    background: Color(0xFFF7F8FC),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    container: Color(0xFFF1F3F8),
    containerHigh: Color(0xFFE7EAF2),
    text: Color(0xFF22262F),
    muted: Color(0xFF717987),
    border: Color(0xFFE1E5ED),
    error: Color(0xFFD94A42),
    success: Color(0xFF2BAE83),
    warning: Color(0xFFD99A12),
  );

  static const daybreakDark = AppPaletteColors(
    primary: Color(0xFF91AAFF),
    onPrimary: Color(0xFF10234E),
    primaryContainer: Color(0xFF253A70),
    onPrimaryContainer: Color(0xFFDCE4FF),
    secondary: Color(0xFFF3C35B),
    tertiary: Color(0xFF65D5AE),
    background: Color(0xFF15171C),
    surface: Color(0xFF1B1E24),
    card: Color(0xFF22262D),
    container: Color(0xFF292E36),
    containerHigh: Color(0xFF343A44),
    text: Color(0xFFF4F5F7),
    muted: Color(0xFFA7ADB7),
    border: Color(0xFF373D47),
    error: Color(0xFFFF7B72),
    success: Color(0xFF58C596),
    warning: Color(0xFFF2B35E),
  );

  static const tokyoNightLight = AppPaletteColors(
    primary: Color(0xFF2959AA),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFD9E3FA),
    onPrimaryContainer: Color(0xFF152E61),
    secondary: Color(0xFF5A3E8E),
    tertiary: Color(0xFF8F5E15),
    background: Color(0xFFD6D8DF),
    surface: Color(0xFFE6E7ED),
    card: Color(0xFFE6E7ED),
    container: Color(0xFFDCDDE3),
    containerHigh: Color(0xFFCDCED1),
    text: Color(0xFF343B58),
    muted: Color(0xFF707280),
    border: Color(0xFFC1C2C7),
    error: Color(0xFFBD4040),
    success: Color(0xFF2D7D72),
    warning: Color(0xFF8F5E15),
  );

  static const tokyoNightDark = AppPaletteColors(
    primary: Color(0xFF7AA2F7),
    onPrimary: Color(0xFF10141F),
    primaryContainer: Color(0xFF29355A),
    onPrimaryContainer: Color(0xFFC0CAF5),
    secondary: Color(0xFFBB9AF7),
    tertiary: Color(0xFFE0AF68),
    background: Color(0xFF16161E),
    surface: Color(0xFF1A1B26),
    card: Color(0xFF1E202E),
    container: Color(0xFF202330),
    containerHigh: Color(0xFF24283B),
    text: Color(0xFFC0CAF5),
    muted: Color(0xFF9AA5CE),
    border: Color(0xFF363B54),
    error: Color(0xFFF7768E),
    success: Color(0xFF9ECE6A),
    warning: Color(0xFFE0AF68),
  );

  static const everforestLight = AppPaletteColors(
    primary: Color(0xFF35A77C),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE9F0E9),
    onPrimaryContainer: Color(0xFF244F43),
    secondary: Color(0xFF3A94C5),
    tertiary: Color(0xFFDFA000),
    background: Color(0xFFEFEBD4),
    surface: Color(0xFFFDF6E3),
    card: Color(0xFFFDF6E3),
    container: Color(0xFFF4F0D9),
    containerHigh: Color(0xFFE6E2CC),
    text: Color(0xFF5C6A72),
    muted: Color(0xFF829181),
    border: Color(0xFFBDC3AF),
    error: Color(0xFFF85552),
    success: Color(0xFF35A77C),
    warning: Color(0xFFDFA000),
  );

  static const everforestDark = AppPaletteColors(
    primary: Color(0xFFA7C080),
    onPrimary: Color(0xFF26311E),
    primaryContainer: Color(0xFF425047),
    onPrimaryContainer: Color(0xFFD3C6AA),
    secondary: Color(0xFF7FBBB3),
    tertiary: Color(0xFFDBBC7F),
    background: Color(0xFF232A2E),
    surface: Color(0xFF2D353B),
    card: Color(0xFF343F44),
    container: Color(0xFF3D484D),
    containerHigh: Color(0xFF475258),
    text: Color(0xFFD3C6AA),
    muted: Color(0xFF9DA9A0),
    border: Color(0xFF56635F),
    error: Color(0xFFE67E80),
    success: Color(0xFFA7C080),
    warning: Color(0xFFDBBC7F),
  );
}
