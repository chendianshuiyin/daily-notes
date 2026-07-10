# Daily Notes Release Status Report

## Current Status

Daily Notes v1.1.0 is published for Android, Windows, Linux, and Web. Core local-first note workflows are complete, including text and image notes, responsive activity history, dedicated tags, archive filters, backup/restore, and short voice dictation on Android, Web, and Windows.

## Completed Evidence

- Hive CE storage with legacy `SharedPreferences` migration and JSON backup/merge restore.
- Up to four compressed images and eight dedicated tags per note, plus inline hashtag extraction.
- Search and filter by title, body, archive state, or tag with visible tag counts.
- Responsive 16/28/52 week activity heatmap without a redundant title.
- Voice dictation with microphone permission and actionable error feedback on supported platforms.
- Signed Android package `com.chendianshuiyin.dailynotes`, version `1.1.0` (`versionCode=5`).
- 23 passing unit/widget tests, analyzer gate, and Android/Web/Windows release builds.

## Local Packages

| Asset | Size | SHA-256 |
| --- | ---: | --- |
| `daily-notes-v1.1.0-android-release.apk` | 53,745,548 bytes | `84B44433730255623F48B85FE7F3BEDB8C2A2DBECBEBDE5C30E7029CE806B5B5` |
| `daily-notes-v1.1.0-windows-x64.zip` | 12,412,484 bytes | `E778A3441B9948B7990B27D004DD09E859C6353144C3CF2CCB88E06638ACC9D4` |
| `daily-notes-v1.1.0-linux-x64.zip` | 11,001,268 bytes | `BB3C55A16BD72CDAB8879B396BD6A18ECE742AAB5C7315125416B52A0C80165D` |
| `daily-notes-v1.1.0-web.zip` | 11,048,399 bytes | `F415C0DDC179F47C41335D5F10AF4C23D62DBC6C369DC3EA5F0220A6AC34115F` |

## Android Verification

The final signed APK upgraded over v1.0.3 and preserved the existing image note. Android 36 AVD `Medium_Phone_API_36.1` verified visible tag chips, tag persistence and filtering, recording permission, no-speech feedback, image display, version metadata, and cold-start data retention. APK signature and package metadata checks passed.

## Remaining Operational Work

- Connect an authorized physical Android phone and run `pwsh -File scripts/verify_android_device.ps1`.
- Keep the private release keystore and `android/key.properties` backed up securely outside Git.

iOS and macOS remain outside the active release scope. Linux supports note workflows but not voice input.
