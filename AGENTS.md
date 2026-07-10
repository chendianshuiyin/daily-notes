# Repository Guidelines

## Project Structure & Module Organization

Primary Dart code lives in `lib/`: `core/` holds shared theme and widgets, `data/` holds models and implementations, `domain/` holds repository contracts, and `presentation/` holds pages, providers, and routing. Tests live in `test/`. Active platform runners are Android, Windows, Linux, and Web; Apple targets are deferred. Planning notes and feature specs are kept in `docs/`.

## Build, Test, and Development Commands

- `flutter pub get`: install dependencies from `pubspec.yaml`.
- `flutter run -d windows`: run the desktop app locally on Windows.
- `flutter run -d chrome`: run the web target during UI checks.
- `flutter analyze`: run Dart analyzer and `flutter_lints` rules.
- `flutter test`: run all unit and widget tests.
- `flutter build apk`: create an Android release APK.

Windows builds require the Visual Studio C++ ATL component because `flutter_secure_storage_windows` uses it. Linux builds require `libsecret-1-dev`; install it before running `flutter build linux`.

## Coding Style & Naming Conventions

Use standard Dart formatting with 2-space indentation; run `dart format lib test` before submission. Follow `analysis_options.yaml` and `flutter_lints`. Name files in `snake_case.dart`, classes and widgets in `PascalCase`, and variables, methods, and providers in `lowerCamelCase`. Keep shared UI primitives under `lib/core/widgets/`, theme values under `lib/core/theme/`, and route definitions in `lib/presentation/routers/`.

## Testing Guidelines

Use `flutter_test` for widget and unit coverage. Name tests by observable behavior, for example `testWidgets('App builds successfully', ...)`. Place new tests under `test/`, mirroring the feature or layer being changed when practical. Every change that affects navigation, persistence, providers, or user-visible UI should include or update a focused test. Run `flutter test` and `flutter analyze` before opening a pull request.

## Commit & Pull Request Guidelines

Recent history uses short messages with Conventional Commit-style prefixes such as `feat:` and `docs:`. Prefer English commit messages like `feat: add note editor persistence` or `fix: handle empty history state`. Pull requests should include a concise summary, linked issue or task when available, test results, and screenshots or short recordings for UI changes. Note any platform-specific behavior, especially for Android, Windows, Linux, and Web.

## Security & Configuration Tips

Do not commit generated build output, local IDE metadata, secrets, or machine-specific configuration. Keep dependency changes in both `pubspec.yaml` and `pubspec.lock`, and document any new runtime permission or platform configuration in the relevant platform directory.
WebDAV credentials must stay in `flutter_secure_storage`. Web deployments need HTTPS, and the WebDAV server must allow the site's CORS origin.
