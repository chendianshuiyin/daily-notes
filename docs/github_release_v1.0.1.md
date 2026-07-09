# Daily Notes v1.0.1

## Summary

Daily Notes v1.0.1 is the first release-ready MVP build. It supports creating, editing, listing, searching, archiving, and deleting local daily notes, plus persisted theme mode settings.

## Highlights

- Local note persistence with `SharedPreferences`.
- Home dashboard with today's notes, recent notes, and note counts.
- Editor with title/content fields, save validation, edit existing note, archive, and delete.
- History page with search, refresh, edit navigation, archive, and delete.
- Settings page with persisted system, light, and dark theme modes.
- Android application ID: `com.chendianshuiyin.dailynotes`.
- Android release APK signed with the local release certificate.

## Release Assets

- `daily-notes-v1.0.1-android-release.apk`
  - SHA-256: `312388469314F86C46B814E1EFCC4F3D32390F2CE9E8678B057E4648C63CEED9`
- `daily-notes-v1.0.1-windows-x64.zip`
  - SHA-256: `D9DDC461D75A927BE7C2970B796E61FC8258BF8EFAD4AC7707277D35769BC361`
- `daily-notes-v1.0.1-web.zip`
  - SHA-256: `54928E0D0BF971369EE39D317FE65C4794846F2A05DB6306837A55B4E86975D8`

## Verification

- `flutter analyze`: passed.
- `flutter test`: passed, 3 tests.
- `flutter build apk --release`: passed.
- `flutter build web --release`: passed.
- `flutter build windows --release`: passed.
- `apksigner verify --print-certs`: passed.
- Android emulator upgrade/install smoke test passed on `Medium_Phone_API_36.1`; `versionName=1.0.1`, `versionCode=2`.

## Known Limits

- iOS/macOS builds require a macOS signing environment.
- Linux build requires a Linux host/toolchain.
- Real-phone USB install check is still recommended in addition to emulator smoke testing.
