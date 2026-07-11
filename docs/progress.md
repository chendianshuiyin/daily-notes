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

### Follow-up Tooling

- Added `scripts/create_github_release.ps1` to publish tag `v1.0.0` with the prepared `dist/` assets once GitHub CLI is installed and authenticated.

## 2026-07-10 GitHub CLI install

### Completed

- Installed GitHub CLI `2.96.0` with `winget`.
- Updated `scripts/create_github_release.ps1` so it can use `C:\Program Files\GitHub CLI\gh.exe` even before PATH refresh.

### Verification

- `C:\Program Files\GitHub CLI\gh.exe --version`: passed.
- `gh auth status`: not authenticated.
- `gh auth login --web --clipboard`: attempted, but authorization was not completed before timeout.

### Blocker

- GitHub Release creation still requires `gh auth login` or a valid `GH_TOKEN`/`GITHUB_TOKEN`.

## 2026-07-10 Theme settings

### Completed

- Added `AppSettingsProvider` backed by `SharedPreferences`.
- Wired `DailyNotesApp` to use persisted `ThemeMode`.
- Replaced the placeholder theme settings row with a working segmented control for system, light, and dark modes.
- Added widget coverage for persisting theme mode from the settings page.

### Verification

- `dart format lib test`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 3 tests.

## 2026-07-10 Version 1.0.1 preparation

### Completed

- Bumped app version to `1.0.1+2` after adding persisted theme settings.
- Updated Settings version display to `1.0.1`.
- Replaced pending GitHub Release notes with `docs/github_release_v1.0.1.md`.
- Updated `scripts/create_github_release.ps1` defaults and asset names for `v1.0.1`.

### Verification

- `dart format lib test`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 3 tests.
- `flutter build apk --release`: passed.
- `flutter build web --release`: passed.
- `flutter build windows --release`: passed.
- `apksigner verify --print-certs`: passed.
- `aapt dump badging`: package `com.chendianshuiyin.dailynotes`, version `1.0.1` (`versionCode=2`), min SDK `24`, target SDK `36`, label `Daily Notes`.
- `adb install -r dist/daily-notes-v1.0.1-android-release.apk`: passed on emulator `Medium_Phone_API_36.1`.
- Captured screenshot evidence at `docs/pictures/android-v1.0.1-home.png`.

### Release Assets

- `dist/daily-notes-v1.0.1-android-release.apk` SHA-256: `312388469314F86C46B814E1EFCC4F3D32390F2CE9E8678B057E4648C63CEED9`.
- `dist/daily-notes-v1.0.1-windows-x64.zip` SHA-256: `D9DDC461D75A927BE7C2970B796E61FC8258BF8EFAD4AC7707277D35769BC361`.
- `dist/daily-notes-v1.0.1-web.zip` SHA-256: `54928E0D0BF971369EE39D317FE65C4794846F2A05DB6306837A55B4E86975D8`.

## 2026-07-10 GitHub Release published

### Completed

- Created GitHub Release `v1.0.1`.
- Uploaded Android, Windows, and Web release assets.
- Verified the remote Android APK download SHA-256 matches the local artifact.
- Added repository-facing README, CHANGELOG, and final release report.

### Verification

- `gh release view v1.0.1 --repo chendianshuiyin/daily-notes`: returned published release URL.
- Release URL: `https://github.com/chendianshuiyin/daily-notes/releases/tag/v1.0.1`.
- GitHub asset digests match local SHA-256 values for all three assets.
- Downloaded Android APK from GitHub and verified SHA-256 `312388469314F86C46B814E1EFCC4F3D32390F2CE9E8678B057E4648C63CEED9`.

## 2026-07-10 Repository presentation

### Completed

- Replaced the Flutter template README with a user-facing project overview.
- Added download links, screenshot, feature list, verification table, development commands, architecture outline, and release report links.
- Added `CHANGELOG.md`.
- Added `docs/final_release_report_v1.0.1.md`.
- Updated GitHub repository description, homepage, and topics.

### Verification

- `gh repo view chendianshuiyin/daily-notes --json name,description,homepageUrl,repositoryTopics,url`: confirmed description, homepage, and topics.

## 2026-07-10 App icon and platform branding

### Completed

