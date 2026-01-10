# Changelog

All notable changes to Wordwank will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

**Note**: We're pre-1.0, so breaking changes happen. It's a feature, not a bug.

## [Unreleased]

- Nothing yet. Go play a round!

## [0.17.0] - 2026-01-10

### Changed - BREAKING

- **Complete Scoring System Overhaul**:
  - **Vowels (A,E,I,O,U)**: Now always worth 1 point
  - **Q and Z**: Always worth 10 points  
  - **Day-of-Week Letter**: First letter of current day in Buffalo, NY timezone is worth 7 points (e.g., "F" on Friday)
  - **Other Letters**: Random value between 2-9, changes every game
  - **Duplicate Penalty**: Players who submit duplicate words get 0 points (original player still gets +1 bonus)
  - **Solo Player Rule**: If only one player submits in a game, everyone gets 0 points
  - **All Tiles Bonus**: Unchanged, still +10 points for using all 7 tiles

### Added

- **DUPLICATE Badge**: Dupers are now marked with a red "DUPLICATE" badge in results screen
- Day-letter calculation uses Buffalo, NY timezone (America/New_York) for consistency

### Fixed

- Backend now properly handles edge cases for scoring bonuses

## [0.16.0] - 2026-01-10

### Added

- **Lifetime Score Tracking**: Players now have a `lifetime_score` column that tracks cumulative points across all games
- **Duplicate Word Bonus**: Original player gets +1 point for each other player who submits the same word
- **All Tiles Bonus**: +10 point bonus for using all 7 tiles in a single word
- **Chat Panel**: Re-enabled chat interface with toggle button in header
- **Panel Persistence**: Panel positions, sizes, and visibility states now persist in localStorage
- **Bonus Display**: End-game results now show detailed breakdowns of "Duplicates" and "All Tiles" bonuses

### Fixed

- **End-of-Game Splash**: Fixed critical bug where results screen wasn't showing due to incorrect player ID usage
- **Logo Display**: Fixed "wordw💥nk" logo breaking across lines on mobile with `white-space: nowrap`
- **Scoring Accuracy**: Backend now correctly uses player IDs for database lookups instead of nicknames

### Changed

- **Database Schema v0.2.0**: Added `lifetime_score INTEGER` column to `players` table
- Tile value font size increased from `clamp(0.6rem, 1.2vw, 1rem)` to `clamp(0.75rem, 1.5vw, 1.2rem)` for better mobile readability
- Panels (Leaderboard, Play-by-Play, Chat) now hidden by default and toggleable via header buttons

## [0.15.7] - 2026-01-08

### Added

- **Per-Letter Randomization**: Each letter now gets its own unique random value (1-10) in Random Score Mode, rather than a single value for the whole game.
- **WebSocket Reconnection**: The frontend now automatically attempts to reconnect if the connection is lost (e.g., after tabbing away).
- **Tab Visibility Sync**: Connection is automatically checked and refreshed when you return to the tab.
- **Empty State UX**: Added a "NO PLAYS THIS ROUND!" message on the results screen when no one submits a word.

### Fixed

- **Stability**: Fixed a syntax error in the frontend message loop.
- **Config**: Ensure `tilemasterd` correctly receives the randomization flag.

## [0.15.6] - 2026-01-08

### UI Improvements

- **Empty Round Message**: Added a friendly "NO PLAYS THIS ROUND!" message on the results screen.
- **Styling**: New centered empty state for the results leaderboard.

## [0.15.5] - 2026-01-08

### Backend Fixes

- **Grace period for auto-submit**: The server now waits 1.5s after the timer hits 0 before ending the game.
- **True randomness**: Switched to `math/rand` with a nanosecond seed.

### Helm Fixes

- **Random Letter Score Mode**: Corrected Helm config inheritance.
- **Log Hygiene**: Refactored CHANGELOG to resolve lint errors.

## [0.15.4] - 2026-01-08

### Features Added

- 🧹 **Clear button** next to Jumble to instantly return all tiles to your rack.
- Updated rack action styles.

## [0.15.3] - 2026-01-08

### UX Fixes

