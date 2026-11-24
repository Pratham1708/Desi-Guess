# Desi Guess – Local Edition

**Desi Guess** is a Flutter-based Indian-themed two-player social deduction and guessing game built for **offline Pass-and-Play on a single phone**.

Two players share a freshly randomized 10-card Indian board across **WHO**, **WHAT**, and **WHERE**, protect their secret cards with Privacy Handoffs, ask unlimited verbal Yes/No questions, eliminate suspects, and race to deduce the opponent's secret card under a five-heart final-guess system.

> **Current Release Status:** **Desi Guess – Local Edition (`1.0.0+1`)** — Offline Local Pass-and-Play only. Online multiplayer, rooms, live chat, invitations, and global leaderboards are temporarily disabled via [`FeatureFlags`](lib/core/config/feature_flags.dart), with the Firebase backend safely preserved in the repository for future releases.

---

## Key Features

- **100% Offline Local Pass-and-Play**: Play two-player deduction matches on one device with zero internet connectivity, accounts, or Firebase credentials required.
- **Randomized 10-Card Boards**: Every match in **WHO**, **WHAT**, or **WHERE** deals 10 freshly shuffled cards drawn from across all subcategories (450 built-in Indian cards across 24 themed packs).
- **Automatic Distinct Secret Assignment & Privacy Handoffs**: Each player receives a distinct secret card (marked `MY CARD` and excluded from opponent guess candidates) protected by full-screen Privacy Handoff screens between turns.
- **Five-Heart Deduction & Automatic Turn Switching**:
  - Unlimited verbal Yes/No questions (never cost hearts).
  - Five starting hearts per player.
  - Correct final guess wins immediately.
  - Incorrect final guess immediately deducts **1 heart**, displays `"Incorrect Guess! 1 Heart Lost. It's <NextPlayer>'s Turn."`, and **automatically ends the turn** and switches to the next active player (no manual **End Turn** button).
  - Losing the last heart eliminates the player and ends the match on the Results screen.
- **Custom Boards (Offline)**: Create private custom decks and cards stored locally in Hive and launch Pass-and-Play matches directly.
- **English & Hinglish UI**: Instant language toggle in Settings (`EN` / `Hinglish`), plus sound effects, haptics, and persistent local match history/stats.
- **Audited 450-Card Image Library**: All 450 `320×320` JPEG card images are bundled offline and tracked in [`assets/cards/artwork_manifest.json`](assets/cards/artwork_manifest.json) (280 original verified images retained, 115 replaced with visually verified open-licensed Wikimedia Commons images, and 55 clean project-owned original graphics flagged for manual verification pending licensed artwork).

---

## Technology Stack

| Layer | Technology |
|---|---|
| Framework & Language | Flutter (Material 3), Dart (`>=3.11.5 <4.0.0`, FlutLab compatible) |
| State Management | `flutter_riverpod` |
| Navigation | `go_router` |
| Local Persistence | `hive`, `hive_flutter`, `shared_preferences` |
| UI, Fonts & Audio | `google_fonts`, `flutter_animate`, `confetti`, `audioplayers` |
| Preserved Backend (Disabled) | Firebase Auth, Cloud Firestore, Cloud Functions, Storage, App Check, Crashlytics, Analytics (`ENABLE_ONLINE_MULTIPLAYER=false`, `ENABLE_FIREBASE=false`) |
| Android Build | Gradle `8.10.2`, AGP `8.7.3`, Kotlin `2.1.0` |

---

## Installation & Setup

### Prerequisites
- Flutter SDK (Dart `>=3.11.5 <4.0.0`)
- Android Studio / Android SDK + JDK 17 or JDK 21 (for local Android builds), or a [FlutLab](https://flutlab.io/) workspace

### Local Setup
```bash
git clone https://github.com/<your-username>/desi-guess.git
cd desi-guess
flutter pub get
```

---

## Running the Application

No Firebase configuration files (`google-services.json`, `GoogleService-Info.plist`, or `firebase_options.dart`) are needed.

```bash
flutter run
```

To run tests and static analysis:
```bash
dart format lib test
flutter analyze
flutter test
```

---

## Building the Android Release APK

### Option 1: FlutLab (Recommended)
1. Upload `desi_guess_flutlab.zip` (or import the repository) into FlutLab.
2. Click **Get Packages** (`flutter pub get`).
3. Open **Build → Android APK → Release** (no extra `--dart-define` flags or Firebase files needed).
4. Download and install the generated `app-release.apk`.

### Option 2: Flutter CLI (JDK 17 / JDK 21)
```bash
flutter clean
flutter pub get
flutter build apk --release
```
Output APK: `build/app/outputs/flutter-apk/app-release.apk`.

---

## Documentation

- [docs/PROJECT_OVERVIEW.md](docs/PROJECT_OVERVIEW.md) — Vision, audience, categories, current limitations, and roadmap
- [docs/GAME_RULES.md](docs/GAME_RULES.md) — Complete Pass-and-Play rules, five-heart system, and automatic turn switching
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Clean architecture, routing, state management, assets, and preserved Firebase design
- [docs/WALKTHROUGH.md](docs/WALKTHROUGH.md) — Step-by-step player guide from launch to match results
- [docs/CHANGELOG.md](docs/CHANGELOG.md) — Version history and key milestones
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) — Environment setup, coding standards, testing, and asset licensing rules

### Image Audit & Licensing Deliverables
- [reports/IMAGE_SOURCES_AND_ATTRIBUTION.md](reports/IMAGE_SOURCES_AND_ATTRIBUTION.md) — Complete source URLs, creators, and licences for all 450 cards
- `assets/cards/artwork_manifest.json` — Machine-readable image metadata and verification status
- `reports/DESI_GUESS_IMAGE_AUDIT.xlsx` & `reports/DESI_GUESS_IMAGE_AUDIT.pdf` — Full 450-card visual audit reports

---

## Credits & Licensing

- **Card Photography**: Verified open-licensed photography sourced from Wikimedia Commons under CC BY, CC BY-SA, CC0, GODL-India, FAL, and Public Domain licences. Full creator attributions and source URLs are listed in [reports/IMAGE_SOURCES_AND_ATTRIBUTION.md](reports/IMAGE_SOURCES_AND_ATTRIBUTION.md).
- **Original Graphics**: 55 cards representing copyrighted characters, trademarked products, or personalities without open-licensed Wikimedia Commons photos use original DESI GUESS card graphics and are flagged for manual verification pending licensed artwork.
- **Repository Licence**: Pending final licence selection by the repository owner (no `LICENSE` file has been added yet).
