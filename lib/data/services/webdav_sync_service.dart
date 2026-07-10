import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../models/models.dart';
import 'note_backup_service.dart';

class WebDavConfig {
  const WebDavConfig._({
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.remoteDirectory,
  });

  factory WebDavConfig.validated({
    required String serverUrl,
    required String username,
    required String password,
    String remoteDirectory = '/DailyNotes',
  }) {
    final normalizedUrl = serverUrl.trim();
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('请输入有效的 HTTP(S) WebDAV 地址。');
    }
    if (username.trim().isEmpty) {
      throw const FormatException('请输入 WebDAV 用户名。');
    }
    if (password.isEmpty) {
      throw const FormatException('请输入 WebDAV 密码或应用密码。');
    }

    final segments = remoteDirectory
        .trim()
        .replaceAll('\\', '/')
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty ||
        segments.any(
          (segment) =>
              segment == '.' ||
              segment == '..' ||
              segment.contains(RegExp(r'[?#]')),
        )) {
      throw const FormatException('请输入有效的 WebDAV 远端目录。');
    }

    return WebDavConfig._(
      serverUrl: normalizedUrl.endsWith('/')
          ? normalizedUrl
          : '$normalizedUrl/',
      username: username.trim(),
      password: password,
      remoteDirectory: '/${segments.join('/')}',
    );
  }

  final String serverUrl;
  final String username;
  final String password;
  final String remoteDirectory;

  String get remoteFilePath => '$remoteDirectory/daily-notes-backup.json';
}

class WebDavSyncResult {
  const WebDavSyncResult({
    required this.notes,
    required this.remoteWasMissing,
    required this.remoteChangesApplied,
  });

  final List<Note> notes;
  final bool remoteWasMissing;
  final int remoteChangesApplied;
}

class WebDavSyncException implements Exception {
  const WebDavSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class WebDavRemote {
  Future<void> ping();

  Future<void> ensureDirectory(String path);

  Future<List<int>?> readOrNull(String path);

  Future<void> writeAtomic(String path, Uint8List data);
}

typedef WebDavRemoteFactory = WebDavRemote Function(WebDavConfig config);

class WebDavSyncService {
  WebDavSyncService({
    WebDavRemoteFactory? remoteFactory,
    NoteBackupService backupService = const NoteBackupService(),
  }) : _remoteFactory = remoteFactory ?? _createRemote,
       _backupService = backupService;

  final WebDavRemoteFactory _remoteFactory;
  final NoteBackupService _backupService;

  Future<void> testConnection(WebDavConfig config) async {
    try {
      final remote = _remoteFactory(config);
      await remote.ping();
      await remote.ensureDirectory(config.remoteDirectory);
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<void> upload(WebDavConfig config, Iterable<Note> notes) async {
    try {
      final remote = _remoteFactory(config);
      await remote.ping();
      await remote.ensureDirectory(config.remoteDirectory);
      await remote.writeAtomic(
        config.remoteFilePath,
        Uint8List.fromList(utf8.encode(_backupService.encode(notes))),
      );
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<NoteBackup?> download(WebDavConfig config) async {
    try {
      final remote = _remoteFactory(config);
      await remote.ping();
      final bytes = await remote.readOrNull(config.remoteFilePath);
      return bytes == null ? null : _backupService.decode(utf8.decode(bytes));
    } catch (error) {
      _throwFriendly(error);
    }
  }

  Future<WebDavSyncResult> synchronize(
    WebDavConfig config,
    Iterable<Note> localNotes,
  ) async {
    try {
      final remote = _remoteFactory(config);
      await remote.ping();
      await remote.ensureDirectory(config.remoteDirectory);
      final remoteBytes = await remote.readOrNull(config.remoteFilePath);
      final remoteBackup = remoteBytes == null
          ? null
          : _backupService.decode(utf8.decode(remoteBytes));
      final merged = mergeNewest(localNotes, remoteBackup?.notes ?? const []);
      final localById = {for (final note in localNotes) note.id: note};
      final remoteChanges = merged.where((note) {
        final local = localById[note.id];
        return local == null || note.updatedAt.isAfter(local.updatedAt);
      }).length;

      await remote.writeAtomic(
        config.remoteFilePath,
        Uint8List.fromList(utf8.encode(_backupService.encode(merged))),
      );
      return WebDavSyncResult(
        notes: merged,
        remoteWasMissing: remoteBackup == null,
        remoteChangesApplied: remoteChanges,
      );
    } catch (error) {
      _throwFriendly(error);
    }
  }

  static List<Note> mergeNewest(
    Iterable<Note> localNotes,
    Iterable<Note> remoteNotes,
  ) {
    final notesById = <String, Note>{
      for (final note in localNotes) note.id: note,
    };
    for (final remote in remoteNotes) {
      final local = notesById[remote.id];
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        notesById[remote.id] = remote;
      }
    }
    final merged = notesById.values.toList()
      ..sort((first, second) => second.updatedAt.compareTo(first.updatedAt));
    return List.unmodifiable(merged);
  }

  static WebDavRemote _createRemote(WebDavConfig config) {
    return _WebDavClientRemote(config);
  }

  Never _throwFriendly(Object error) {
    if (error is WebDavSyncException) {
      throw error;
    }
    if (error is FormatException) {
      throw WebDavSyncException(error.message.toString());
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        throw const WebDavSyncException('认证失败，请检查用户名和密码。');
      }
      if (status == 404) {
        throw const WebDavSyncException('WebDAV 地址或路径不存在。');
      }
      if (status != null) {
        throw WebDavSyncException('WebDAV 服务器返回 HTTP $status。');
      }
    }
    throw const WebDavSyncException('无法连接 WebDAV 服务器。Web 端还需服务器允许 CORS。');
  }
}

class _WebDavClientRemote implements WebDavRemote {
  _WebDavClientRemote(WebDavConfig config)
    : _client = webdav.newClient(
        config.serverUrl,
        user: config.username,
        password: config.password,
      ) {
    _client.setConnectTimeout(12000);
    _client.setSendTimeout(30000);
    _client.setReceiveTimeout(30000);
    _client.setHeaders({'accept-charset': 'utf-8'});
  }

  final webdav.Client _client;

  @override
  Future<void> ensureDirectory(String path) => _client.mkdirAll(path);

  @override
  Future<void> ping() => _client.ping();

  @override
  Future<List<int>?> readOrNull(String path) async {
    try {
      return await _client.read(path);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> writeAtomic(String path, Uint8List data) async {
    final temporaryPath = '$path.uploading';
    await _client.write(temporaryPath, data);
    try {
      await _client.rename(temporaryPath, path, true);
    } catch (_) {
      await _client.write(path, data);
      try {
        await _client.remove(temporaryPath);
      } catch (_) {
        // A stale temporary file is harmless and can be overwritten next time.
      }
    }
  }
}
