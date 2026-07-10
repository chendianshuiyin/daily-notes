# Changelog

## 1.1.0 - 2026-07-11

### Added

- Dedicated `#tag` editing with inline hashtag extraction and backup compatibility.
- Tag counts and one-tap tag filtering across current and archived notes.
- Short voice dictation in the note editor on Android, Web, and Windows.

### Changed

- Simplified the activity heatmap header and kept its date range on one line.
- Made tag filter colors explicit for reliable light and dark rendering.
- Bumped app version to `1.1.0+5`.

### Verified

- `flutter analyze` and 23 unit/widget tests
- Android voice permission, unavailable/no-speech feedback, tag save, and tag filtering
- Android, Web, and Windows release builds

## 1.0.3 - 2026-07-10

### Added

- GitHub-style activity heatmap with responsive 16, 28, and 52 week views.
- Up to four compressed image attachments per note with preview and removal.
- JSON backup and merge restore from the system clipboard.
- History filters, tag extraction, image thumbnails, and persistent search.

### Changed

- Migrated note storage to Hive CE with one-time `SharedPreferences` migration.
- Redesigned Home, Editor, History, and Settings for compact light and dark layouts.
- Replaced runtime Google Fonts with platform fonts for immediate offline rendering.
- Bumped app version to `1.0.3+4`.

### Verified

- `flutter analyze` and 21 unit/widget tests
- Android, Web, and Windows release builds
- Android image picking, save, cold restart persistence, and responsive visual checks

## 1.0.2 - 2026-07-10

### Added

- Custom Daily Notes app icons for Android, Web, Windows, Linux, iOS, and macOS.
- Confirmation before discarding an unsaved note draft.
- Focused repository and widget tests for persistence and failed saves.

### Changed

- Standardized platform names and identifiers around `Daily Notes` and `com.chendianshuiyin.dailynotes`.
- Kept editor content visible and reported an error when a save cannot be persisted.
- Created a fresh `GoRouter` for each app instance and disposed it with the app lifecycle.
- Bumped app version to `1.0.2+3`.

### Verified

- `flutter analyze`
- `flutter test`
- Android, Web, Windows, and Linux release builds
- Android APK signature, package metadata, installation, launch, and note persistence

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
