# Changelog

All notable changes to Wordwank will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

**Note**: We're pre-1.0, so breaking changes happen. It's a feature, not a bug.

## [0.23.0] - 2026-01-13

### Added (0.23.0)

- **Global Win Broadcasts**: When a game ends, the winner's word and score are announced globally to all connected clients on the server.
- **Persistent Play-by-Play**: The game mechanics log now persists across multiple games, with a "--- New Game Started ---" separator to maintain context.
- **Session Join Notifications**: Real-time system messages notify all players in a game when a new participant joins the session.
- **Explosion Favicon Suite**: Implemented a professional, "comic-book explosion" (💥) themed favicon suite under `.well-known/`.
- **Keyboard Listener Hardening**: Global key listeners now strictly ignore inputs, textareas, and content-editable areas to avoid conflicts with external UI elements (like IDE chats).
- **Anti-sniffing measures**: Obfuscated the played word in real-time broadcasts while revealing the base score, balancing hype with fairness.
- **Configurable Rack Size**: Added `RACK_SIZE` environment variable support (defaults to 7).
- **Dynamic Doubling Bonuses**: +5 for 6 letters, doubling for each additional letter.
- **Unique Word Bonus**: +5 point bonus for playing a word that no other player duplicated.
- **Discursive Results Display**: Detailed score breakdowns in the end-game results.

### Fixed (0.23.0)

- **Solo Game Robustness**: Ensured solo game scores never persist to lifetime totals, even if state is manipulated.
- **Resilient Game Prep**: Background pre-population now uses better PRNG seeding (`/dev/urandom`) and has enhanced error handling for race conditions.

## [0.21.1] - 2026-01-11

### Fixed

- **Game Start Hang**: Resolved issue where players could get stuck in "Waiting for game" loop due to stale game rotation logic.
- **Wordd Compilation**: Fixed Rust compilation errors in `wordd` service regarding type ambiguity and mismatches.

### Changed

- **Language-Partitioned Games**: Players are now strictly matched into games based on their language preference (EN players in EN games, ES players in ES games).
- **Persistent Game Language**: Added `language` column to `games` table to ensure consistent tile distributions and rules for all participants.

## [0.21.0] - 2026-01-11

### Added

- **Spanish Language Support**: Full Spanish gameplay with 79,489-word dictionary
- **Audio Controls**: Separated background music (ambience) from master mute
- **UI Button Grouping**: Reorganized header buttons into Account, Audio, and Language groups
- **Locale Selector Enabled**: EN/ES switching in header dropdown

## [0.19.0] - 2026-01-11

### Added

- **Bottom-Left Resize Handles**: Draggable panels (Leaderboard, Play-by-Play, Chat) now have resize handles on both bottom corners
  - Bottom-right: Expands width and height (original behavior)
  - Bottom-left: Expands width to left and height down while keeping right edge anchored
  - Both handles have visual indicators (yellow triangles) and appropriate cursors

### Changed

- **End-of-Game Interaction**: Improved UX for results screen
  - Any click or keypress on results screen closes it and joins next game
  - Exception: "Wait, what does [word] mean?" button opens definition modal
  - Definition modal only closes back to results screen (not directly to game)
  - Updated prompt text: "Click anywhere or press any key to play again..."
  - Translations updated in English and Spanish

## [0.18.0] - 2026-01-11

### Added

- **SSL/HTTPS Support**: Full cert-manager integration with Let's Encrypt for automatic SSL certificate provisioning
  - Supports both staging and production Let's Encrypt environments
  - NAT workaround using hostAliases patch for local Minikube development
  - `make cert-manager-setup` command for one-step installation
  - CoreDNS failover and hostAliases solutions for HTTP-01 validation behind NAT
- **Blank Tiles**: Added 2 blank tiles (`_`) to the game distribution (finally!)
- Translation key `waiting_next_game` for loading state message

### Fixed

- **Loading State**: Shows "Waiting for next game to start..." when connecting during game transitions instead of blank screen
- **Keyboard Input Bug**: Fixed issue where typing duplicate letters (e.g., "E", "E") would select the same tile twice
  - Keyboard handler now checks `!t.isUsed` to find unused tiles
  - Supports multiple copies of the same letter in rack
- **Solo Game Scoring**: Lifetime scores no longer update when only one player participates (everyone gets 0 points as intended)
- **Auto-Restart Behavior**: Removed 5-second auto-rejoin timer
  - Players must now manually click "Play Again" to start next game
  - Can chat and inspect results freely without being auto-restarted

### Infrastructure

- **Cert-Manager Resources**:
  - `helm/resources/letsencrypt-issuer.yaml` - ClusterIssuer for staging and production
  - `helm/resources/patch-cert-manager-hosts.sh` - NAT workaround script
  - `helm/resources/coredns-custom.yaml` - DNS override (alternative solution)
- Updated `Makefile` to proxy both HTTP (80) and HTTPS (443) in `expose` target
- Updated README with SSL setup instructions and troubleshooting

### Changed

- Results screen no longer auto-closes after 5 seconds
- Players have full control over when to start next game

## [0.17.1] - 2026-01-10

### Changed - BREAKING

- **Fixed Position Tile Rack**: Tiles no longer disappear when selected. Instead, they stay in their original positions and grey out, making the game more challenging as players must remember tile locations

### Added

- Visual feedback for used tiles (30% opacity, greyscale filter)
- Grid-based rack layout that maintains 7 fixed positions

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
