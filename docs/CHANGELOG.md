# Changelog — Desi Guess

All notable changes to **Desi Guess** are documented in this file.

---

## [1.0.0+1] — Desi Guess – Local Edition

### Initial Development & Core Local Pass-and-Play
- Built the Flutter application with Material 3 dark theme, Riverpod state management, GoRouter navigation, Hive/SharedPreferences offline persistence, English/Hinglish localization, and bundled WAV sound effects.
- Implemented the 450-card Indian library across 24 packs (`WHO: 250`, `WHAT: 128`, `WHERE: 72`) plus offline Custom Board & Custom Card creation.
- Added `RandomBoardGenerator` to deal balanced 10-card boards across all subcategories of **WHO**, **WHAT**, or **WHERE** with automatic distinct secret card assignment (`MY CARD` exclusion) and Privacy Handoff screens.
- Implemented the pure Dart `GameEngine` five-heart deduction system, match persistence/resume, player profiles, achievements, and match results.
- Aligned SDK and build configuration for FlutLab compatibility (`sdk: '>=3.11.5 <4.0.0'`, standard `package:flutter/material.dart`, Gradle `8.10.2`, AGP `8.7.3`, Kotlin `2.1.0`).

### Temporary Disabling of Online Multiplayer (Local-Only Release)
- Introduced [`FeatureFlags`](../lib/core/config/feature_flags.dart) with `enableOnlineMultiplayer = false` by default and gated Firebase startup on `FeatureFlags.enableOnlineMultiplayer && kEnableFirebase`.
- Simplified the Home Dashboard and Pass & Play Setup screens to focus exclusively on offline single-device Pass-and-Play.
- Hid Online Multiplayer, Create Room, Join Room, Online Chat, Friends & Invites, Leaderboard, and cloud-sync UI controls while redirecting online routes safely to local screens.
- Preserved all Firebase repositories, Cloud Functions, Firestore/Storage security rules, and online screens intact for future re-enablement.

### Gameplay Improvements & Automatic Turn Switching
- Updated `GameEngine.submitFinalGuess` so an incorrect final guess immediately deducts 1 heart, ends the current player's turn, and automatically switches to the next active player (skipping eliminated 0-heart players).
- **Removed the manual "End Turn" button**, callbacks, and localization strings from the gameplay UI; turn progression is now fully automatic.
- Added the floating notification `"Incorrect Guess! 1 Heart Lost. It's <NextPlayer>'s Turn."` followed by automatic transition to the Privacy Handoff screen, while 0-heart eliminations and correct guesses navigate directly to Match Results.
- Fixed narrow-screen (`360×640`) `RenderFlex` layout overflows on `CategorySelectionScreen`, `HomeScreen`, `MainGameBoardScreen`, and `HeartsIndicator`.

### Complete 450-Card Image Library Audit & Replacements
- Conducted a full visual inspection of all 450 bundled card images (`WHO: 250`, `WHAT: 128`, `WHERE: 72`).
- Retained **280** visually verified original images.
- Replaced **115** confirmed mismatched, duplicate (`cty_04` Jaipur vs `ta_12` Hawa Mahal), and low-quality/cropped images with visually verified open-licensed Wikimedia Commons images normalized to `320×320` JPEG.
- Replaced **55** mismatched cards that lack free-licensed Wikimedia Commons imagery (copyrighted cartoon characters, niche creators, trademarked goods, and films) with clean original project-owned DESI GUESS graphics, explicitly flagged as **Manual Verification Required**.
- Updated `assets/cards/artwork_manifest.json` and generated `reports/DESI_GUESS_IMAGE_AUDIT.xlsx`, `reports/DESI_GUESS_IMAGE_AUDIT.pdf`, and `reports/IMAGE_SOURCES_AND_ATTRIBUTION.md` with zero duplicate hashes or missing assets.

### Documentation & GitHub Repository Preparation
- Organized project documentation with `README.md` at the root, six detailed guides inside `docs/` (`PROJECT_OVERVIEW.md`, `GAME_RULES.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `WALKTHROUGH.md`), and image audit/attribution records inside `reports/`.
- Cleaned redundant export folders, duplicate ZIP archives, superseded generated reports, and ephemeral build caches.
- Hardened `.gitignore` to prevent committing secrets, keystores, Firebase private credentials, Office lock files, or build artifacts.
