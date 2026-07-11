import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_color_palette.dart';

enum HeatmapRange {
  threeMonths(12, '3 个月'),
  sixMonths(26, '6 个月'),
  oneYear(52, '1 年');

  const HeatmapRange(this.weeks, this.label);

  final int weeks;
  final String label;
}

class AppSettingsProvider extends ChangeNotifier {
  static const String _themeModeKey = 'daily_notes.theme_mode';
  static const String _colorPaletteKey = 'daily_notes.color_palette';
  static const String _heatmapRangeKey = 'daily_notes.heatmap_range';

  ThemeMode _themeMode = ThemeMode.system;
  AppColorPalette _colorPalette = AppColorPalette.daybreak;
  HeatmapRange _heatmapRange = HeatmapRange.threeMonths;
  bool _isLoading = false;

  ThemeMode get themeMode => _themeMode;
  AppColorPalette get colorPalette => _colorPalette;
  HeatmapRange get heatmapRange => _heatmapRange;

  bool get isLoading => _isLoading;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _themeMode = _themeModeFromValue(prefs.getString(_themeModeKey));
    _colorPalette = _colorPaletteFromValue(prefs.getString(_colorPaletteKey));
    _heatmapRange = _heatmapRangeFromValue(prefs.getString(_heatmapRangeKey));

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (_themeMode == themeMode) {
      return;
    }

    _themeMode = themeMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _themeModeToValue(themeMode));
  }

  Future<void> setColorPalette(AppColorPalette palette) async {
    if (_colorPalette == palette) {
      return;
    }

    _colorPalette = palette;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_colorPaletteKey, palette.name);
  }

  Future<void> setHeatmapRange(HeatmapRange range) async {
    if (_heatmapRange == range) {
      return;
    }
    _heatmapRange = range;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_heatmapRangeKey, range.name);
  }

  String themeModeLabel(ThemeMode themeMode) {
    return switch (themeMode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
  }

  ThemeMode _themeModeFromValue(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  String _themeModeToValue(ThemeMode themeMode) {
    return switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  HeatmapRange _heatmapRangeFromValue(String? value) {
    return HeatmapRange.values.firstWhere(
      (range) => range.name == value,
      orElse: () => HeatmapRange.threeMonths,
    );
  }

  AppColorPalette _colorPaletteFromValue(String? value) {
    return AppColorPalette.values.firstWhere(
      (palette) => palette.name == value,
      orElse: () => AppColorPalette.daybreak,
    );
  }
}
