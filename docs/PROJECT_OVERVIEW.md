# Project Overview — Desi Guess

## Objectives & Vision

**Desi Guess** is an Indian cultural adaptation of classic two-player deduction board games (*Who / What / Where*). Its goal is to deliver a fast, tactile, visually polished mobile party game tailored to Indian pop culture, cuisine, landmarks, sports, and everyday life—playable anywhere without requiring an internet connection or accounts.

---

## Game Concept & Target Audience

- **Concept**: Two players share one phone, view a randomized 10-card board, receive hidden secret cards, ask unlimited verbal Yes/No questions, tap to eliminate or restore suspects on their own board, and lock in a Final Guess while managing 5 hearts.
- **Target Audience**: Friends, families, college groups, travelers, and casual Indian mobile gamers looking for quick 3–8 minute face-to-face deduction rounds.

---

## Built-In Categories (450 Cards Across 24 Packs)

| Category | Built-In Cards | Subcategory Packs |
|---|---:|---|
| **WHO** | 250 | Bollywood Actors, Bollywood Actresses, Indian Cricketers, Indian Influencers, Indian Politicians, Indian Singers, Indian Cartoon Characters, Indian TV Personalities, Indian Sports Personalities, Indian Meme Personalities |
| **WHAT** | 128 | Indian Food, Indian Brands, Vehicles, Bollywood Movies, Household Objects, Technology, Indian Snacks, Popular Products |
| **WHERE** | 72 | Indian Cities, Tourist Attractions, Indian States, Famous Monuments, Colleges & Universities, Popular Destinations |
| **CUSTOM** | User-created | Offline player-created custom boards and cards stored locally in Hive |

---

## Core Features (Current Release: Local Edition)

- **Single-Device Local Pass-and-Play** with customizable player names (`Player 1` & `Player 2`).
- **Balanced 10-Card Random Board Generation** mixing multiple subcategories automatically without forcing subcategory picks.
- **Privacy Handoff Screens** hiding the board and secret card between turns.
- **Five-Heart Final Guess System** with automatic turn switching on incorrect guesses and zero-heart elimination.
- **Offline Persistence** via Hive & SharedPreferences (active match resume, player stats, achievements, match history, custom boards).
- **Bilingual Support** for English and Hinglish, plus bundled offline WAV sound effects and haptics.

---

## Supported Platforms

| Platform | Status |
|---|---|
| **Android** | Primary target; builds cleanly in FlutLab and Flutter CLI (Gradle `8.10.2`, AGP `8.7.3`, Kotlin `2.1.0`) |
| **iOS** | Project configuration preserved intact for macOS + Xcode builds |
| **Web** | Compatible for preview builds (`lib/` avoids unconditional `dart:io` imports) |

---

## Current Development Status & Limitations

- **Local-Only Release**: Online multiplayer, room codes, real-time Firestore chat, friend invitations, cloud accounts, and global leaderboards are intentionally disabled via `FeatureFlags.enableOnlineMultiplayer = false` and `kEnableFirebase = false`.
- **Image Library Status**:
  - 450 total cards (`WHO: 250`, `WHAT: 128`, `WHERE: 72`).
  - **280** originally correct images retained and visually verified.
  - **115** confirmed mismatched/duplicate/low-quality images replaced with visually verified open-licensed Wikimedia Commons images.
  - **55** cards (primarily copyrighted cartoon characters, niche internet creators, trademarked brands/snacks, and films without free-licensed Commons photos) use clean original DESI GUESS typographic cards and are explicitly flagged **Manual Verification Required**—they do **not** claim to depict the real likeness/artwork of those subjects until official licensed assets are supplied.

---

## Future Development Roadmap

1. **Licensed Artwork Completion**: Replace the 55 flagged cards with officially licensed artwork or updated card entries.
2. **Online Multiplayer Restoration**: Re-enable the preserved Firebase implementation (`FeatureFlags.defaultEnableOnlineMultiplayer = true` + `--dart-define=ENABLE_FIREBASE=true`), deploy `firestore.rules`, `storage.rules`, and `functions/`, and unlock 6-letter rooms, live chat, friend invites, cloud-synced custom boards, and global leaderboards.
3. **Expanded Regional Packs**: Add South Indian cinema, regional street food, and festival-themed packs.
4. **Play Store & App Store Publishing**: Release signing, Play Integrity / App Check activation, and store assets.
