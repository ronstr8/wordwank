# Changelog

All notable changes to Wordwank will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

**Note**: We're pre-1.0, so breaking changes happen. It's a feature, not a bug.

## [Unreleased]

- Nothing yet. Go play a round!

## [0.15.3] - 2026-01-08

### Fixed

- Auto-submit now properly triggers when timer expires (added ref flag and `<= 0` check)
- Results modal can now be clicked anywhere to close (except when viewing definition)
- Definition button click opens modal without closing results screen

## [0.15.2] - 2026-01-08

### Fixed

- Critical circular dependency crash when clearing site data (removed `submitWord` from useEffect dependencies)
- Auto-submit logic now inlines WebSocket send to avoid React closure issues

## [0.15.1] - 2026-01-08

### Fixed

- Auto-submit on timer expiration now works correctly (fixed stale closure in useEffect)
- React dependency array now includes all necessary values for auto-submit logic

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
