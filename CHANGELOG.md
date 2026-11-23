# Changelog

All notable changes to Logodal will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- **Commit-Tagged Images**: Service images are tagged with the commit they were built from instead of the app version, and the rules footer shows that commit. Each build is kept, so a service can be rolled back to an earlier image, and new text reaches returning players without a hard refresh.
- **Wordwank Leader Title**: The Wordwank leader is now the "Wankmaster" in every language, replacing "apex wanker" and its native-slang counterparts.

## [3.1.0] - 2026-11-16

### Added (3.1.0)

- **Guest Play**: Players can start without signing in and get a generated nickname.
- **AI Small Talk**: AI players greet newcomers, compliment strong plays and congratulate the winner, using the language model. When the model is unavailable they stay quiet (canned filler only with `IDLE_CHATTER`), and their output is trimmed to one short line so a weak model can't leak its prompt into chat.
- **Multiple Backend Replicas**: Redis carries game events between backend instances, so the backend can run with more than one replica.
- **Wordwank Brand**: The game now also runs as Wordwank on wordwank.com, the original whimsical look (sunflower on midnight blue, Luckiest Guy lettering, its own logo and "W" tile icons). Both sites share one game pool, so Logodal and Wordwank players meet at the same tables.
- **Wordwank Wording**: Wordwank has its own cruder wording in all six languages, using native slang rather than literal translations, layered over the shared text.
- **Wordwank Bots**: Wanko, Fapsworth and Tugz play on Wordwank, each with that brand's voice. A bot speaks in its own brand's voice to everyone at a mixed table.
- **Brand Badges**: A small brand icon beside each player's name in chat, pop-up messages and results shows which site they're playing from.
- **Wordwank Icons**: Wordwank has its own favicon, Apple touch icon and installable app icons (including maskable ones), generated from the logo tile by `assets/logo/generate.sh`.
- **Per-Site Branding**: nginx serves each site's own page title, theme colour, icons, web manifest and link-preview (og:) tags based on the host name, so logodal.com and wordwank.com look like separate sites when shared or installed.
- **Duplicate Squawk**: A squawk plays at the end of a round when anyone played a duplicated word.
- **Play Feed**: Plays now appear in a one-line strip across the top of the page instead of slide-outs over the rack, with an ellipsis between plays and a centre dot after the end-of-round notice. Choose Off, Fade (one still line that fades to the next play) or Scroll (a ticker that pauses on hover or tap) from the header button or the menu. Scroll is the default, or Fade if your device asks for reduced motion. When plays pile up at the end of a round, the feed speeds up and folds them into "Wanko, Tugz +3 played words" so it doesn't fall behind.

### Changed (3.1.0)

- **No Chat Pop-ups**: Chat messages no longer slide out over the game; read them in the Messages panel.
- **Bigger Logodal Logo**: The LOGODAL wordmark is larger beside its tile, and on phones the logo grows with the screen width (up to 48px tall) to fill the header.
- **Wordwank Logo**: The tile now appears before the wordmark, the logo is bigger on phones, and the letters are centred on the tile. On the login screen it shrinks to fit the card.
- **Rack of 7**: Racks have 7 tiles instead of 8. The full-rack bonus, submit sounds and rules text all follow the configured rack size.
- **Length Bonus**: Words of 5 letters or more earn a length bonus of +10, doubling with each extra letter (+20 for 6, +40 for 7). The starting length and base amount are configurable, and the rules and help panel show the live values.
- **Help Panel Tile Values**: The tile grid shows each letter's normal value, so the mutant letter no longer appears as 10.
- **Mutant Letter Every Game**: A rack tile mutates in every game, with no conditions to earn it. The rules text in all six languages says so.
- **Leader Title**: The leader is now "the apex logodal" (was "the Daedalus").
- **AI Players Join by Schedule**: Each AI joins on its schedule (75% of games) or by its own join chance, then sits out for a cooldown, instead of every AI joining every game.
- **Tiles**: Tile letters and values use Cinzel to match the library theme, scale down on small screens so they don't overlap, and the mutant tile pulses. The tile look was refined and all favicons now show the lambda tile.
- **Results Panel**: The end-of-round results panel was redesigned.
- **External Ollama**: The Helm chart no longer bundles Ollama; AI chat uses a separate shared Ollama server.
- **AI Chat Model**: AI players chat using gemma3:12b (was llama3.1:8b).
- **Fewer Admin Alerts**: The Discord/SMS "started playing" alert is only sent when no one has joined for the past 5 minutes, instead of every time someone joins.

### Removed (3.1.0)

- **Passkeys**: The unfinished passkey sign-in from 3.0.0 is gone; sign in with Google or Discord, or play as a guest.
- **Game Over Sound**: The sound at the end of every round is gone; only the duplicate squawk remains.
- **Unique Word Bonus**: Playing a word nobody else played no longer earns a bonus. It was applied unevenly (the winner forfeited it) and rarely changed the outcome. The rules text and help panel no longer mention it.

