import 'package:flutter/foundation.dart';

import '../../data/services/services.dart';
import 'note_provider.dart';

enum WebDavOperation { idle, testing, syncing, uploading, downloading }

class WebDavProvider extends ChangeNotifier {
  WebDavProvider({
    WebDavConfigStore? configStore,
    WebDavSyncService? syncService,
  }) : _configStore = configStore ?? SecureWebDavConfigStore(),
       _syncService = syncService ?? WebDavSyncService();

  final WebDavConfigStore _configStore;
  final WebDavSyncService _syncService;

  WebDavConfig? _config;
  DateTime? _lastSyncAt;
  WebDavOperation _operation = WebDavOperation.idle;
  String? _message;
  String? _errorMessage;

  WebDavConfig? get config => _config;
  DateTime? get lastSyncAt => _lastSyncAt;
  WebDavOperation get operation => _operation;
  bool get isConfigured => _config != null;
  bool get isBusy => _operation != WebDavOperation.idle;
  String? get message => _message;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    try {
      _config = await _configStore.load();
      _lastSyncAt = await _configStore.loadLastSyncAt();
      _errorMessage = null;
    } catch (error) {
      debugPrint('Failed to load WebDAV settings: ${error.runtimeType}');
      _config = null;
      _errorMessage = '无法读取 WebDAV 加密配置';
    }
    notifyListeners();
  }

  Future<void> testConnection(WebDavConfig config) async {
    await _run(WebDavOperation.testing, () async {
      await _syncService.testConnection(config);
      _message = 'WebDAV 连接成功';
    });
  }

  Future<void> saveAndTest(WebDavConfig config) async {
    await _run(WebDavOperation.testing, () async {
      await _syncService.testConnection(config);
      await _configStore.save(config);
      _config = config;
      _message = 'WebDAV 配置已保存';
    });
  }

  Future<void> clearConfig() async {
    await _run(WebDavOperation.testing, () async {
      await _configStore.clear();
      _config = null;
      _lastSyncAt = null;
      _message = 'WebDAV 配置已清除';
    });
  }

  Future<WebDavSyncResult> synchronize(NoteProvider noteProvider) async {
    late WebDavSyncResult result;
    await _run(WebDavOperation.syncing, () async {
      result = await _syncService.synchronize(
        _requireConfig(),
        noteProvider.notes,
      );
      await noteProvider.restoreBackup(
        NoteBackup(exportedAt: DateTime.now(), notes: result.notes),
      );
      await _markSynced();
      _message = result.remoteWasMissing
          ? '已创建远端备份，共 ${result.notes.length} 条笔记'
          : '同步完成，合并 ${result.remoteChangesApplied} 条远端更新';
    });
    return result;
  }

  Future<void> upload(NoteProvider noteProvider) async {
    await _run(WebDavOperation.uploading, () async {
      await _syncService.upload(_requireConfig(), noteProvider.notes);
      await _markSynced();
      _message = '已上传 ${noteProvider.notes.length} 条笔记';
    });
  }

  Future<int> download(NoteProvider noteProvider) async {
    var count = 0;
    await _run(WebDavOperation.downloading, () async {
      final backup = await _syncService.download(_requireConfig());
      if (backup == null) {
        throw const WebDavSyncException('远端还没有 Daily Notes 备份。');
      }
      await noteProvider.restoreBackup(backup);
      count = backup.notes.length;
      await _markSynced();
      _message = '已下载并合并 $count 条笔记';
    });
    return count;
  }

  Future<void> _markSynced() async {
    _lastSyncAt = DateTime.now();
    await _configStore.saveLastSyncAt(_lastSyncAt!);
  }

  WebDavConfig _requireConfig() {
    final value = _config;
    if (value == null) {
      throw const WebDavSyncException('请先配置 WebDAV。');
    }
    return value;
  }

  Future<void> _run(
    WebDavOperation operation,
    Future<void> Function() action,
  ) async {
    if (isBusy) {
      throw const WebDavSyncException('另一个 WebDAV 操作正在进行。');
    }
    _operation = operation;
    _message = null;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _errorMessage = error is WebDavSyncException
          ? error.message
          : 'WebDAV 操作失败';
      rethrow;
    } finally {
      _operation = WebDavOperation.idle;
      notifyListeners();
    }
  }
}
