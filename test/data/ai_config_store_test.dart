import 'package:daily_notes/data/services/services.dart';
import 'package:daily_notes/presentation/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes secure OpenAI-compatible configuration', () {
    final config = AiConfig.validated(
      endpoint: ' https://example.com/v1/// ',
      model: ' model-mini ',
      apiKey: ' secret ',
    );

    expect(config.endpoint, 'https://example.com/v1');
    expect(config.model, 'model-mini');
    expect(config.apiKey, 'secret');
  });

  test('allows local HTTP but rejects insecure remote endpoints', () {
    expect(
      AiConfig.validated(
        endpoint: 'http://127.0.0.1:11434/v1',
        model: 'local',
        apiKey: '',
      ).endpoint,
      startsWith('http://127.0.0.1'),
    );
    expect(
      () => AiConfig.validated(
        endpoint: 'http://example.com/v1',
        model: 'remote',
        apiKey: 'key',
      ),
      throwsFormatException,
    );
  });

  test('provider saves and deletes configuration through its store', () async {
    final store = _MemoryAiConfigStore();
    final provider = AiProvider(configStore: store);
    final config = AiConfig.validated(
      endpoint: 'https://example.com/v1',
      model: 'model-mini',
      apiKey: 'secret',
    );

    await provider.save(config);
    expect(provider.isConfigured, isTrue);
    expect(store.value, same(config));

    await provider.clear();
    expect(provider.isConfigured, isFalse);
    expect(store.value, isNull);
  });
}

class _MemoryAiConfigStore implements AiConfigStore {
  AiConfig? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AiConfig?> load() async => value;

  @override
  Future<void> save(AiConfig config) async => value = config;
}