- Added a custom Daily Notes app icon with editable source at `assets/brand/app_icon.svg`.
- Generated launcher/icon assets for Android, Web, Windows, iOS, and macOS.
- Added a Linux window icon asset and installed it into the Linux release bundle.
- Updated Web manifest/title metadata, Windows version metadata, Linux application ID/window title, and Apple bundle identifiers/display names.
- Added `tools/generate_app_icons.ps1` so platform icon assets can be regenerated from one source design.

### Verification

- Icon size spot check passed for 48, 192, 512, and 1024 px PNGs plus Windows `.ico`.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 3 tests.
- `flutter build apk --release`: passed.
- `flutter build web --release`: passed.
- `flutter build windows --release`: passed.
- `apksigner verify --print-certs`: passed.
- `aapt dump badging`: confirmed package `com.chendianshuiyin.dailynotes`, label `Daily Notes`, and launcher icon resources.

## 2026-07-10 Editor draft protection and persistence reliability

### Completed

- Added a confirmation dialog before leaving an editor with unsaved changes.
- Kept the current draft visible and showed actionable feedback when persistence fails.
- Added error feedback for note load, archive, and delete failures.
- Made `SharedPreferencesNoteRepository` reject unsuccessful writes instead of silently reporting success.
- Replaced the shared static router with an app-owned router instance and lifecycle cleanup.
- Added repository persistence coverage and widget tests for unsaved drafts and failed saves.

### Verification

- `dart format lib test`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 6 tests.
- Commit `9d33004` pushed to `origin/main` as `feat: protect unsaved note drafts`.

## 2026-07-10 Version 1.0.2 release preparation

### Completed

- Bumped the app version to `1.0.2+3` and updated the Settings version display.
- Updated Linux workflow and GitHub Release helper defaults for `v1.0.2`.
- Built and packaged signed Android, Web, and Windows release assets.
- Verified an upgrade install over v1.0.1 preserved its existing note.
- Created and saved a v1.0.2 smoke note, cold-restarted the app, and confirmed the note persisted.
- Captured screenshot evidence at `docs/pictures/android-v1.0.2-home.png`.

### Verification

- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 6 tests.
- `flutter build apk --release`: passed.
- `flutter build web --release`: passed.
- `flutter build windows --release`: passed.
- `apksigner verify --print-certs`: passed.
- `aapt dump badging`: package `com.chendianshuiyin.dailynotes`, version `1.0.2` (`versionCode=3`), min SDK `24`, target SDK `36`, label `Daily Notes`.
- `adb install -r`: passed on emulator `Medium_Phone_API_36.1`.
- `uiautomator dump`: confirmed two persisted notes after the v1.0.2 cold restart.

### Local Release Assets

- `daily-notes-v1.0.2-android-release.apk`: 49,402,296 bytes, SHA-256 `97098D8C5476F46F2064E98A6137A25DB47FA904171CD2C6E0E61C2D4011F047`.
- `daily-notes-v1.0.2-windows-x64.zip`: 11,861,254 bytes, SHA-256 `1A29E0BA43F213495568C8B25DD7D3390EF94E77DBE37CB60493E64EBF45E11B`.
- `daily-notes-v1.0.2-web.zip`: 10,857,015 bytes, SHA-256 `92FC877A5C231DC3773B1DAA8BA836E775C2A8AED1A5D2588DE2415247AB0176`.

## 2026-07-10 Version 1.0.2 publication

### Completed

- Committed release preparation as `becea10 chore: prepare v1.0.2 release` and pushed `main`.
- Created and pushed annotated tag `v1.0.2`.
- Published GitHub Release `Daily Notes v1.0.2` with Android, Windows, and Web assets.
- Ran GitHub Actions workflow `29043858648` and uploaded the Linux x64 ZIP plus checksum sidecar.
- Downloaded the published Android APK and Linux assets for independent hash verification.
- Updated repository download links, checksums, status report, and final release report.

### Verification

- Release URL: `https://github.com/chendianshuiyin/daily-notes/releases/tag/v1.0.2`.
- GitHub reports all five assets as `uploaded`.
- Linux workflow completed successfully in 2 minutes 30 seconds.
- Published Android APK SHA-256: `97098D8C5476F46F2064E98A6137A25DB47FA904171CD2C6E0E61C2D4011F047`.
- Published Linux ZIP SHA-256: `ED8660A4ABBF29E6EAC3F6974397D0F942DACEA3D5D3F87281DEEA9893AF29C5`.
- Linux `.sha256` sidecar contains the same ZIP digest.

