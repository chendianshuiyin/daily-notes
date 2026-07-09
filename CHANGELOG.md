# Changelog

## 1.0.1 - 2026-07-10

### Added

- Persisted theme settings with system, light, and dark modes.
- GitHub Release assets for Android, Windows, and Web.
- Android emulator install/launch verification evidence.
- Repository README, release notes, status report, and release helper script.

### Changed

- Bumped app version to `1.0.1+2`.
- Updated Settings page version display to `1.0.1`.

### Verified

- `flutter analyze`
- `flutter test`
- `flutter build apk --release`
- `flutter build web --release`
- `flutter build windows --release`
- `apksigner verify --print-certs`
- Android emulator install and launch smoke test

## 1.0.0 - 2026-07-10

### Added

- Core note workflow: create, edit, save, list, search, archive, and delete.
- Local note persistence with `SharedPreferences`.
- Android application ID `com.chendianshuiyin.dailynotes`.
- Android release signing configuration.
- Initial release notes and release status documentation.
