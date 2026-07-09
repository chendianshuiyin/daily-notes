# Daily Notes v1.0.2 Final Release Report

## Summary

Daily Notes v1.0.2 is published on GitHub with Android, Windows, Linux, and Web packages. The release provides a complete local note loop: create, edit, save, list, search, archive, delete, and persisted theme selection. This version also protects unsaved drafts, reports persistence failures without clearing editor content, and adds branded platform icons.

Release URL: https://github.com/chendianshuiyin/daily-notes/releases/tag/v1.0.2

## Published Assets

| Asset | Size | SHA-256 |
| --- | ---: | --- |
| `daily-notes-v1.0.2-android-release.apk` | 49,402,296 bytes | `97098D8C5476F46F2064E98A6137A25DB47FA904171CD2C6E0E61C2D4011F047` |
| `daily-notes-v1.0.2-windows-x64.zip` | 11,861,254 bytes | `1A29E0BA43F213495568C8B25DD7D3390EF94E77DBE37CB60493E64EBF45E11B` |
| `daily-notes-v1.0.2-linux-x64.zip` | 10,399,939 bytes | `ED8660A4ABBF29E6EAC3F6974397D0F942DACEA3D5D3F87281DEEA9893AF29C5` |
| `daily-notes-v1.0.2-linux-x64.zip.sha256` | 99 bytes | `7D0E0DBE0C75E6ED3665BB5B2596C66E9D58762015B661DAFE1BD9E3DA971180` |
| `daily-notes-v1.0.2-web.zip` | 10,857,015 bytes | `92FC877A5C231DC3773B1DAA8BA836E775C2A8AED1A5D2588DE2415247AB0176` |

GitHub asset digests match all locally built assets. The Android APK and Linux ZIP were downloaded from the published Release and independently re-hashed successfully.

## Android Verification

- Package: `com.chendianshuiyin.dailynotes`
- Version: `1.0.2` (`versionCode=3`)
- Min SDK: `24`; target SDK: `36`
- App label: `Daily Notes`
- Signer: `CN=Daily Notes, OU=Release, O=chendianshuiyin, L=Shanghai, ST=Shanghai, C=CN`
- Signer SHA-256: `750fe89e137d070f7620dfe198486f4dae01b5087833995e1b651bccedc163d5`

The release APK passed `adb install -r` over v1.0.1, preserving an existing note. A new `v1.0.2 smoke note` was created and saved, then remained visible after a forced stop and cold launch. `uiautomator dump` confirmed two persisted notes, and screenshot evidence is stored at `docs/pictures/android-v1.0.2-home.png`.

## Build and Test Evidence

- `dart format lib test`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 6 tests.
- Android, Web, and Windows release builds: passed locally.
- Linux release build/upload: passed in GitHub Actions run `29043858648`.
- `apksigner verify --print-certs` and `aapt dump badging`: passed.

## Platform Coverage

- Android: signed APK published and emulator installation/use verified.
- Windows: x64 release bundle published.
- Linux: x64 release bundle built on Ubuntu and published by GitHub Actions.
- Web: static release bundle published for deployment to any static host.
- iOS/macOS: identifiers, display names, and icons are prepared; signed packages require macOS and Apple signing credentials.

## Remaining Operational Checks

- A physical Android phone was not connected during this run, so hardware installation remains unverified even though emulator installation and use passed.
- Notes are local to each installation; sync, import/export, and cloud backup are not part of v1.0.2.
- The private Android release keystore and `android/key.properties` must be backed up securely outside the repository.
