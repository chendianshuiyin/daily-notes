# Daily Notes Release Status Report

## Current Status

Daily Notes v1.0.2 is published as a usable local-first release. Android, Windows, Linux, and Web packages are available from GitHub. The signed Android APK passed upgrade installation, cold launch, note creation, save, and restart persistence checks on Android 36 emulator `Medium_Phone_API_36.1`.

Release URL: https://github.com/chendianshuiyin/daily-notes/releases/tag/v1.0.2

## Completed Evidence

- Core note workflow: create, edit, list, search, archive, and delete.
- Local note and theme persistence through `SharedPreferences`.
- Unsaved-draft confirmation and visible persistence failure handling.
- Branded application icons and normalized platform metadata.
- Android release signing with package `com.chendianshuiyin.dailynotes`.
- Six passing unit/widget tests plus analyzer and release build gates.
- Published Android, Windows, Web, and GitHub Actions-built Linux assets.

## Published Packages

| Asset | Size | SHA-256 |
| --- | ---: | --- |
| `daily-notes-v1.0.2-android-release.apk` | 49,402,296 bytes | `97098D8C5476F46F2064E98A6137A25DB47FA904171CD2C6E0E61C2D4011F047` |
| `daily-notes-v1.0.2-windows-x64.zip` | 11,861,254 bytes | `1A29E0BA43F213495568C8B25DD7D3390EF94E77DBE37CB60493E64EBF45E11B` |
| `daily-notes-v1.0.2-linux-x64.zip` | 10,399,939 bytes | `ED8660A4ABBF29E6EAC3F6974397D0F942DACEA3D5D3F87281DEEA9893AF29C5` |
| `daily-notes-v1.0.2-web.zip` | 10,857,015 bytes | `92FC877A5C231DC3773B1DAA8BA836E775C2A8AED1A5D2588DE2415247AB0176` |

GitHub reports all assets as uploaded. Downloaded Android and Linux assets were independently hashed and matched the published digests.

## Remaining Operational Work

- Run the published APK on a physical Android phone when one is connected; current installation/use evidence is from an Android emulator.
- Back up the release keystore and `android/key.properties` securely outside Git.

The current release and maintenance scope is Android, Windows, Linux, and Web. iOS and macOS are deferred.
