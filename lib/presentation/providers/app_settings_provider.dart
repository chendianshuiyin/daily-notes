import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  static const String _themeModeKey = 'daily_notes.theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = false;

  ThemeMode get themeMode => _themeMode;

  bool get isLoading => _isLoading;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _themeMode = _themeModeFromValue(prefs.getString(_themeModeKey));

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
}