- **Submission Reliability**: Auto-submit now properly triggers when timer expires.
- **Navigation UX**: Results modal can now be clicked anywhere to close.
- **Interactive Definitions**: Definition button click opens modal without closing results screen.

## [0.15.2] - 2026-01-08

### Crash Fixes

- **Startup Stability**: Critical circular dependency crash when clearing site data fixed.
- **Message Integrity**: Auto-submit logic now inlines WebSocket send.

## [0.15.1] - 2026-01-08

### Timer Fixes

- **Bug Fix**: Auto-submit on timer expiration now works correctly.
- **React Optimization**: Fixed React dependency arrays.

## [0.15.0] - 2026-01-08

### Added

- 🔀 **Jumble button** to shuffle rack tiles for word brainstorming
- **Auto-submit** when timer expires (no more losing because you didn't hit Enter in time)
- **Server-side timer broadcasts** for synchronized countdowns across all clients

### Fixed

- Timer desync issues where frontend would show different time than server
- Random letter score mode now properly parses boolean config values

## [0.14.4] - 2026-01-08

### Fixed

- Chat messages now display procedural nicknames instead of player IDs
- Gateway properly enhances chat payloads with `senderName` before broadcasting

## [0.14.3] - 2026-01-08

### Added

- **WebSocket error handling** with user-friendly error messages
- **Connection timeout** (10 seconds) with reload button for recovery
- Generic loading screen (removed Arkham/cosmic horror branding)

### Fixed

- Stuck "Connecting..." overlay when WebSocket fails to establish

## [0.14.2] - 2026-01-08

### Added

- **Server-side player name tracking** in gateway
- Player names now included in play/chat message payloads
- Results screen displays nicknames instead of IDs

### Fixed

- Player nicknames now appear correctly in all UI panels (play-by-play, results, chat)

## [0.14.1] - 2026-01-08

### Added

- **Configurable game duration** via `gameDuration` in values.yaml (default: 30 seconds)
- Player nickname mapping system for consistent identity across features

### Fixed

- Definition modal can now be clicked without closing results screen
- Improved dependency handling in React hooks

## [0.14.0] - 2026-01-08

### Added

- 🔊 **Sound system** with 4 audio effects:
  - `placement.mp3` - Satisfying click for each tile placed
  - `buzzer.mp3` - Error feedback for invalid actions
  - `bigsplat.mp3` - Epic explosion when game ends
  - `ambience.mp3` - Looping background atmosphere
- **Mute button** (🔊/🔇) in top-right corner with localStorage persistence
- Sound credits in README for Freesound community contributions

### Changed

- All sounds use MP3 format for optimal web performance

## [0.13.2] - 2026-01-08

### Added

- **Visual indicator for blank tiles** (greyed-out appearance)
- Robust keyboard input using React refs to prevent rapid-typing race conditions

### Fixed

- Blank tile handling during fast keyboard entry
- Tile exhaustion checks now work correctly during rapid word building

## [0.13.1] - 2026-01-08

### Added

- **Random letter score mode** (configurable via `randomLetterScoreMode`)
  - Each game assigns a random value (1-10) to all letters for that round
  - Shifts strategy from letter rarity to word length
  - Blank tiles always worth 0 points

### Changed

- Tile component now accepts optional `value` prop for score override

## [0.13.0] - 2026-01-08

### Added

- 🎮 **Game Factory pattern** - ensures at least one game always available
- **Procedural username generation** using AdjectiveNoun hashing (e.g., "GroovyPanda", "FunkyWizard")
- **Configurable max players** per game via `maxPlayers` in values.yaml
- **Persistent chat** across game sessions for player relationship building
- **Instant typing mode** - keyboard input active immediately after tiles dealt
- Backspace and Enter support for word manipulation
- Visual focus cue (pulsing animation) on first empty word slot
- Seamless game transitions (no page reloads)

### Changed

- Frontend version tracking system
- Player registration now uses procedural nicknames
- Results screen uses callback instead of page reload

## Earlier Versions

Versions prior to 0.13.0 were experimental builds during initial development.
The game has evolved significantly since then, including the core architecture
transition to a microservices pattern with Go, Rust, Java, and React.

---

*Remember: If you find a bug, it's a surprise mechanic. If you like a feature, it was intentional all along.*
