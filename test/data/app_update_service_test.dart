import 'package:daily_notes/data/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses trusted GitHub release metadata and platform assets', () {
    final release = AppReleaseInfo.fromGitHubJson({
      'tag_name': 'v1.3.0',
      'html_url':
          'https://github.com/chendianshuiyin/daily-notes/releases/tag/v1.3.0',
      'published_at': '2026-07-12T08:00:00Z',
      'body': 'New release notes',
      'assets': [
        {
          'name': 'daily-notes-v1.3.0-android-release.apk',
          'browser_download_url':
              'https://github.com/chendianshuiyin/daily-notes/releases/download/v1.3.0/app.apk',
        },
        {
          'name': 'daily-notes-v1.3.0-windows-x64.zip',
          'browser_download_url':
              'https://github.com/chendianshuiyin/daily-notes/releases/download/v1.3.0/windows.zip',
        },
      ],
    });

    expect(release.version, '1.3.0');
    expect(release.notes, 'New release notes');
    expect(release.assets, hasLength(2));
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      expect(
        release.updateUriForCurrentPlatform().path,
        endsWith('windows.zip'),
      );
    }
  });

  test('compares stable semantic versions and prereleases', () {
    expect(AppReleaseInfo.isNewer('v1.2.1', '1.2.0'), isTrue);
    expect(AppReleaseInfo.isNewer('2.0.0', '1.9.9'), isTrue);
    expect(AppReleaseInfo.isNewer('1.2.0', '1.2.0'), isFalse);
    expect(AppReleaseInfo.isNewer('1.2.0-beta.1', '1.2.0'), isFalse);
  });

  test('rejects untrusted release and asset URLs', () {
    expect(
      () => AppReleaseInfo.fromGitHubJson({
        'tag_name': 'v9.0.0',
        'html_url': 'https://example.com/fake-release',
      }),
      throwsFormatException,
    );
  });
}
