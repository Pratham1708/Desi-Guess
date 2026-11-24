# Contributing to Desi Guess

Thank you for your interest in contributing to **Desi Guess**! Please follow these guidelines to keep the codebase clean, FlutLab-compatible, legally compliant, and reliable offline.

---

## 1. Development Environment & Requirements

- **Dart SDK**: `>=3.11.5 <4.0.0` (must remain compatible with FlutLab's Dart `3.11.5` environment—do **not** introduce Dart 3.14-only APIs or `package:material_ui`).
- **Flutter SDK**: Flutter 3.x stable using standard `package:flutter/material.dart`.
- **Android Toolchain**: Gradle `8.10.2`, Android Gradle Plugin `8.7.3`, Kotlin `2.1.0`, JDK 17 or JDK 21.
- **No Firebase Credentials Required**: The app runs offline by default (`ENABLE_ONLINE_MULTIPLAYER=false`, `ENABLE_FIREBASE=false`). Never commit `google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`, `.env`, or signing keystores.

---

## 2. Repository Setup

```bash
git clone https://github.com/<your-username>/desi-guess.git
cd desi-guess
flutter pub get
flutter test
```

---

## 3. Branching Conventions

Create a focused branch from `main` for every change:

- `feat/<short-description>` — New gameplay or UI features
- `fix/<short-description>` — Bug fixes and layout overflow fixes
- `assets/<short-description>` — Card artwork additions or verified replacements
- `docs/<short-description>` — Documentation updates
- `chore/<short-description>` — Build, dependency, or cleanup tasks

---

## 4. Commit Message Conventions

Use clear, concise imperative commit messages (Conventional Commits style recommended):

- `feat: add South Indian cinema card pack`
- `fix: prevent HeartsIndicator overflow on narrow screens`
- `assets: replace verified licensed image for cl_05`
- `docs: clarify five-heart elimination rule in GAME_RULES.md`
- `test: add narrow viewport regression test for HomeScreen`

---

## 5. Code Formatting & Static Analysis

Before opening a pull request, format all Dart code and verify zero analyzer warnings or errors:

```bash
dart format lib test
flutter analyze
```

---

## 6. Testing Requirements

Run the full automated test suite before submitting changes:

```bash
flutter test
```

*(On Windows environments where Smart App Control blocks `impellerc.exe`, run `flutter test --no-test-assets`.)*

- Keep pure game-rule tests in `test/game_engine_test.dart`.
- Add widget regression tests in `test/widget_test.dart` for any UI or responsive layout changes (test at `360×640` for narrow phones).
- Ensure all 450 built-in card paths and `assets/cards/artwork_manifest.json` pass integrity checks with zero duplicate image hashes.

---

## 7. Pull Request Process

1. Rebase or merge the latest `main` into your branch.
2. Confirm `dart format`, `flutter analyze`, and `flutter test` all pass.
3. Keep PRs focused—do not re-enable online multiplayer or Firebase in local-edition PRs unless explicitly planned.
4. Describe what changed, why, and how it was tested in the PR description.

---

## 8. Asset Contribution, Attribution & Licence Rules

All card images in `assets/cards/` must strictly follow these rules:

- **Format & Size**: Square `320×320` JPEG (`quality ~85–88`), clear subject framing (top-biased crop for portraits, aspect-fit with clean padding for logos).
- **Legal Sources Only**: Use only **Wikimedia Commons** open-licensed media (CC BY, CC BY-SA, CC0, GODL-India, FAL, Public Domain) or **original artwork** created specifically for Desi Guess. **Never** upload copyrighted posters, cartoon stills, or unverified web images without a valid licence.
- **Visual Verification Required**: Visually confirm the image actually depicts the intended card subject and introduces zero duplicates.
- **Mandatory Metadata Updates**: Whenever adding or replacing a card image, update:
  1. `assets/cards/artwork_manifest.json` (exact `sourceUrl`, `attribution`, `licence`, `verified` flag)
  2. `reports/IMAGE_SOURCES_AND_ATTRIBUTION.md`
  3. Preserve existing `cardId` and asset path conventions.
