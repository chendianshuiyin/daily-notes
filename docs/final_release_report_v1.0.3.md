# Daily Notes v1.0.3 Final Release Report

## Summary

Daily Notes v1.0.3 is a local-first journal release for Android, Windows, Linux, and Web. It adds compressed image notes, a GitHub-style activity heatmap, Hive CE storage, JSON backup/restore, richer history search and filters, and a redesigned responsive light/dark interface.

## Release Assets

| Asset | Size | SHA-256 |
| --- | ---: | --- |
| `daily-notes-v1.0.3-android-release.apk` | 53,679,352 bytes | `D38AF67E1C2B325A1542584DB85A11C2C1D709036E24FF938E7209BD4E9E51B9` |
| `daily-notes-v1.0.3-windows-x64.zip` | 12,334,289 bytes | `EF159C3791382D3FE882046507035164B02609C797BAF97E155818B9199CBC30` |
| `daily-notes-v1.0.3-web.zip` | 11,040,718 bytes | `49A47E85BF6499EEEDBB053EA23A9C401943881DAFDAFA5CEF1FD5B238F1901D` |

Linux x64 asset size and checksum are appended after the tagged GitHub Actions build completes.

## Android Evidence

- Package: `com.chendianshuiyin.dailynotes`
- Version: `1.0.3` (`versionCode=4`)
- Min SDK: `24`; target SDK: `36`
- Signer: `CN=Daily Notes, OU=Release, O=chendianshuiyin, L=Shanghai, ST=Shanghai, C=CN`
- Signer SHA-256: `750fe89e137d070f7620dfe198486f4dae01b5087833995e1b651bccedc163d5`

The final APK passed upgrade installation and retained the existing image note. On Android 36 emulator `Medium_Phone_API_36.1`, the system image picker selected a PNG, the editor displayed its compressed attachment, and the saved note remained after a forced stop and cold launch. Home heatmap counts, history filters, image thumbnails, backup controls, and light/dark themes were visually inspected at 1080x2400.

## Build and Test Evidence

- `dart format lib test`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 21 tests; the full suite was repeated after eliminating date-sensitive test behavior.
- Android, Web, and Windows release builds: passed locally.
- `apksigner verify --print-certs` and `aapt dump badging`: passed.
- Linux release build and publication are performed by GitHub Actions from tag `v1.0.3`.

## Data Compatibility

Production storage now uses Hive CE. On first start, existing v1.0.2 notes are copied from `SharedPreferences`; the legacy value is retained as a fallback. Backups include title, body, timestamps, archive state, and base64 image data. Restore validates the schema and merges notes by ID.

## Scope and Residual Risk

iOS and macOS are intentionally deferred. A physical Android phone was not connected, so hardware installation remains unverified even though signed APK installation and complete use passed on the Android emulator. Notes remain device-local unless users export a JSON backup.
