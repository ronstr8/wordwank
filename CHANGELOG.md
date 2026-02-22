# Changelog

All notable changes to Wordwank will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

**Note**: We're pre-1.0, so breaking changes happen. It's a feature, not a bug.

## [1.3.0] - 2026-02-22

### Added (1.3.0)

- **Chat History Persistence**: The chat window now remembers and displays the last 50 messages globally. New players can see the recent conversation history upon joining.
  - Added `CHAT_HISTORY_SIZE` environment variable and Helm configuration to make the history limit adjustable.
- **Hunspell Lexicon Converter**: Added `hunspell_to_lexicon.pl` to allow expansion of word lists from Hunspell dictionaries.
  - Automatically filters out proper nouns (capitalized words).
  - Strips Hunspell flags for a clean plain-text lexicon for `wordd`.

### Fixed (1.3.0)

- **Locale Cleanup**: Removed duplicate keys for `rules_summary` and `tile_frequencies` in the German (`de.json`) translation.

## [1.2.0] - 2026-02-22

### Added (1.2.0)

- **Stripe Integration**: Fully integrated Stripe Checkout for donations and subscriptions.
  - Implemented backend payment verification and session fulfillment.
  - Added Stripe credentials to Helm secret management.
- **Invite Friend Feature**: New "🔗 INVITE FRIEND" button in sidebar and header for instant game link sharing.
  - Automatic clipboard copy of unique game invite links.
  - Frontend auto-join logic for invite-parameterized URLs.
- **Hybrid Notifications**:
  - **Discord Webhooks**: Real-time game entry notifications via configurable webhooks.
  - **Email-to-SMS Relay**: Dedicated relay for Mint Mobile (and general SMTP) notifications.
  - Centralized notification setting toggle in backend configuration.

### Improved (1.2.0)

- **Discord OAuth Stability**: Standardized Discord authorization URLs and resolved `unsupported_response_type` errors.
- **Infrastructure Reliability**:
  - Restored correct `nindent` filters in Helm templates to fix label/selector alignment.
  - Sanitized environment variable quoting in `deployment.yaml` to prevent literal quote leakage.
  - Added Workspace Settings (`.vscode/settings.json`) to disable conflicting YAML formatters.

### Fixed (1.2.0)

- **Critical Auth Bug**: Fixed a 500 error where Perl accidentally interpolated `@me` in the Discord user API query, disabling the entire `Auth` controller.

## [0.31.0] - 2026-01-26

### Refactored (0.31.0)

- **Wordd Overhaul**: Complete architectural refactor of the `wordd` service.
  - Split monolithic `main.rs` into `services`, `handlers`, `models`, and `utils`.
  - Optimized language loading (6x fewer allocations).
  - Implemented `Word` struct with `u32` bitmask signatures for high-performance filtering.
  - Decoupled random word generation logic into `services/generator.rs`.

### Fixed (0.31.0)

- **Missed Opportunity Bug**: Fixed random generator failing to suggest words for racks with blank tiles.
  - Added wildcard support (`_`) to letter checks.
  - Replaced unreliable rejection sampling with guaranteed linear scan.
- **Listen Host**: Fixed `wordd` ignoring the `--listen-host` CLI argument.

## [0.30.0] - 2026-01-26

### Fixed (0.30.0)

- **PostgreSQL Permissions**: Resolved persistent storage permission issues by adding an init container that fixes volume ownership before PostgreSQL starts
  - Set `fsGroup: 1001` to match PostgreSQL user
  - Init container runs as root to `chown -R 1001:1001` the data directory
  - Fixed `CrashLoopBackOff` caused by "Permission denied" errors

### Changed (0.30.0)

- **Wordd Letter Validation**: Refactored `contains_all_letters` → `contains_only_letters` with inverted logic
  - Function now validates that words can be formed using _only_ the available letters (subset check), but does _not_ need to use them all
  - Updated all test cases to reflect new semantics
  - Variable renamed from `required` to `available_letters` for clarity

## [0.29.0] - 2026-01-25

### Removed (0.29.0)

- **dictd Service**: Completely eliminated the `dictd` dictionary definition service and all dependencies
  - Removed `dictd` from Helm charts, build system, and deployment configuration
  - Simplified `wordd` service by removing dictionary lookup functionality (~180 lines of code)
  - Word validation endpoints now return simple validation messages instead of dictionary definitions
  - Cleaned up unused imports and dead code from the removal

## [0.28.0] - 2026-01-19

### Added (0.28.0)

