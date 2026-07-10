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
- Windows x64 and Linux x64 packages are built from this tag in GitHub Actions.

## Platform Notes

- Android, Windows, Linux, and Web are in scope; iOS and macOS remain deferred.
- WebDAV on Web requires HTTPS and a server that allows the deployed site's CORS origin.
- Linux secure credential storage requires a Secret Service provider such as GNOME Keyring or KWallet.
- Voice input remains available on Android, Web, and Windows, subject to platform speech services.