## 2026-07-10 Platform scope update

### Decision

- Confirmed the active release and maintenance scope as Android, Windows, Linux, and Web.
- Deferred iOS and macOS work; no Apple platform source or workflow changes were made.
- Kept physical Android phone installation as the only outstanding hardware verification.

## 2026-07-10 v1.0.3 product completion

### Completed

- Added JSON backup and merge restore in commit `f8a2380`.
- Migrated production storage to Hive CE with one-time legacy migration in commit `b169db9`.
- Added compressed image attachments, thumbnails, preview, and backup compatibility in commit `b0ca488`.
- Added a responsive GitHub-style activity heatmap and daily detail selection in commit `2a3feca`.
- Modernized Home, Editor, History, Settings, light/dark themes, search filters, and tags in commit `1e813ea`.
- Removed runtime Google Fonts so all text renders immediately without a network connection.

### Verification

- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 21 tests.
- Android, Web, and Windows release builds passed before release preparation.
- Android 36 emulator verified image selection, compression display, save, Hive persistence after cold restart, responsive heatmap, history filters, and light/dark layouts.
- Final release packaging and published asset checksums are recorded in the v1.0.3 release report.

## 2026-07-11 Version 1.0.3 release preparation

### Completed

- Bumped the app to `1.0.3+4` and updated Settings, release scripts, and the Linux workflow default.
- Replaced runtime Google Fonts with native platform fonts; the final APK rendered all text 1.5 seconds after a cold launch without network access.
- Made widget tests independent of wall-clock dates and isolated UI state with an in-memory repository.
- Added final Android screenshots for Home, Editor, History, and Settings to `docs/pictures/`.
- Built, signed, packaged, and hashed Android, Windows, and Web release assets.

### Verification

- `flutter analyze`: passed with no issues.
- `flutter test`: 21 tests passed in two consecutive full-suite runs.
- APK metadata: package `com.chendianshuiyin.dailynotes`, version `1.0.3` (`versionCode=4`), min SDK `24`, target SDK `36`.
- Final APK upgrade install retained the existing image note on `Medium_Phone_API_36.1`.
- Android SHA-256: `D38AF67E1C2B325A1542584DB85A11C2C1D709036E24FF938E7209BD4E9E51B9`.
- Windows SHA-256: `EF159C3791382D3FE882046507035164B02609C797BAF97E155818B9199CBC30`.
- Web SHA-256: `49A47E85BF6499EEEDBB053EA23A9C401943881DAFDAFA5CEF1FD5B238F1901D`.

## 2026-07-11 Tag organization and voice dictation

### Completed

- Removed the redundant activity heatmap title in commit `f7eec7f`.
- Added dedicated and inline hashtag persistence, search, tag counts, and archive filtering in commit `5efe39f`.
- Added short voice dictation for Android, Web, and Windows in commit `d83e898`.
- Configured Android recording permission and speech recognition service discovery.
- Verified tag entry, save, history filtering, microphone permission, and no-speech feedback on Android 36.
- Found and fixed low-contrast tag labels in both history filters and editor chips during screenshot review.

### Verification

- `flutter analyze`: passed with no issues.
- `flutter test`: 23 tests passed.
- Android, Web, and Windows release builds passed with `speech_to_text 7.4.0`.
- Android editor exposes image, time, voice, character count, and save controls without overflow at 1080x2400.
- The Web release rendered Home and Editor without console errors; the Windows executable launched and remained responsive.

## 2026-07-11 Version 1.1.0 release preparation

### Completed

- Bumped the app to `1.1.0+5` and updated Settings, release scripts, and the Linux workflow default.
- Rebuilt and packaged signed Android, Windows, and Web release assets after the final visual fix.
- Verified APK signature, package metadata, upgrade installation, and retained v1.0.3 data.
- Added v1.1.0 Home, Editor, History, and Settings screenshots to `docs/pictures/`.
- Updated README, CHANGELOG, GitHub release notes, release status, and final release report.

