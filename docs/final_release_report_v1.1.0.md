# Daily Notes v1.1.0 Final Release Report

## Summary

Daily Notes v1.1.0 is a local-first journal release for Android, Windows, Linux, and Web. It adds dedicated and inline `#tags`, tag-based archive filtering, and short voice dictation on Android, Web, and Windows while retaining text, compressed images, heatmap history, Hive CE storage, and JSON backup/restore.

Release URL: https://github.com/chendianshuiyin/daily-notes/releases/tag/v1.1.0

## Release Assets

| Asset | Size | SHA-256 |
| --- | ---: | --- |
| `daily-notes-v1.1.0-android-release.apk` | 53,745,548 bytes | `84B44433730255623F48B85FE7F3BEDB8C2A2DBECBEBDE5C30E7029CE806B5B5` |
| `daily-notes-v1.1.0-windows-x64.zip` | 12,412,484 bytes | `E778A3441B9948B7990B27D004DD09E859C6353144C3CF2CCB88E06638ACC9D4` |
| `daily-notes-v1.1.0-linux-x64.zip` | 11,001,268 bytes | `BB3C55A16BD72CDAB8879B396BD6A18ECE742AAB5C7315125416B52A0C80165D` |
| `daily-notes-v1.1.0-web.zip` | 11,048,399 bytes | `F415C0DDC179F47C41335D5F10AF4C23D62DBC6C369DC3EA5F0220A6AC34115F` |

## Android Evidence

- Package: `com.chendianshuiyin.dailynotes`
- Version: `1.1.0` (`versionCode=5`)
- Min SDK: `24`; target SDK: `36`
- Signer: `CN=Daily Notes, OU=Release, O=chendianshuiyin, L=Shanghai, ST=Shanghai, C=CN`
- Signer SHA-256: `750fe89e137d070f7620dfe198486f4dae01b5087833995e1b651bccedc163d5`

The final APK passed `adb install -r` over v1.0.3 and retained the existing image note and its new tag. Android 36 emulator `Medium_Phone_API_36.1` verified visible tag chips, tag search/filtering, recording permission, no-speech feedback, image display, and version metadata. Screenshot evidence is stored in `docs/pictures/android-v1.1.0-*.png`.

## Build and Test Evidence

- `dart format lib test`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 23 tests.
- Android, Web, and Windows release builds: passed locally after the final tag-chip visual fix.
- The Web release rendered Home and Editor without console errors; the Windows release executable launched and remained responsive.
- `apksigner verify --print-certs` and `aapt dump badging`: passed.
- Linux release build and publication passed in GitHub Actions run `29111879692`.
- The downloaded Linux ZIP matched both GitHub's asset digest and its `.sha256` sidecar.

## Data Compatibility

Dedicated tags are serialized in Hive and JSON backups. Existing notes without a tag list remain compatible and expose hashtags extracted from title and body. The release keeps the v1.0.3 storage schema, images, archive state, and signing identity.

## Scope and Residual Risk

iOS and macOS are intentionally deferred. Linux remains supported for notes but does not expose voice input. Speech recognition depends on platform services and is designed for short dictation rather than continuous recording.

A physical Android phone was not connected, so hardware installation remains unverified even though signed APK installation and full interaction passed on the Android emulator. `scripts/verify_android_device.ps1` now provides the exact remaining gate: it rejects emulators by default, checks package/version, installs the release APK, writes and saves a smoke note, performs a cold start, verifies persistence, and stores UI XML plus screenshots under `dist/android-device-verification/`. Its emulator-only maintenance mode passed end to end against v1.1.0.
