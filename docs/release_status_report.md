# Daily Notes Release Status Report

## Current Status

Daily Notes v1.0.3 is the current release candidate for Android, Windows, Linux, and Web. Core functionality, modern responsive layouts, local persistence, backup/restore, and image attachments are complete. Local release assets for Android, Windows, and Web have passed build and checksum verification; Linux is produced on GitHub Actions after tagging.

## Completed Evidence

- Hive CE note storage with one-time migration from the v1.0.2 `SharedPreferences` format.
- Text and compressed image notes, full-screen preview, history thumbnails, tags, archive, and delete.
- Responsive 16/28/52 week activity heatmap with per-day note selection.
- JSON backup and merge restore, including image data.
- Immediate offline typography, light/dark themes, unsaved-draft protection, and visible persistence errors.
- Signed Android package `com.chendianshuiyin.dailynotes`, version `1.0.3` (`versionCode=4`).
- 21 passing unit/widget tests, analyzer gate, and Android/Web/Windows release builds.

## Local Packages

| Asset | Size | SHA-256 |
| --- | ---: | --- |
| `daily-notes-v1.0.3-android-release.apk` | 53,679,352 bytes | `D38AF67E1C2B325A1542584DB85A11C2C1D709036E24FF938E7209BD4E9E51B9` |
| `daily-notes-v1.0.3-windows-x64.zip` | 12,334,289 bytes | `EF159C3791382D3FE882046507035164B02609C797BAF97E155818B9199CBC30` |
| `daily-notes-v1.0.3-web.zip` | 11,040,718 bytes | `49A47E85BF6499EEEDBB053EA23A9C401943881DAFDAFA5CEF1FD5B238F1901D` |

## Android Verification

The final signed APK upgraded over the previous emulator installation and preserved its image note. Android 36 AVD `Medium_Phone_API_36.1` verified the native image picker, compressed attachment display, save, forced-stop relaunch, Hive persistence, heatmap counts, history filters, and light/dark themes. APK signature and package metadata checks passed.

## Remaining Operational Work

- Publish the v1.0.3 GitHub Release and attach the Linux Actions artifact.
- Run the published APK on a physical Android phone when one is connected.
- Keep the private release keystore and `android/key.properties` backed up securely outside Git.

iOS and macOS remain outside the active release scope.