### Local Release Assets

- Android: 53,745,548 bytes, SHA-256 `84B44433730255623F48B85FE7F3BEDB8C2A2DBECBEBDE5C30E7029CE806B5B5`.
- Windows: 12,412,484 bytes, SHA-256 `E778A3441B9948B7990B27D004DD09E859C6353144C3CF2CCB88E06638ACC9D4`.
- Web: 11,048,399 bytes, SHA-256 `F415C0DDC179F47C41335D5F10AF4C23D62DBC6C369DC3EA5F0220A6AC34115F`.

## 2026-07-11 Version 1.1.0 publication

### Completed

- Committed release preparation as `9721c69 chore: prepare v1.1.0 release` and pushed `main`.
- Created and pushed annotated tag `v1.1.0`.
- Published GitHub Release `Daily Notes v1.1.0` with Android, Windows, and Web assets.
- Ran GitHub Actions workflow `29111879692`; Linux x64 built and uploaded successfully.
- Downloaded the Linux ZIP and checksum sidecar for independent verification.
- Confirmed all five GitHub assets are uploaded and their digests match the final packages.

### Verification

- Release URL: `https://github.com/chendianshuiyin/daily-notes/releases/tag/v1.1.0`.
- Linux asset: 11,001,268 bytes, SHA-256 `BB3C55A16BD72CDAB8879B396BD6A18ECE742AAB5C7315125416B52A0C80165D`.
- Linux `.sha256` sidecar contains the same digest.
- GitHub asset digests match local Android, Windows, Web, and downloaded Linux SHA-256 values.

## 2026-07-11 Physical Android verification automation

### Completed

- Added `scripts/verify_android_device.ps1` for the remaining hardware release gate.
- Made physical-device selection mandatory by default; an emulator is accepted only with explicit `-AllowEmulator`.
- Added APK package/version inspection, upgrade installation, launch verification, smoke-note entry, save, force-stop, cold launch, and persistence checks.
- Added UI hierarchy and screenshot evidence capture under ignored `dist/android-device-verification/`.
- Documented the one-command physical verification flow in README and the final release report.

### Verification

- PowerShell parser check: passed with no syntax errors.
- Default run with only `emulator-5554` connected: correctly rejected as non-physical evidence.
- Explicit emulator maintenance run: passed end to end for package `com.chendianshuiyin.dailynotes`, version `1.1.0` (`versionCode=5`).
- Verified APK SHA-256 `84B44433730255623F48B85FE7F3BEDB8C2A2DBECBEBDE5C30E7029CE806B5B5`.
- Created `emulator-script-smoke-20260711b`, saved it, force-stopped the app, cold-launched, and confirmed the note remained visible.

### Scope Decision

- On 2026-07-11, the project owner explicitly removed physical-phone execution from the release acceptance scope.
- The completed Android 36 emulator install, write, save, force-stop, cold-launch, and persistence evidence is accepted as the final Android gate.
- The strict physical-device script mode remains available for optional future maintenance and is not a pending release requirement.

## 2026-07-11 Inline tags and sidebar navigation

### Completed

- Studied flomo's public quick-capture, inline multi-level tag, sidebar, and review workflows without copying its visual design or product text.
- Removed the dedicated tag field from Editor; `#tags` and `#parent/child` tags now live directly in the note body.
- Added automatic migration that appends legacy explicit tags to the body when an older note is opened.
- Replaced the horizontal tag chip strip with a persistent desktop sidebar and a slide-in narrow-screen side sheet.
- Added parent-tag aggregation, hierarchical filtering, and a random-review action for active notes.

### Verification

- `flutter analyze`: passed with no issues.
- `flutter test`: 25 tests passed, including hierarchical matching, parent filtering, random review, and legacy tag migration.

## 2026-07-11 WebDAV synchronization

### Completed

- Added encrypted WebDAV configuration for server URL, username, password, and remote directory.
- Added connection testing, explicit overwrite upload, download-and-merge, and bidirectional newest-update synchronization.
- Stored one versioned JSON backup at `/DailyNotes/daily-notes-backup.json`; writes use a temporary file and rename when supported.
- Kept local-only and remote-only notes, selected the newer `updatedAt` value for matching IDs, and deliberately avoided automatic deletion propagation.
- Added Android backup hardening and Linux `libsecret` build dependencies.
- Added focused merge, malformed-backup, tag round-trip, and Settings UI coverage.

