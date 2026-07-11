import 'package:flutter/foundation.dart';

import '../../data/services/services.dart';

class AiProvider extends ChangeNotifier {
  AiProvider({AiConfigStore? configStore})
    : _configStore = configStore ?? SecureAiConfigStore();

  final AiConfigStore _configStore;
  AiConfig? _config;
  bool _isBusy = false;
  String? _errorMessage;

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
