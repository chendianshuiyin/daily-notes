# Daily Notes Progress

## 2026-07-10 Core note loop

### Completed

- Added a `Note` model with JSON serialization, timestamps, archive state, display title, and text preview helpers.
- Added `NoteRepository` plus `SharedPreferencesNoteRepository` so notes persist locally across app restarts on supported Flutter targets.
- Added `NoteProvider` to load, save, search, archive, and delete notes through a single app state boundary.
- Wired `DailyNotesApp` with `ChangeNotifierProvider`.
- Replaced placeholder Home UI with summary cards, today notes, recent notes, empty/error states, refresh, and edit navigation.
- Replaced placeholder Editor UI with title/content fields, validation, save, edit existing note, archive, and delete.
- Replaced placeholder History UI with search, refresh, all-note list, edit navigation, archive, and delete.
- Added widget coverage for app startup and the create-save-list note flow.

### Verification

- `dart format lib test`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 2 tests.

### Notes

- This is a pragmatic persistence step for a usable MVP. The previous task plan references Isar and rich-text editing, but those are not yet implemented.
- Android release readiness still requires package metadata review, icon/signing checks, APK build verification, installation testing, GitHub release creation, and a final report.

## 2026-07-10 Android build environment

### Completed

- Diagnosed Android debug build failure caused by malformed local NDK `28.2.13676358`.
- Moved the malformed NDK directory to `28.2.13676358.broken-20260710` and allowed Gradle to reinstall NDK, Build-Tools 35, and CMake 3.22.1.
- Built `build/app/outputs/flutter-apk/app-debug.apk` successfully.
- Added `kotlin.incremental=false` to reduce Kotlin incremental cache failures on Windows cross-drive builds.

### Verification

- `flutter build apk --debug`: produced `app-debug.apk` after SDK repair.

## 2026-07-10 Android app identity

### Completed

- Updated Android `namespace` and `applicationId` to `com.chendianshuiyin.dailynotes`.
- Updated `MainActivity` package to match the release identity.
- Updated Android app label to `Daily Notes`.
- Replaced the default Flutter project description in `pubspec.yaml`.

### Verification

- `flutter build apk --debug`: passed with the new Android application ID.

## 2026-07-10 Android release APK smoke build

### Completed

- Built `build/app/outputs/flutter-apk/app-release.apk`.
- Verified APK signature with `apksigner verify --print-certs`.
- Captured package hashes for traceability.

### Verification

- `flutter build apk --release`: passed, output size 49,195,028 bytes.
- `app-release.apk` SHA-256: `CC6AB70E04D5075C47D56C4D5FE28B0A7BB7B1CC8019FC9101DE497FFD87D257`.
- `app-debug.apk` SHA-256: `E1438F3C567BFEFD00F924E7688EE13F90F4B23901F8E1510F1EABFE9103CE88`.

### Release Blockers

- Resolved by the Android release signing work below.

## 2026-07-10 Android release signing

### Completed

- Added Gradle release signing configuration that reads `android/key.properties`.
- Generated a local private release keystore at `C:\Users\cytus\.daily_notes\release\daily-notes-release.jks`.
- Kept `android/key.properties` ignored by Git; signing secrets are not committed.
- Rebuilt `build/app/outputs/flutter-apk/app-release.apk` with the release certificate.

### Verification

- `flutter build apk --release`: passed, output size 49,195,028 bytes.
- `apksigner verify --print-certs`: passed.
- Release signer DN: `CN=Daily Notes, OU=Release, O=chendianshuiyin, L=Shanghai, ST=Shanghai, C=CN`.
- Release signer SHA-256 digest: `750fe89e137d070f7620dfe198486f4dae01b5087833995e1b651bccedc163d5`.
- Signed `app-release.apk` SHA-256: `CE24E5AE8EE1AFB495AEB83987F96A901748A38F26DF0434DB174E711A499943`.
- `aapt dump badging`: package `com.chendianshuiyin.dailynotes`, version `1.0.0` (`versionCode=1`), min SDK `24`, target SDK `36`, label `Daily Notes`.

### Remaining Release Work

- Publish a GitHub release and attach the signed APK.
- Back up the release keystore and `android/key.properties` securely; losing them prevents publishing compatible upgrades with the same signing identity.

## 2026-07-10 Android install smoke test

### Completed

- Started emulator `Medium_Phone_API_36.1`.
- Installed the signed release APK with `adb install -r`.
- Launched `com.chendianshuiyin.dailynotes/.MainActivity`.
- Created and saved a smoke-test note in the installed app.
- Captured screenshot evidence at `docs/pictures/android-smoke-after-save.png`.

### Verification

- `adb shell pm path com.chendianshuiyin.dailynotes`: returned installed APK path under `/data/app`.
- `adb shell pidof com.chendianshuiyin.dailynotes`: returned PID `3098`.
- `uiautomator dump`: confirmed home UI text, `今日 1`, `全部 1`, and saved note `Android smoke note`.

### Remaining Release Work

- Publish a GitHub release and attach the signed APK.
- Run a real-phone install check when a USB device is available; emulator install/use smoke test is passing.

## 2026-07-10 Multi-platform release builds

### Completed

- Built Android release APK.
- Built Web release output at `build/web`.
- Built Windows release output at `build/windows/x64/runner/Release/daily_notes.exe`.
- Packaged local release assets under ignored `dist/`.

### Verification

- `flutter build apk --release`: passed.
- `flutter build web --release`: passed; output `build/web`.
- `flutter build windows --release`: passed; output `build/windows/x64/runner/Release/daily_notes.exe`.
- `dist/daily-notes-v1.0.0-android-release.apk` SHA-256: `CE24E5AE8EE1AFB495AEB83987F96A901748A38F26DF0434DB174E711A499943`.
- `dist/daily-notes-v1.0.0-windows-x64.zip` SHA-256: `1521801DCFCE7A83913650CC34E0759F33D65FD7C3CBB82DC511BA6C014D1C9E`.
- `dist/daily-notes-v1.0.0-web.zip` SHA-256: `0B2F63D01D85A7231B22AF4C315A7811E6F975E30D10C55FE40FDDF7C0F53419`.

### Platform Notes

- iOS and macOS release builds require an Apple build/signing environment and were not built on this Windows host.
- Linux release build requires a Linux host/toolchain and was not built on this Windows host.

## 2026-07-10 GitHub release preparation

### Completed

- Added GitHub Release notes at `docs/github_release_v1.0.0.md`.
- Added release status report at `docs/release_status_report.md`.
- Created and pushed annotated tag `v1.0.0`.
- Confirmed local release assets are ready under ignored `dist/`.

### Verification

- `git ls-remote --tags origin v1.0.0`: returned remote tag ref.
- GitHub Releases API for `v1.0.0`: returned `404`, so the GitHub Release has not been created yet.

### Blocker

- No `GH_TOKEN`/`GITHUB_TOKEN` is available and GitHub CLI is not installed/authenticated, so creating the GitHub Release and uploading assets requires GitHub write credentials or an authenticated browser/CLI session.