### Verification

- `flutter analyze`: passed with no issues.
- `flutter test`: 29 tests passed.
- Android and Web release builds passed.
- Android 36 emulator verified the synchronization section, WebDAV dialog, tag side sheet, and editor toolbar without overflow.
- Windows source configuration is complete; this host still needs ATL installed for its selected MSVC 14.38 toolchain before rebuilding the Windows package.

### Platform Notes

- Web deployments require HTTPS and a WebDAV endpoint that permits the site's CORS origin.
- Linux requires `libsecret-1-dev` to build and a Secret Service provider at runtime.
- iOS and macOS remain outside the active release scope.

## 2026-07-11 Version 1.2.0 publication

### Completed

- Bumped the app to `1.2.0+6`, updated repository screenshots, README, CHANGELOG, release notes, and platform scripts.
- Built, signed, packaged, and published Android and Web assets locally.
- Published tag and GitHub Release `v1.2.0`.
- Added and ran a Windows x64 release workflow on the ATL-enabled `windows-2022` runner.
- Ran the Linux x64 workflow with `libsecret-1-dev` and uploaded both desktop packages plus checksum sidecars.
- Downloaded Windows and Linux assets and independently matched their SHA-256 values to GitHub digests and sidecars.

### Verification

- Release URL: `https://github.com/chendianshuiyin/daily-notes/releases/tag/v1.2.0`.
- Windows workflow run `29118667532`: passed.
- Linux workflow run `29118182287`: passed.
- GitHub reports all six assets as uploaded.

## 2026-07-11 Editor 2.0 design and foundations

### Completed

- Defined the responsive product shell, capture and review flows, block editor schema, migration strategy, and privacy-first AI boundaries under `docs/design/`.
- Reworked voice input into explicit starting, listening, and review phases; recognized text is inserted only after confirmation and can be retried or discarded.
- Added installed-locale selection and cursor-safe transcript insertion without overwriting existing note text.
- Added an `Untagged` sidebar filter and automatic recovery from stale tag selections after search or status changes.
- Added a versioned V2 note-block model with legacy text/image derivation and backup round-trip support.

### Verification

- `flutter analyze`: passed with no issues.
- `flutter test`: 34 tests passed.
- Android and Web release builds passed; the Web Wasm dry run also passed.
- Android 36 emulator preserved the existing three-note database across upgrade installation.
- Emulator UI checks confirmed the mobile tag side sheet, two-note untagged result, first-use microphone permission, fixed listening panel, locale indicator, disabled save state, and no-speech fallback without overflow.

### Remaining Work

- Integrate the block editor UI, lightweight Markdown shortcuts and preview, and freely ordered multi-image blocks.
- Implement opt-in AI tag, cleanup, related-note, question, and review features after the editor interaction is stable.

## 2026-07-11 Markdown preview foundation

### Completed

- Added an app-owned Markdown codec for headings, paragraphs, bullet and numbered lists, quotes, dividers, and fenced code blocks.
- Preserved inline `#tags` as paragraph text and reused existing text-block IDs while editing.
- Added a read-only Markdown preview to the Editor action menu using `appflowy_editor` behind the app-owned content boundary.
- Saved typed text blocks alongside the compatibility Markdown shadow and increased the per-note image limit from 4 to 12.
- Kept the narrow-screen bottom toolbar unchanged to avoid adding another overflow-prone action.

### Verification

- `flutter test`: 38 tests passed, including Markdown codec round-trip and draft-preserving preview coverage.
- `flutter analyze`: passed with no issues.
- Android release APK built at 63,463,294 bytes and Web release compilation completed, including its Wasm dry run.
- Android 36 emulator upgrade installation retained existing data and showed the `0/12` image counter.
- Emulator visual inspection confirmed the preview sheet has finite bounds, internal scrolling, a reachable close action, and no narrow-screen overflow.

### Remaining Work

- Replace source-only body editing with the full block editing surface and formatting controls.
- Insert image blocks at the caret, then add captions, reorder, replace, and mixed text/image persistence tests.
