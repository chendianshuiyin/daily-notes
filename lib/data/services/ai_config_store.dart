import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiConfig {
  const AiConfig({
    required this.endpoint,
    required this.model,
    required this.apiKey,
  });

  final String endpoint;
  final String model;
  final String apiKey;

  factory AiConfig.validated({
    required String endpoint,
    required String model,
    required String apiKey,
  }) {
    final normalizedEndpoint = endpoint.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalizedEndpoint);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('请输入有效的 HTTP(S) API 地址');
    }
    final isLocal = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (uri.scheme != 'https' && !isLocal) {
      throw const FormatException('远端 AI 地址必须使用 HTTPS');
    }
    final normalizedModel = model.trim();
    if (normalizedModel.isEmpty) {
      throw const FormatException('请输入模型名称');
    }
    return AiConfig(
      endpoint: normalizedEndpoint,
      model: normalizedModel,
      apiKey: apiKey.trim(),
    );
  }
}

abstract class AiConfigStore {
  Future<AiConfig?> load();

  Future<void> save(AiConfig config);

  Future<void> clear();
}

class SecureAiConfigStore implements AiConfigStore {
  SecureAiConfigStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _endpointKey = 'ai_endpoint';
  static const _modelKey = 'ai_model';
  static const _apiKey = 'ai_api_key';

  final FlutterSecureStorage _storage;

  @override
  Future<AiConfig?> load() async {
    final values = await Future.wait([
      _storage.read(key: _endpointKey),
      _storage.read(key: _modelKey),
      _storage.read(key: _apiKey),
    ]);
    if (values.every((value) => value == null || value.isEmpty)) {
      return null;
    }
    return AiConfig.validated(
      endpoint: values[0] ?? '',
      model: values[1] ?? '',
      apiKey: values[2] ?? '',
    );
  }

  @override
  Future<void> save(AiConfig config) async {
    await Future.wait([
      _storage.write(key: _endpointKey, value: config.endpoint),
      _storage.write(key: _modelKey, value: config.model),
      _storage.write(key: _apiKey, value: config.apiKey),
    ]);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _endpointKey),
      _storage.delete(key: _modelKey),
      _storage.delete(key: _apiKey),
    ]);
  }
}
