import 'package:daily_notes/data/services/services.dart';
import 'package:daily_notes/presentation/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists automatic checks and exposes a newer release', () async {
    final client = _FakeUpdateClient();
    final provider = AppUpdateProvider(client: client);
    await provider.load();

    expect(provider.autoCheck, isTrue);
    expect(provider.shouldAutoCheck, isTrue);

    final release = await provider.checkForUpdates();
    expect(release?.version, '1.3.0');
    expect(provider.currentVersion, '1.2.0');
    expect(provider.shouldAutoCheck, isFalse);
    expect(await provider.openAvailableUpdate(), isTrue);
    expect(client.openCalls, 1);

    await provider.setAutoCheck(false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('daily_notes.auto_check_updates'), isFalse);
  });
}

class _FakeUpdateClient implements AppUpdateClient {
  int openCalls = 0;

  @override
  Future<String> currentVersion() async => '1.2.0';

  @override
  Future<AppReleaseInfo> fetchLatest() async {
    return AppReleaseInfo(
      version: '1.3.0',
      pageUri: Uri.parse(
        'https://github.com/chendianshuiyin/daily-notes/releases/tag/v1.3.0',
      ),
      publishedAt: DateTime.utc(2026, 7, 12),
      notes: 'Changes',
      assets: const [],
    );
  }

  @override
  Future<bool> openUpdate(AppReleaseInfo release) async {
    openCalls++;
    return true;
  }
}
