# Daily Notes v1.0.0

## Summary

Daily Notes v1.0.0 is the first usable MVP release. It supports creating, editing, listing, searching, archiving, and deleting local daily notes.

## Highlights

- Local note persistence with `SharedPreferences`.
- Home dashboard with today's notes, recent notes, and note counts.
- Editor with title/content fields, save validation, edit existing note, archive, and delete.
- History page with search, refresh, edit navigation, archive, and delete.
- Android application ID: `com.chendianshuiyin.dailynotes`.
- Android release APK signed with the local release certificate.

## Release Assets

- `daily-notes-v1.0.0-android-release.apk`
  - SHA-256: `CE24E5AE8EE1AFB495AEB83987F96A901748A38F26DF0434DB174E711A499943`
- `daily-notes-v1.0.0-windows-x64.zip`
  - SHA-256: `1521801DCFCE7A83913650CC34E0759F33D65FD7C3CBB82DC511BA6C014D1C9E`
- `daily-notes-v1.0.0-web.zip`
  - SHA-256: `0B2F63D01D85A7231B22AF4C315A7811E6F975E30D10C55FE40FDDF7C0F53419`

## Verification

- `flutter analyze`: passed.
- `flutter test`: passed, 2 tests.
- `flutter build apk --release`: passed.
- `flutter build web --release`: passed.
- `flutter build windows --release`: passed.
- Android emulator install smoke test passed on `Medium_Phone_API_36.1`.

## Known Limits

- iOS/macOS builds were not produced on this Windows host.
- Linux build was not produced on this Windows host.
- Real-phone USB install check is still recommended in addition to the passing emulator smoke test.
