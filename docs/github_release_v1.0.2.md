# Daily Notes v1.0.2

## Summary

Daily Notes v1.0.2 improves release polish and protects note content during common failure paths. It includes branded icons across supported runners, clearer platform identity, unsaved-draft confirmation, and visible persistence errors without discarding editor content.

## Highlights

- Create, edit, search, archive, and delete local notes.
- Persist system, light, and dark theme choices.
- Confirm before leaving an editor with unsaved changes.
- Keep the current draft available when a save fails.
- Use a branded Daily Notes icon on Android, Web, Windows, Linux, iOS, and macOS runners.
- Preserve existing local notes when upgrading from v1.0.1.

## Release Assets

- `daily-notes-v1.0.2-android-release.apk`
  - SHA-256: `97098D8C5476F46F2064E98A6137A25DB47FA904171CD2C6E0E61C2D4011F047`
- `daily-notes-v1.0.2-windows-x64.zip`
  - SHA-256: `1A29E0BA43F213495568C8B25DD7D3390EF94E77DBE37CB60493E64EBF45E11B`
- `daily-notes-v1.0.2-web.zip`
  - SHA-256: `92FC877A5C231DC3773B1DAA8BA836E775C2A8AED1A5D2588DE2415247AB0176`
- `daily-notes-v1.0.2-linux-x64.zip`
  - SHA-256: `ED8660A4ABBF29E6EAC3F6974397D0F942DACEA3D5D3F87281DEEA9893AF29C5`
  - The accompanying `.sha256` file contains the same workflow-generated checksum.

## Verification

- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 6 tests.
- Android, Web, and Windows release builds: passed.
- Android APK signature and package metadata: passed.
- Android emulator upgrade install, cold launch, create/save, and restart persistence: passed on `Medium_Phone_API_36.1`.
- Linux release build and asset upload passed in GitHub Actions run `29043858648`.

## Android Details

- Package: `com.chendianshuiyin.dailynotes`
- Version: `1.0.2` (`versionCode=3`)
- Min SDK: `24`
- Target SDK: `36`
- Signer SHA-256: `750fe89e137d070f7620dfe198486f4dae01b5087833995e1b651bccedc163d5`

## Known Limits

- The current release scope is Android, Windows, Linux, and Web; iOS and macOS are deferred.
- Physical Android phone installation remains a recommended final hardware check; Android emulator installation and use are verified.