- **French Support**: Fully enabled French (FR) lexicography and UI translations. The `wordd` service now handles French dictionary lookups.
- **Frequency-Based Scoring**: Replaced random/static letter values with a dynamic system where points (1-9) are calculated based on letter counts in the "Wank Sock". Common letters are worth less, rare ones more.
- **Smart Game Migration**: Language switching now automatically removes the player from their current game and joins a new one in the target language.
- **WTF Grid Redesign**: Overhauled the letter statistics grid with larger tiles (`80x80`), NW-corner frequencies, and SE-corner scores.
- **Letter Scaling**: Applied custom CSS transforms to game tiles to make letters 30% higher and 20% wider for a premium comic-book look.
- **Privacy Disclaimer**: Added a privacy hint to the top of the login screen regarding anonymous vs. account-based play.

### Changed (0.28.0)

- **i18n Single Source of Truth**: Centralized all localization files to `helm/share/locale/`. Both services now mount a unified ConfigMap, eliminating redundant sync logic.

### Fixed (0.28.0)

- **UI State Persistence**: Fixed a bug where tile values would disappear when switching languages.
- **Backend Broadcaster**: Resolved a critical registration error in the `broadcaster` service that broke event notifications.
- **Timer Formatting**: Fixed the `app.seconds_short` label rendering in the timer component.

## [0.27.0] - 2026-01-19

### Added (0.27.0)

- **Backend Test Suite**: Implemented a comprehensive test suite in `t/scorer.t` for core game logic (scoring, rack generation, word validation).
- **Build-Time Verification**: Integrated Perl `prove` into the backend `Dockerfile` to ensure all tests pass during the container build process.
- **Shared i18n ConfigMap**: Refactored the entire localization system to use a shared Kubernetes ConfigMap. Both frontend and backend now consume unified JSON files from a single source of truth.
- **Hot Reloading**: Enabled hot-reloading for translations. The backend re-scans for changes every 5 minutes, and the frontend fetches locales dynamically via `i18next-http-backend`.
- **Dynamic Tile Values**: Removed hardcoded frontend tile values. Points and frequencies are now served dynamically from the backend based on the specific language configuration.
- **Tile UI/UX Overhaul**: Redesigned the game tiles with a 75% larger font size, corner-aligned letters and values, and improved responsive spacing.
- **Backend Broadcaster**: Implemented a dedicated `Broadcaster` service to handle targeted and exclusionary WebSocket messaging, refining game event distribution.
- **Rack Constraints**: Added configurable `minVowels` and `minConsonants` constraints for game racks, with support for language-specific vowel definitions in locale files.
- **Logo Polish**: Adjusted logo margins to prevent overlap between the "explosion" and text on mobile devices.
- **High-Score Hype**: Increased the volume of the `bigsplat` sound effect to maximum for plays worth 40+ points.

### Changed (0.27.0)

- **Guaranteed Playable Racks**: Enhanced the rack generation algorithm to guarantee at least one vowel and one consonant in every game rack across all languages.
- **Wank-Centric Locales**: Updated the "word not found" error message across English ("We don't wank..."), Spanish ("No pajilleamos..."), and French ("On ne branle pas...") for brand consistency.
- **Multilingual Sync**: Synchronized all frontend and backend translation keys and unified interpolation syntax to `{{variable}}`.

## [0.26.0] - 2026-01-16

### Changed (0.26.0)

- **Toastification**: Replaced the persistent Play-by-Play panel with a modern system of ephemeral toast notifications for all game events.
- **Grouped Join Toasts**: When joining a session, players now see a summarized toast ("X, Y and you start...") instead of individual entries.
- **Elsegame Redirects**: Notifications from other game rooms are now redirected to toasts instead of cluttering the chat window.
- **Cleaner Join UI**: Mid-game joins now use a dedicated toast ("Z joined the duel") and no longer spam the chat history.

### Removed (0.26.0)

- **Play-by-Play Panel**: Completely removed the panel, its state management, toggle buttons, and historical tracking to reduce UI clutter and memory usage.

## [0.25.0] - 2026-01-14

### Changed (0.25.0)

- **Mobile-Friendly Timer**: Transformed the bulky vertical timer into a sleek horizontal line that scales with the tile rack.
- **Improved UI Layout**: Moved the timer below the rack for better mobile UX and preventing accidental clicks.
- **Dynamic Timer Duration**: The timer now dynamically scales its total duration based on server-side configuration instead of being hardcoded.

### Fixed (0.25.0)

- **Rack Scaling**: Resolved an issue where tiles would wrap prematurely on mobile devices.
- **Timer Width Alignment**: Corrected the timer bar's width to precisely match the tiles currently in play.

