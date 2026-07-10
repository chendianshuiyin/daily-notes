# Daily Notes v1.1.0

## Summary

Daily Notes v1.1.0 adds structured `#tags` and short voice dictation to the existing local-first text and image workflow. Tags now travel with notes, backups, search, and archive filters, while Android, Web, and Windows users can dictate directly into note content.

## Highlights

- Add up to eight dedicated tags per note and automatically recognize inline hashtags.
- Filter current and archived notes by tag, with visible per-tag note counts.
- Dictate short passages from the editor on Android, Web, and Windows.
- Handle microphone permission, unavailable recognition services, network errors, and no-speech results with visible feedback.
- Keep the activity heatmap compact by removing its redundant title.
- Preserve existing text, images, archive state, and backups during upgrade.

## Verification

- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 23 tests.
- Android, Web, and Windows release builds: passed locally.
- Android 36 emulator: upgrade install, existing image note retention, tag editing/filtering, microphone permission, and no-speech feedback passed.
- Linux x64 build and asset upload passed in GitHub Actions run `29111879692`; voice input is disabled on Linux.

## Release Assets

- `daily-notes-v1.1.0-android-release.apk`
  - SHA-256: `84B44433730255623F48B85FE7F3BEDB8C2A2DBECBEBDE5C30E7029CE806B5B5`
- `daily-notes-v1.1.0-windows-x64.zip`
  - SHA-256: `E778A3441B9948B7990B27D004DD09E859C6353144C3CF2CCB88E06638ACC9D4`
- `daily-notes-v1.1.0-web.zip`
  - SHA-256: `F415C0DDC179F47C41335D5F10AF4C23D62DBC6C369DC3EA5F0220A6AC34115F`
- `daily-notes-v1.1.0-linux-x64.zip`
  - SHA-256: `BB3C55A16BD72CDAB8879B396BD6A18ECE742AAB5C7315125416B52A0C80165D`

## Android Details

- Package: `com.chendianshuiyin.dailynotes`
- Version: `1.1.0` (`versionCode=5`)
- Min SDK: `24`; target SDK: `36`
- Existing release signing identity is retained for compatible upgrades.

## Known Limits

- iOS and macOS are deferred.
- Speech recognition is intended for short dictation and depends on the platform speech service.
- A physical Android phone installation remains to be checked; emulator installation and use are verified.
