# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter app named `daily_notes`. Primary Dart code lives in `lib/` and is organized by responsibility: `core/` for shared constants, theme, utilities, and widgets; `data/` for datasources, models, and repository implementations; `domain/` for repository contracts; and `presentation/` for pages, providers, and routing. Tests live in `test/`, with the current widget smoke test in `test/widget_test.dart`. Platform runners are in `android/`, `ios/`, `linux/`, `macos/`, `web/`, and `windows/`. Planning notes and feature specs are kept in `docs/`.

## Build, Test, and Development Commands

- `flutter pub get`: install dependencies from `pubspec.yaml`.
- `flutter run -d windows`: run the desktop app locally on Windows.
- `flutter run -d chrome`: run the web target during UI checks.
- `flutter analyze`: run Dart analyzer and `flutter_lints` rules.
- `flutter test`: run all unit and widget tests.
- `flutter build apk`: create an Android release APK when mobile packaging is needed.

## Coding Style & Naming Conventions

Use standard Dart formatting with 2-space indentation; run `dart format lib test` before submitting larger edits. Follow `analysis_options.yaml`, which includes `package:flutter_lints/flutter.yaml`. Name files in `snake_case.dart`, classes and widgets in `PascalCase`, and variables, methods, and providers in `lowerCamelCase`. Keep shared UI primitives under `lib/core/widgets/`, theme values under `lib/core/theme/`, and route definitions in `lib/presentation/routers/`.

## Testing Guidelines

Use `flutter_test` for widget and unit coverage. Name tests by observable behavior, for example `testWidgets('App builds successfully', ...)`. Place new tests under `test/`, mirroring the feature or layer being changed when practical. Every change that affects navigation, persistence, providers, or user-visible UI should include or update a focused test. Run `flutter test` and `flutter analyze` before opening a pull request.

## Commit & Pull Request Guidelines

Recent history uses short messages with Conventional Commit-style prefixes such as `feat:` and `docs:`. Prefer English commit messages like `feat: add note editor persistence` or `fix: handle empty history state`. Pull requests should include a concise summary, linked issue or task when available, test results, and screenshots or short recordings for UI changes. Note any platform-specific behavior, especially for Android, iOS, Windows, and Web.

## Security & Configuration Tips

Do not commit generated build output, local IDE metadata, secrets, or machine-specific configuration. Keep dependency changes in both `pubspec.yaml` and `pubspec.lock`, and document any new runtime permission or platform configuration in the relevant platform directory.
