import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'webdav_sync_service.dart';

abstract class WebDavConfigStore {
  Future<WebDavConfig?> load();

  Future<void> save(WebDavConfig config);

  Future<void> clear();

  Future<DateTime?> loadLastSyncAt();

  Future<void> saveLastSyncAt(DateTime value);
}

class SecureWebDavConfigStore implements WebDavConfigStore {
  SecureWebDavConfigStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _serverKey = 'webdav_server_url';
  static const _usernameKey = 'webdav_username';
  static const _passwordKey = 'webdav_password';
  static const _directoryKey = 'webdav_remote_directory';
  static const _lastSyncKey = 'webdav_last_sync_at';

  final FlutterSecureStorage _storage;

  @override
  Future<WebDavConfig?> load() async {
    final values = await Future.wait([
      _storage.read(key: _serverKey),
      _storage.read(key: _usernameKey),
      _storage.read(key: _passwordKey),
      _storage.read(key: _directoryKey),
    ]);
    if (values.every((value) => value == null || value.isEmpty)) {
      return null;
    }
    return WebDavConfig.validated(
      serverUrl: values[0] ?? '',
      username: values[1] ?? '',
      password: values[2] ?? '',
      remoteDirectory: values[3] ?? '/DailyNotes',
    );
  }

  @override
  Future<void> save(WebDavConfig config) async {
    await Future.wait([
      _storage.write(key: _serverKey, value: config.serverUrl),
      _storage.write(key: _usernameKey, value: config.username),
      _storage.write(key: _passwordKey, value: config.password),
      _storage.write(key: _directoryKey, value: config.remoteDirectory),
    ]);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _serverKey),
      _storage.delete(key: _usernameKey),
      _storage.delete(key: _passwordKey),
      _storage.delete(key: _directoryKey),
      _storage.delete(key: _lastSyncKey),
    ]);
  }

  @override
  Future<DateTime?> loadLastSyncAt() async {
    final value = await _storage.read(key: _lastSyncKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  @override
  Future<void> saveLastSyncAt(DateTime value) {
    return _storage.write(key: _lastSyncKey, value: value.toIso8601String());
  }
}
