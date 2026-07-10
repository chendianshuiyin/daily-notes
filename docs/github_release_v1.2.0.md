# Daily Notes v1.2.0

## Summary

Daily Notes v1.2.0 turns tags into part of the writing flow and adds optional WebDAV synchronization. Notes remain local-first, while users who provide their own WebDAV account can merge changes across devices without handing data to a built-in service.

## Highlights

- Type `#tags` and `#parent/child` directly beside note text.
- Browse tags from a persistent desktop sidebar or a mobile side sheet.
- Filter a whole tag branch and open a random active note for review.
- Test and securely save a WebDAV endpoint, username, password, and remote directory.
- Synchronize both sides by note ID and `updatedAt`, preserving local-only and remote-only notes.
- Use explicit overwrite upload or remote download-and-merge when manual recovery is preferable.
- Keep deletion local during synchronization to avoid accidental cross-device data loss.

## Verification

- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 29 tests.
- Android and Web release builds: passed locally.
- Android 36 emulator: upgrade installation and responsive visual checks passed.
- Windows x64 and Linux x64 packages passed in GitHub Actions runs `29118667532` and `29118182287`.

## Release Assets

- `daily-notes-v1.2.0-android-release.apk`
  - SHA-256: `4927D526136BA9B50C36DC9A3EFDFADBB63863EF6D8F018EA831273C3F53934A`
- `daily-notes-v1.2.0-windows-x64.zip`
  - SHA-256: `18BFF16E2B80C090807FC7851AFBD5025B79719913447EA613B116264E93EBE3`
- `daily-notes-v1.2.0-linux-x64.zip`
  - SHA-256: `AEE55F28D3126992C60D94F429C95135B59D41582BB833C05CDE15244EF6861D`
- `daily-notes-v1.2.0-web.zip`
  - SHA-256: `506B80358F17DC9CB5B07A7BB706E207099F1D3D61A32D025D3A69D5FB44BC38`

## Platform Notes

- Android, Windows, Linux, and Web are in scope; iOS and macOS remain deferred.
- WebDAV on Web requires HTTPS and a server that allows the deployed site's CORS origin.
- Linux secure credential storage requires a Secret Service provider such as GNOME Keyring or KWallet.
- Voice input remains available on Android, Web, and Windows, subject to platform speech services.
