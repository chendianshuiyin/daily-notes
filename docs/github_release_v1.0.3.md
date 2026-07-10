# Daily Notes v1.0.3

## Summary

Daily Notes v1.0.3 turns the original text-note MVP into a polished local-first journal. It adds a responsive GitHub-style activity heatmap, image attachments, durable Hive storage, JSON backup/restore, richer history filtering, and a redesigned light/dark interface.

## Highlights

- Attach up to four images to a note; large images are resized and compressed before local storage.
- Review writing activity in responsive 16, 28, or 52 week heatmaps and open notes for a selected day.
- Search titles, content, and `#tags`, then filter current or archived notes.
- Back up all text and image data as JSON and merge it back from the clipboard.
- Automatically migrate existing v1.0.2 `SharedPreferences` notes to Hive CE without deleting legacy data.
- Render immediately offline with platform fonts and refreshed Android, Windows, Linux, and Web layouts.

## Verification

- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 21 tests.
- Android, Web, and Windows release builds: passed locally.
- Android image picker, attachment save, cold restart persistence, and light/dark visual checks: passed on `Medium_Phone_API_36.1`.
- Linux x64 release is built and uploaded by GitHub Actions.

## Release Assets

- `daily-notes-v1.0.3-android-release.apk`
  - SHA-256: `D38AF67E1C2B325A1542584DB85A11C2C1D709036E24FF938E7209BD4E9E51B9`
- `daily-notes-v1.0.3-windows-x64.zip`
  - SHA-256: `EF159C3791382D3FE882046507035164B02609C797BAF97E155818B9199CBC30`
- `daily-notes-v1.0.3-web.zip`
  - SHA-256: `49A47E85BF6499EEEDBB053EA23A9C401943881DAFDAFA5CEF1FD5B238F1901D`
- `daily-notes-v1.0.3-linux-x64.zip`
  - Built by GitHub Actions with an accompanying `.sha256` file.

## Android Details

- Package: `com.chendianshuiyin.dailynotes`
- Version: `1.0.3` (`versionCode=4`)
- Min SDK: `24`
- Target SDK: `36`
- Existing release signing identity is retained for compatible upgrades.

## Known Limits

- The active release scope is Android, Windows, Linux, and Web; iOS and macOS are deferred.
- A physical Android phone installation remains to be checked; emulator installation and use are verified.
