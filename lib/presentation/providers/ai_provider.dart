import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../data/services/services.dart';

class AiProvider extends ChangeNotifier {
  AiProvider({AiConfigStore? configStore, AiRemoteClient? remoteClient})
    : _configStore = configStore ?? SecureAiConfigStore(),
      _remoteClient = remoteClient ?? AiRemoteClient();

  final AiConfigStore _configStore;
  final AiRemoteClient _remoteClient;
  AiConfig? _config;
  bool _isBusy = false;
  String? _errorMessage;
  CancelToken? _cancelToken;

  AiConfig? get config => _config;
  bool get isConfigured => _config != null;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    try {
      _config = await _configStore.load();
      _errorMessage = null;
    } catch (error) {
      debugPrint('Failed to load AI settings: ${error.runtimeType}');
      _config = null;
      _errorMessage = '无法读取 AI 加密配置';
    }
    notifyListeners();
  }

  Future<void> save(AiConfig config) async {
    await _run(() async {
      await _configStore.save(config);
      _config = config;
    });
  }

  Future<void> clear() async {
    await _run(() async {
      await _configStore.clear();
      _config = null;
    });
  }

  Future<List<AiTagSuggestion>> suggestTags(AiNoteContext context) async {
    final currentConfig = _config;
    if (currentConfig == null) {
      throw const AiRemoteException(AiRemoteError.authentication, '请先配置 AI 服务');
    }
    if (_isBusy) {
      throw const AiRemoteException(AiRemoteError.network, '另一个 AI 操作正在进行');
    }
    _isBusy = true;
    _errorMessage = null;
    _cancelToken = CancelToken();
    notifyListeners();
    try {
      return await _remoteClient.suggestTags(
        currentConfig,
        context,
        cancelToken: _cancelToken,
      );
    } on AiRemoteException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } finally {
      _cancelToken = null;
      _isBusy = false;
      notifyListeners();
    }
  }

  void cancel() {
    _cancelToken?.cancel('Cancelled by user');
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _errorMessage = 'AI 配置保存失败';
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