### Fixed (3.1.0)

- **Word Slot Bonus Badges**: The glowing bonus slots and their "+N" badges now match the real length bonus. They used to start one slot late and show half the points (+5 from the 6th letter instead of +10 from the 5th).
- **Games Across Replicas**: With several backend replicas, a game is no longer ended twice or timed by more than one replica; the replica that started a game runs its timer and AIs.
- **Perdix and Daedalus**: Only Icarus ever joined games because of a misnamed setting; Perdix now joins about 35% of games and Daedalus about 10%.
- **Missing-Letters Error**: Playing a word with letters not on your rack showed a raw `error.missing_letters` key; it now shows a real message in every language.
- **AI Chat Off Switch**: Leaving the Ollama address unset now really turns AI chat off.
- **Word Service Crash Loop**: A build caching problem could ship a wordd image that exited immediately on start.
- **Russian Games**: The Russian word list had been emptied by a filter that kept only Latin letters, so Russian showed no word count and couldn't deal Cyrillic tiles. It is restored (about 150,000 playable words), and a temporary failure to reach the word service is no longer remembered until the next restart.

## [3.0.0] - 2026-05-11

### Changed (3.0.0)

- **Complete Rebrand: Wordwonk → Logodal**: Renamed the project, all namespaces, Docker images, Helm charts, database names, and locale keys from Wordwonk to Logodal. Deployed to [logodal.com](https://logodal.com) with Let's Encrypt TLS via cert-manager.
- **Logodal SVG Logo**: Replaced plain text headers with an inline SVG React component (`LogodalLogo`) featuring the amber-tiled Logodal wordmark. Used in both the game header and login screen. Fully responsive via CSS at mobile breakpoints.
- **Leader Title**: Corrected the in-game identity label to "You are the Daedalus" (was showing an incorrect fallback string).
- **Play Score Notification**: Word submission notifications now read "worth at least {points}" to clarify that the displayed score is the raw letter value before strategy bonuses are applied.
- **Help Button Localization**: Renamed the "WTF" button to "Help" across all six supported locales (en, es, fr, de, ru, el).

### Added (3.0.0)

- **Passkey Authentication**: Full WebAuthn/passkey support via `Authen::WebAuthn`. Players can register and sign in with device-bound passkeys. Registration requires an active OAuth session; authentication is fully standalone.
- **Greek Locale**: Added Greek (`el`) as a supported UI language.

### Fixed (3.0.0)

- **Ctrl+R / Ctrl+Shift+R Intercepted**: The global keyboard handler was capturing modifier-key combos, preventing browser reload. Now exits early when `Ctrl` or `Meta` is held.
- **Messages Panel Auto-Scroll**: The chat history panel failed to scroll to new messages because `scrollRef` was attached to an inner container while the parent `.panel-body` was the actual scroll root. Fixed by wrapping `MessageList` in a `.messages-container` div, activating the existing CSS `:has()` rule that disables scroll on `.panel-body` and makes `.chat-history` the sole scroll container.
- **AI Player Names**: Stale persistent volume data retained old AI player records (Flash, Wanko). Replaced with the correct AI opponents: Icarus and Perdix.

## [2.0.0] - 2026-04-23

### Added (2.0.0)

- **Mutant Letter**: When every player in the most recently completed multi-player game earned at least one bonus (length, unique word, quick play, or duplicate), a randomly chosen tile in the new game's rack mutates. It glows green with a subtle throb animation and is worth 10 points — regardless of its normal value. Natural selection amongst all logodals, past and future.
- **Logodal Banner**: The Stats panel now opens with a prominent banner identifying the current #1 player by lifetime score ("The Logodal is..."), along with the last word they played in a finished game and a live-updating relative timestamp (e.g. "knife (3m ago)").

### Changed (2.0.0)

- **Duplicate Bonus Rebalanced**: The original player of a duplicated word now earns the full raw letter value of that word per copy, replacing the previous flat +2 per copy. Rare, high-value words are now properly rewarded when others steal them.

## [1.14.0] - 2026-04-16

### Changed (1.14.0)

- **Frontend Architecture Overhaul**: Refactored the monolithic `App.jsx` (~1150 lines) into a modular, hook-based architecture, reducing primary component size by 70%.
- **Custom Hooks Ecosystem**: Introduced specialized hooks (`usePlayerAuth`, `useGameState`, `useGameSocket`, `useGameController`, `useInteractionHandler`) to cleanly separate network I/O, game state, and user interaction logic.
- **Component Decomposition**: Extracted `GameHeader` and `GameArea` into dedicated, reusable components to improve UI maintainability.
- **Backend Configuration Hardening**: Refactored `Logodal::Game::StateProcessor` to utilize Moose attributes for scoring rules, enabling dependency injection and decoupling critical game logic from environment variables.
- **Rust Service Modularization**: Extracted state bootstrapping in the `wordd` service into dedicated functions, cleaning up `main.rs` and improving startup orchestration.

### Fixed (1.14.0)

- **Service Robustness**: Replaced panic-prone `unwrap()` calls in the Rust word service with graceful error handling, ensuring informative failures if word lists are missing or misconfigured.
- **Config Syntax**: Hardened `StateProcessor` attribute defaults in Perl to use safer defined-or (`//`) checks.

## [1.13.0] - 2026-04-16

### Added (1.13.0)

- **Cloud Portability**: Helm chart now supports both local homelab (manual PV) and cloud provider storage via `global.storageClass` and `global.persistence.manualPV` toggles.
- **Automated Backups**: Implemented `make backup` and secure `scripts/backup-db.sh` using Kubernetes secrets for dynamic credential fetching.
- **AI Competitive Scoring**: AI opponents now count toward leaderboard eligibility, allowing solo players to progress against the system (controllable via `global.scoreAgainstAI`).
- **Configurable Logic**: Added `global.scoreAgainstAI` toggle to `values.yaml` to switch between relaxed (AI counts) and strict (2 humans required) scoring.

### Fixed (1.13.0)

- **Volume Permissions**: Switched to `busybox:latest` for volume permission init containers to resolve image pull failures in restricted environments.
- **Database Restoration**: Successfully recovered 1,000+ historical game plays and player accounts from legacy SQL backups.
- **Standardized Bonuses**: Standardized the `uniqueWordBonus` default value to **+1 point**.

## [1.12.0] - 2026-04-15 (Silent Bump)

## [1.10.1] - 2026-03-07

### Added (1.10.1)

- **Github Link**: Project code link near version and build date, useful for submitting issues

## [1.10.0] - 2026-03-05

### Added (1.10.0)

- **End on All Played Toggle**: New global setting (`global.endOnAllPlayed`) that automatically ends a game as soon as every connected player has submitted a word.
- **Premature Climax! branding**: Games that end early due to the "All Played" condition now feature a unique "PREMATURE CLIMAX!" header on the results screen.
- **Full Multilingual Support**: Localized "Premature Climax!" and result screens in **English, Spanish, German, French, and Russian**.

### Changed (1.10.0)

- **Simplified Duplicate Display**: Duplicating players are now shown as a clean, comma-separated list on the results screen, removing unnecessary point breakdowns.
- **Balanced Duplicate Bonus**: Increased the duplicate word bonus to **+2 points** per duplication to better reward original vocabulary.
- **Scoped Game Broadcasts**: Refactored internal broadcast logic to ensure chat and end-game notifications are strictly scoped to the active game.

## [1.9.0] - 2026-03-03

### Added (1.9.0)

- **Quick Wank Bonus**: New end-game bonus for lightning-fast players. Earn up to +6 points for playing in the first 5 seconds of a game. Bonus is calculated as `(quickBonusSeconds + 1) - seconds_since_start`.
- **AI Brain & Scheduling**:
  - Added `brain` column (JSONB) to `players` table for AI configuration and personalities.
  - Implemented AI scheduling logic allowing AIs to join during specific windows or jump in randomly.
  - Persona-driven AI dialogue now supports custom prompts and character-specific behaviors.
- **Database Migration Framework**: Introduced a robust Perl-based migration runner (`migrate.pl`) with version tracking.

### Refactored (1.9.0)

- **Backend Architecture Overhaul**: Refactored monolithic `Game.pm` into specialized modules:
  - `Logodal::Game::Manager`: Handles game lifecycle and player joining.
  - `Logodal::Game::StateProcessor`: Manages scoring, bonuses, and results calculation.
  - `Logodal::Game::Registry`: Handles game discovery and creation logic.
  - `Logodal::Service::Wordd`: Cleaned up interface for the word validation service.

### Fixed (1.9.0)

- **UTF-8 & JSON Safety**:
  - Hardened `Mojo::JSON` inflation/deflation in DBIx::Class models to safely handle UTF-8 characters (like smart quotes) in JSON columns.
  - Added `use utf8;` and `binmode(STDERR, ":utf8")` to prevent "Wide character" warnings and server hangs.
- **SQL Syntax Errors**: Fixed quoting issues in migration scripts by adopting smart quotes (`’`) for character prompts.

## [1.8.0] - 2026-02-28

### Added (1.8.0)

- **Ko-fi Donation Integration**: Replaced Stripe with Ko-fi for a simpler, Google Pay-compatible donation experience.
- **Donation Visibility Toggles**: Added `VITE_KOFI_ENABLED` and `VITE_PAYPAL_ENABLED` toggles to allow full control over which payment options are displayed in the UI.

### Removed (1.8.0)

- **Legacy Payment Provider**: Completely removed all legacy payment-related backend controllers, frontend logic, and environment configurations.

## [1.7.0] - 2026-02-27

### Added (1.7.0)

- **Dynamic LLM AI Characters**: Replaced canned AI chat with dynamic, persona-driven dialogue powered by Ollama. **Note: This feature is in early testing phase.**
  - **Persona System**: Custom prompts for Yertyl (grumpy turtle), Flash (speedster), Wanko (pun-master), and Scrabbler (sophisticated linguist).
  - **Context-Aware Preamble**: AI now considers game rules and its current tile rack when generating reactions.
- **Wanker Log Panel**: Re-introduced the "Play-by-Play" style log window as a dedicated, non-interactive "Wanker Log" to reduce chat noise while maintaining event visibility.
  - Refactored chat logic into a reusable `MessageList` component.
  - Toggles available in header and sidebar with position/visibility persistence.
- **Integration Test Suite Expansion**: Added `08-llm-ai-player.t` to verify character personalities and prompt enrichment.

### Improved (1.7.0)

- **AI Thinking Accuracy**: AI now maintains awareness of its current tiles during the thinking phase.
- **Deployment Payload**: Optimized `AI.pm` async callbacks for better reliability under load.

### Changed (1.7.0)

- **Chat Format Reversion**: Reverted `app.chat_format` to a cleaner `{{player}} : {{text}}` across all localized JSON files.

### Fixed (1.7.0)

- **AI Broadcast Typos**: Resolved a critical typo in `AI.pm` that prevented AI reactions from broadcasting to the game channel.
- **WebSocket Handshake Races**: Stabilized integration tests to prevent timeouts during backend initialization.

## [1.6.0] - 2026-02-26

### Fixed (1.6.0)

- **First-to-Score Wins**: Corrected tie-breaking logic in `Game.pm`. Ties are now resolved by submission time (`created_at`), ensuring the first player to achieve a winning score is declared the victor.
- **Frontend ReferenceError**: Resolved `ReferenceError: player is not defined` in `Chat.jsx` by streamlining `Trans` component interpolation.
- **System Stability**: Replaced unsafe `$tx->result` calls with `$tx->res` in `Game.pm` and `AI.pm` to prevent backend crashes during external service connection failures.
- **Handshake Robustness**: Hardened `TestHelper.pm` with a resilient, timeout-aware message waiting loop, making integration tests immune to intermediate join notifications.
- **Join Notifications Restored**: Re-enabled player join and identity broadcasts, providing better situational awareness in multi-player sessions.

### Improved (1.6.0)

- **Testability Architecture**: Refactored `Game.pm` and `AI.pm` to isolate external service calls (validation, definitions, AI candidates) into overridable methods, enabling full mocking support.
- **Modernized Test Suite**: Updated `03-multi-player.t` to use `done_testing()`, providing more robust verification of variable game flows.

## [1.5.0] - 2026-02-25

### Added (1.5.0)

- **Full Hunspell Affix Support**: Expanded `scripts/hunspell-to-lexicon.pl` with a custom expansion engine and `unmunch` integration.
  - Successfully handles plurals, prefixes, and complex suffixes from `.aff` files.
  - Priority given to `unmunch` on Arkham, with a zero-dependency Perl fallback for local dev.
- **Lexicon Build Automation**: Added `make lexicon` and `make lexicons` targets to the root `Makefile` for automated word list generation across all supported languages (`de`, `en`, `es`, `fr`, `ru`).
- **Documentation & Credits**:
  - Refreshed `README.md` with new prerequisites and lexicography instructions.
  - Updated `THANKS.md` to formally credit the Hunspell project and preserve links to historical word list providers.

## [1.4.0] - 2026-02-25

### Added (1.4.0)

- **AI Adversary Emergence**: Introduced a new AI-powered player capable of joining games, pondering its moves in real-time (with localized "thoughts"), and challenging human players across all supported languages.
- **Multilingual AI Intelligence**: The AI now understands and communicates in English, Spanish, French, German, and Russian, fully integrated with our shared locale system.

### Fixed (1.4.0)

- **AI Thought Localization**: Resolved a display bug where AI "thinking" states were showing as raw translation keys (`ai.thinking`) instead of their natural language equivalents.
- **Recursive Locale Fixes**: Restored and validated AI thinking strings across all supported language JSON files.

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

- **Payment Integration**: Initial integration for community donations.
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

[Unreleased]: https://github.com/ronstr8/logodal/compare/v3.1.0...HEAD
[3.1.0]: https://github.com/ronstr8/logodal/releases/tag/v3.1.0
