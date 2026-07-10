# Daily Notes Release Status Report

## Current Status

Daily Notes v1.2.0 is published for Android, Windows, Linux, and Web. The release combines the local-first text, image, heatmap, archive, backup, and voice workflows with inline multi-level tags, responsive tag navigation, random review, and optional WebDAV synchronization.

Release URL: https://github.com/chendianshuiyin/daily-notes/releases/tag/v1.2.0

## Completed Evidence

- Hive CE storage with legacy migration and versioned JSON backup/merge restore.
- Inline `#tags`, `#parent/child` hierarchy, parent counts, branch filtering, and random review.
- WebDAV connection testing, encrypted credentials, newest-update synchronization, overwrite upload, and download-and-merge.
- Explicit no-delete synchronization policy to reduce cross-device data-loss risk.
- Signed Android package `com.chendianshuiyin.dailynotes`, version `1.2.0` (`versionCode=6`).
- 29 passing unit/widget tests and a clean analyzer gate.
- Android and Web release builds completed locally.

## Local Packages

| Asset | Size | SHA-256 |
| --- | ---: | --- |
| `daily-notes-v1.2.0-android-release.apk` | 55,715,032 bytes | `4927D526136BA9B50C36DC9A3EFDFADBB63863EF6D8F018EA831273C3F53934A` |
| `daily-notes-v1.2.0-windows-x64.zip` | 13,726,462 bytes | `18BFF16E2B80C090807FC7851AFBD5025B79719913447EA613B116264E93EBE3` |
| `daily-notes-v1.2.0-linux-x64.zip` | 11,299,099 bytes | `AEE55F28D3126992C60D94F429C95135B59D41582BB833C05CDE15244EF6861D` |
| `daily-notes-v1.2.0-web.zip` | 11,092,928 bytes | `506B80358F17DC9CB5B07A7BB706E207099F1D3D61A32D025D3A69D5FB44BC38` |

Windows run `29118667532` and Linux run `29118182287` completed successfully. Their downloaded ZIP hashes match both GitHub's asset digests and the published SHA-256 sidecars.

## Android Verification

Android 36 AVD `Medium_Phone_API_36.1` passed upgrade installation, package/version checks, inline multi-level tag entry, save, force-stop, cold launch, and persistence. Visual inspection covered Home, Editor, the mobile tag side sheet, WebDAV settings, and the credential dialog without overflow or overlap.

## Operational Notes

- Web deployments require HTTPS and WebDAV CORS configuration.
- Windows source builds require the Visual Studio C++ ATL component.
- Linux builds require `libsecret-1-dev`, and runtime secure storage needs a Secret Service provider.
- The Android release keystore and `android/key.properties` remain outside Git.
- Physical-phone execution is outside the accepted release scope.

iOS and macOS remain outside the active release scope. Linux supports note and WebDAV workflows but not voice input.
