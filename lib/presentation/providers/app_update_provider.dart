import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/services.dart';

class AppUpdateProvider extends ChangeNotifier {
  AppUpdateProvider({AppUpdateClient? client})
    : _client = client ?? AppUpdateService();

  static const _autoCheckKey = 'daily_notes.auto_check_updates';
  static const _lastCheckKey = 'daily_notes.last_update_check';
  static const _checkInterval = Duration(hours: 24);

  final AppUpdateClient _client;

  bool _autoCheck = true;
  bool _isChecking = false;
  String _currentVersion = '1.2.0';
  String? _errorMessage;
  DateTime? _lastCheckAt;
  AppReleaseInfo? _availableRelease;

  bool get autoCheck => _autoCheck;
  bool get isChecking => _isChecking;
  String get currentVersion => _currentVersion;
  String? get errorMessage => _errorMessage;
  DateTime? get lastCheckAt => _lastCheckAt;
  AppReleaseInfo? get availableRelease => _availableRelease;

  bool get shouldAutoCheck {
    if (!_autoCheck || _isChecking) return false;
    final last = _lastCheckAt;
    return last == null || DateTime.now().difference(last) >= _checkInterval;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _autoCheck = prefs.getBool(_autoCheckKey) ?? true;
    _lastCheckAt = DateTime.tryParse(prefs.getString(_lastCheckKey) ?? '');
    notifyListeners();
  }

  Future<void> setAutoCheck(bool value) async {
    if (_autoCheck == value) return;
    _autoCheck = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCheckKey, value);
  }

  Future<AppReleaseInfo?> checkForUpdates() async {
    if (_isChecking) return _availableRelease;
    _isChecking = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _client.currentVersion(),
        _client.fetchLatest(),
      ]);
      _currentVersion = results[0] as String;
      final release = results[1] as AppReleaseInfo;
      _availableRelease =
          AppReleaseInfo.isNewer(release.version, _currentVersion)
          ? release
          : null;
      return _availableRelease;
    } catch (error, stackTrace) {
      debugPrint('Failed to check app update: $error\n$stackTrace');
      _errorMessage = '检查更新失败，请稍后重试';
      return null;
    } finally {
      _lastCheckAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCheckKey, _lastCheckAt!.toIso8601String());
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<bool> openAvailableUpdate() async {
    final release = _availableRelease;
    if (release == null) return false;
    try {
      return await _client.openUpdate(release);
    } catch (error, stackTrace) {
      debugPrint('Failed to open app update: $error\n$stackTrace');
      _errorMessage = '无法打开更新下载地址';
      notifyListeners();
      return false;
    }
  }
}