## [0.24.0] - 2026-01-13

### Added (0.24.0)

- **Donation Feature**: Added a "huggy face" (🤗) icon to the header that opens a donation panel.
- **Configurable PayPal**: The donation link is now configurable via `src/config.js` or `VITE_PAYPAL_EMAIL` environment variable.
- **Player Join Notifications**: Real-time chat messages now broadcast when a player joins the session (with multilingual support).
- **Identity Broadcasting**: Backend now shouts player identities to all clients, ensuring nicknames are correctly mapped in the UI immediately upon joining.

### Fixed (0.24.0)

- **Localization Placeholders**: Resolved issues where backend broadcast messages showed raw keys instead of translated text.
- **Multilingual Sync**: Synchronized English, Spanish, and French localization files with new donation strings and fixed inconsistent interpolation markers.
- **UI Distinctions**: Fixed a bug where identity messages would override the current user's nickname if they originated from another player.

## [0.23.0] - 2026-01-13

### Added (0.23.0)

- **Game Icons**: Added a favicon.ico and manifest to the root of the project.
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

### Fixed (0.21.1)

- **Game Start Hang**: Resolved issue where players could get stuck in "Waiting for game" loop due to stale game rotation logic.
- **Wordd Compilation**: Fixed Rust compilation errors in `wordd` service regarding type ambiguity and mismatches.

### Changed (0.21.1)

- **Language-Partitioned Games**: Players are now strictly matched into games based on their language preference (EN players in EN games, ES players in ES games).
- **Persistent Game Language**: Added `language` column to `games` table to ensure consistent tile distributions and rules for all participants.

## [0.21.0] - 2026-01-11

### Added (0.21.0)

- **Spanish Language Support**: Full Spanish gameplay with 79,489-word dictionary
- **Audio Controls (0.21.0)**: Separated background music (ambience) from master mute
- **UI Button Grouping**: Reorganized header buttons into Account, Audio, and Language groups
- **Locale Selector Enabled**: EN/ES switching in header dropdown

## [0.19.0] - 2026-01-11

### Added (0.19.0)

- **Bottom-Left Resize Handles**: Draggable panels (Leaderboard, Play-by-Play, Chat) now have resize handles on both bottom corners
  - Bottom-right: Expands width and height (original behavior)
  - Bottom-left: Expands width to left and height down while keeping right edge anchored
  - Both handles have visual indicators (yellow triangles) and appropriate cursors

### Changed (0.19.0)

- **End-of-Game Interaction**: Improved UX for results screen
  - Any click or keypress on results screen closes it and joins next game
  - Exception: "Wait, what does [word] mean?" button opens definition modal
  - Definition modal only closes back to results screen (not directly to game)
  - Updated prompt text: "Click anywhere or press any key to play again..."
  - Translations updated in English and Spanish

## [0.18.0] - 2026-01-11

### Added (0.18.0)

- **SSL/HTTPS Support**: Full cert-manager integration with Let's Encrypt for automatic SSL certificate provisioning
  - Supports both staging and production Let's Encrypt environments
  - NAT workaround using hostAliases patch for local Minikube development
  - `make cert-manager-setup` command for one-step installation
  - CoreDNS failover and hostAliases solutions for HTTP-01 validation behind NAT
- **Blank Tiles**: Added 2 blank tiles (`_`) to the game distribution (finally!)
- Translation key `waiting_next_game` for loading state message

### Fixed (0.18.0)

- **Loading State**: Shows "Waiting for next game to start..." when connecting during game transitions instead of blank screen
- **Keyboard Input Bug**: Fixed issue where typing duplicate letters (e.g., "E", "E") would select the same tile twice
  - Keyboard handler now checks `!t.isUsed` to find unused tiles
  - Supports multiple copies of the same letter in rack
- **Solo Game Scoring**: Lifetime scores no longer update when only one player participates (everyone gets 0 points as intended)
- **Auto-Restart Behavior**: Removed 5-second auto-rejoin timer
  - Players must now manually click "Play Again" to start next game
  - Can chat and inspect results freely without being auto-restarted

### Infrastructure (0.18.0)

- **Cert-Manager Resources**:
  - `helm/resources/letsencrypt-issuer.yaml` - ClusterIssuer for staging and production
  - `helm/resources/patch-cert-manager-hosts.sh` - NAT workaround script
  - `helm/resources/coredns-custom.yaml` - DNS override (alternative solution)
- Updated `Makefile` to proxy both HTTP (80) and HTTPS (443) in `expose` target
- Updated README with SSL setup instructions and troubleshooting

### Changed (0.17.1)

