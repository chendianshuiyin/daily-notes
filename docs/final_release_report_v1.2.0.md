# Daily Notes v1.2.0 Final Release Report

## Summary

Daily Notes v1.2.0 is a local-first notes release for Android, Windows, Linux, and Web. It moves tags into note text, adds hierarchical tag navigation and random review, and introduces optional self-configured WebDAV synchronization with encrypted credential storage.

Release URL: https://github.com/chendianshuiyin/daily-notes/releases/tag/v1.2.0

## Release Assets

| Asset | Size | SHA-256 |
| --- | ---: | --- |
| `daily-notes-v1.2.0-android-release.apk` | 55,715,032 bytes | `4927D526136BA9B50C36DC9A3EFDFADBB63863EF6D8F018EA831273C3F53934A` |
| `daily-notes-v1.2.0-windows-x64.zip` | 13,726,462 bytes | `18BFF16E2B80C090807FC7851AFBD5025B79719913447EA613B116264E93EBE3` |
| `daily-notes-v1.2.0-linux-x64.zip` | 11,299,099 bytes | `AEE55F28D3126992C60D94F429C95135B59D41582BB833C05CDE15244EF6861D` |
| `daily-notes-v1.2.0-web.zip` | 11,092,928 bytes | `506B80358F17DC9CB5B07A7BB706E207099F1D3D61A32D025D3A69D5FB44BC38` |

## Android Evidence

- Package: `com.chendianshuiyin.dailynotes`
- Version: `1.2.0` (`versionCode=6`)
- Min SDK: `24`; target SDK: `36`
- Signer SHA-256: `750fe89e137d070f7620dfe198486f4dae01b5087833995e1b651bccedc163d5`

The signed APK upgraded over v1.1.0 without clearing existing notes. Android 36 emulator `Medium_Phone_API_36.1` verified multi-level tag entry, save, force-stop, cold-start persistence, the tag side sheet, WebDAV settings, and the editor toolbar. Final screenshots are stored in `docs/pictures/android-v1.2.0-*.png`.

## Build and Test Evidence

- `dart format lib test`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: 29 tests passed.
- Android and Web release builds passed locally.
- Windows x64 passed in GitHub Actions run `29118667532`.
- Linux x64 passed in GitHub Actions run `29118182287`.
- Downloaded Windows and Linux hashes matched GitHub digests and both `.sha256` sidecars.
- Android APK signature and package metadata checks passed.

## Synchronization Behavior

WebDAV stores one versioned JSON backup in the configured directory. Bidirectional sync keeps local-only and remote-only notes; matching IDs use the newer `updatedAt` value. Writes use a temporary remote file and rename when supported. Deletions do not propagate automatically. Explicit overwrite upload and download-and-merge remain available for recovery.

## Compatibility and Scope

Older dedicated tags are appended to note content when opened, and backups now preserve tags. Existing text, compressed images, archive state, Hive data, and the Android signing identity remain compatible.

iOS and macOS are intentionally deferred. WebDAV on Web requires HTTPS and server-side CORS. Linux secure storage requires a Secret Service provider and does not expose voice input. Physical-phone execution remains outside the accepted release scope; Android acceptance is based on the completed emulator upgrade and cold-start workflow.