- Results screen no longer auto-closes after 5 seconds
- Players have full control over when to start next game

## [0.17.1] - 2026-01-10

### Changed - BREAKING (0.17.1)

- **Fixed Position Tile Rack**: Tiles no longer disappear when selected. Instead, they stay in their original positions and grey out, making the game more challenging as players must remember tile locations

### Added (0.17.1)

- Visual feedback for used tiles (30% opacity, greyscale filter)
- Grid-based rack layout that maintains 7 fixed positions

## [0.17.0] - 2026-01-10

### Changed - BREAKING (0.17.0)

- **Complete Scoring System Overhaul**:
  - **Vowels (A,E,I,O,U)**: Now always worth 1 point
  - **Q and Z**: Always worth 10 points  
  - **Day-of-Week Letter**: First letter of current day in Buffalo, NY timezone is worth 7 points (e.g., "F" on Friday)
  - **Other Letters**: Random value between 2-9, changes every game
  - **Duplicate Penalty**: Players who submit duplicate words get 0 points (original player still gets +1 bonus)
  - **Solo Player Rule**: If only one player submits in a game, everyone gets 0 points
  - **All Tiles Bonus**: Unchanged, still +10 points for using all 7 tiles

### Added (0.17.0)

- **DUPLICATE Badge**: Dupers are now marked with a red "DUPLICATE" badge in results screen
- Day-letter calculation uses Buffalo, NY timezone (America/New_York) for consistency

### Fixed (0.17.0) (0.17.0)

- Backend now properly handles edge cases for scoring bonuses

## [0.16.0] - 2026-01-10

### Added (0.16.0)

- **Lifetime Score Tracking**: Players now have a `lifetime_score` column that tracks cumulative points across all games
- **Duplicate Word Bonus**: Original player gets +1 point for each other player who submits the same word
- **All Tiles Bonus**: +10 point bonus for using all 7 tiles in a single word
- **Chat Panel**: Re-enabled chat interface with toggle button in header
- **Panel Persistence**: Panel positions, sizes, and visibility states now persist in localStorage
- **Bonus Display**: End-game results now show detailed breakdowns of "Duplicates" and "All Tiles" bonuses

### Fixed (0.16.0)

- **End-of-Game Splash**: Fixed critical bug where results screen wasn't showing due to incorrect player ID usage
- **Logo Display**: Fixed "wordw💥nk" logo breaking across lines on mobile with `white-space: nowrap`
- **Scoring Accuracy**: Backend now correctly uses player IDs for database lookups instead of nicknames

### Changed (0.16.0) (0.16.0)

- **Database Schema v0.2.0**: Added `lifetime_score INTEGER` column to `players` table
- Tile value font size increased from `clamp(0.6rem, 1.2vw, 1rem)` to `clamp(0.75rem, 1.5vw, 1.2rem)` for better mobile readability
- Panels (Leaderboard, Play-by-Play, Chat) now hidden by default and toggleable via header buttons

## [0.15.7] - 2026-01-08

### Added (0.15.7)

- **Per-Letter Randomization**: Each letter now gets its own unique random value (1-10) in Random Score Mode, rather than a single value for the whole game.
- **WebSocket Reconnection**: The frontend now automatically attempts to reconnect if the connection is lost (e.g., after tabbing away).
- **Tab Visibility Sync**: Connection is automatically checked and refreshed when you return to the tab.
- **Empty State UX**: Added a "NO PLAYS THIS ROUND!" message on the results screen when no one submits a word.

### Fixed (0.15.7) (0.15.7)

- **Stability**: Fixed a syntax error in the frontend message loop.
- **Config**: Ensure `tilemasterd` correctly receives the randomization flag.

## [0.15.6] - 2026-01-08

### UI Improvements

- **Empty Round Message**: Added a friendly "NO PLAYS THIS ROUND!" message on the results screen.
- **Styling**: New centered empty state for the results leaderboard.

## [0.15.5] - 2026-01-08

### Backend Fixes (0.15.5)

- **Grace period for auto-submit**: The server now waits 1.5s after the timer hits 0 before ending the game.
- **True randomness**: Switched to `math/rand` with a nanosecond seed.

### Helm Fixes (0.15.5)

- **Random Letter Score Mode**: Corrected Helm config inheritance.
- **Log Hygiene**: Refactored CHANGELOG to resolve lint errors.

## [0.15.4] - 2026-01-08

### Features Added

- 🧹 **Clear button** next to Jumble to instantly return all tiles to your rack.
- Updated rack action styles.

## [0.15.3] - 2026-01-08

### UX Fixes (0.15.3)

- **Submission Reliability**: Auto-submit now properly triggers when timer expires.
- **Navigation UX**: Results modal can now be clicked anywhere to close.
- **Interactive Definitions**: Definition button click opens modal without closing results screen.

## [0.15.2] - 2026-01-08

### Crash Fixes (0.15.2)

- **Startup Stability**: Critical circular dependency crash when clearing site data fixed.
- **Message Integrity**: Auto-submit logic now inlines WebSocket send.

## [0.15.1] - 2026-01-08

### Timer Fixes (0.15.1)

- **Bug Fix**: Auto-submit on timer expiration now works correctly.
- **React Optimization**: Fixed React dependency arrays.

## [0.15.0] - 2026-01-08

### Added (0.15.0)

- 🔀 **Jumble button** to shuffle rack tiles for word brainstorming
- **Auto-submit** when timer expires (no more losing because you didn't hit Enter in time)
- **Server-side timer broadcasts** for synchronized countdowns across all clients

### Fixed (0.15.0)

- Timer desync issues where frontend would show different time than server
- Random letter score mode now properly parses boolean config values

## [0.14.4] - 2026-01-08

### Fixed

- Chat messages now display procedural nicknames instead of player IDs
- Gateway properly enhances chat payloads with `senderName` before broadcasting

## [0.14.3] - 2026-01-08

### Added (0.14.3)

- **WebSocket error handling** with user-friendly error messages
- **Connection timeout** (10 seconds) with reload button for recovery
- Generic loading screen (removed Arkham/cosmic horror branding)

### Fixed (0.14.3)

- Stuck "Connecting..." overlay when WebSocket fails to establish

## [0.14.2] - 2026-01-08

### Added (0.14.2)

- **Server-side player name tracking** in gateway
- Player names now included in play/chat message payloads
- Results screen displays nicknames instead of IDs

### Fixed (0.14.2)

- Player nicknames now appear correctly in all UI panels (play-by-play, results, chat)

## [0.14.1] - 2026-01-08

### Added (0.14.1)

- **Configurable game duration** via `gameDuration` in values.yaml (default: 30 seconds)
- Player nickname mapping system for consistent identity across features

### Fixed (0.14.1)

- Definition modal can now be clicked without closing results screen
- Improved dependency handling in React hooks

## [0.14.0] - 2026-01-08

### Added (0.14.0)

- 🔊 **Sound system** with 4 audio effects:
  - `placement.mp3` - Satisfying click for each tile placed
  - `buzzer.mp3` - Error feedback for invalid actions
  - `bigsplat.mp3` - Epic explosion when game ends
  - `ambience.mp3` - Looping background atmosphere
- **Mute button** (🔊/🔇) in top-right corner with localStorage persistence
- Sound credits in README for Freesound community contributions

### Changed (0.14.0)

- All sounds use MP3 format for optimal web performance

## [0.13.2] - 2026-01-08

### Added (0.13.2)

- **Visual indicator for blank tiles** (greyed-out appearance)
- Robust keyboard input using React refs to prevent rapid-typing race conditions

### Fixed (0.13.2)

- Blank tile handling during fast keyboard entry
- Tile exhaustion checks now work correctly during rapid word building

## [0.13.1] - 2026-01-08

### Added (0.13.1)

- **Random letter score mode** (configurable via `randomLetterScoreMode`)
  - Each game assigns a random value (1-10) to all letters for that round
  - Shifts strategy from letter rarity to word length
  - Blank tiles always worth 0 points

### Changed (0.13.1)

- Tile component now accepts optional `value` prop for score override

## [0.13.0] - 2026-01-08

### Added (0.13.0)

- 🎮 **Game Factory pattern** - ensures at least one game always available
- **Procedural username generation** using AdjectiveNoun hashing (e.g., "GroovyPanda", "FunkyWizard")
- **Configurable max players** per game via `maxPlayers` in values.yaml
- **Persistent chat** across game sessions for player relationship building
- **Instant typing mode** - keyboard input active immediately after tiles dealt
- Backspace and Enter support for word manipulation
- Visual focus cue (pulsing animation) on first empty word slot
- Seamless game transitions (no page reloads)

### Changed (0.13.0)

- Frontend version tracking system
- Player registration now uses procedural nicknames
- Results screen uses callback instead of page reload

## Earlier Versions

Versions prior to 0.13.0 were experimental builds during initial development.
The game has evolved significantly since then, including the core architecture
transition to a microservices pattern with Go, Rust, Java, and React.

---

_Remember: If you find a bug, it's a surprise mechanic. If you like a feature, it was intentional all along._
