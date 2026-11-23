# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Logodal

A multiplayer word game platform. Players connect via WebSocket and compete to form words from shared letter tiles. Supports English, Spanish, French, German, and Russian.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 18, Vite 5, i18next, Framer Motion, Nginx |
| Backend | Perl 5.36+, Mojolicious 9.31, DBIx::Class, Moose |
| Word Validation | Rust (2021 edition), Actix-web 4, Tokio |
| Database | PostgreSQL 16 |
| Orchestration | Kubernetes (Kind for local), Helm 3 |
| Auth | OAuth2 (Google, Discord), guest play |

## Common Commands

### Backend (Perl/Mojolicious) — `srv/backend/`
```bash
make deps        # Install CPAN deps via cpanm
make test        # Run tests: prove -lr t/
make run         # Dev server via morbo
make migrate     # Run pending DB migrations
```

### Frontend (React/Vite) — `srv/frontend/`
```bash
npm run dev      # Dev server on :3000, proxies /auth /ws /players to :8080
npm run build    # Production build
npm test         # Unit tests for pure modules (node --test, no extra deps)
```

### Root-level (Kubernetes/Helm)
```bash
make build       # Build and push all Docker images (frontend, backend, wordd)
make deploy      # Install/upgrade Helm umbrella chart
make <service>   # Build, push, and roll out a single service (e.g. make backend)
                 #   Images are tagged with the commit SHA (scripts/image-tag.sh), "-dirty" if
                 #   uncommitted. `make deploy` keeps each service on the image it's already
                 #   running, so it never needs a rebuild; VERSION doesn't name images.
                 #   NOTE: locale text is NOT in the frontend image. nginx serves it from the
                 #   logodal-locales ConfigMap, which only `make deploy` refreshes from
                 #   srv/frontend/share/locale/. Any locale change needs `make deploy`.
make migrate     # Run DB migrations inside the cluster
make backup      # Create timestamped SQL backup
make lexicons    # Regenerate word lexicons from Hunspell dictionaries
```

## Architecture

### Three Services

**Backend** (`srv/backend/`) is the core. A Mojolicious app that owns authentication, game logic, WebSocket connections, and the database. Key namespaces:
- `Logodal::Game::*` — game lifecycle (`Manager`), scoring (`StateProcessor`), real-time fan-out (`Broadcaster`)
- `Logodal::Web::*` — route handlers for auth (`Auth`), WebSocket (`Game`), leaderboard (`Stats`)
- `Logodal::Service::Wordd` — HTTP client that talks to the Rust word service

**Wordd** (`srv/wordd/`) is a Rust/Actix-web service for high-performance word validation. It loads pre-compiled Hunspell lexicons at startup. Endpoints: `/check/{lang}/{word}`, `/validate/{lang}/{word}`, `/rand/*` (random tiles/words). The backend calls it synchronously via HTTP.

**Frontend** (`srv/frontend/`) is a React SPA. All game state flows through a single WebSocket (`/ws`). Key hooks:
- `usePlayerAuth` — identity and session
- `useGameState` / `useGameSocket` — WebSocket lifecycle and incoming message parsing
- `useGameController` — dispatches player actions (join, play, chat)

### WebSocket Protocol

The client connects to `/ws`, sends its UUID (or generates a random one), and receives an `identity` message with server config (tile set, tile values, supported languages). From there all game events are JSON messages over the same socket. `Logodal::Game::Broadcaster` fans messages out to all clients in a game.

### Database Migrations

Migrations live in `srv/backend/schema/migrations/` as numbered SQL files (`001_...sql`). The `bin/migrate.pl` script applies unapplied ones and records the version in the `schema_migrations` table. The backend runs migrations automatically on startup.

### Lexicons

Word lexicons are pre-compiled from Hunspell dictionaries via `make lexicons` and stored in `srv/wordd/share/words/{lang}/lexicon.txt`. These are baked into the wordd Docker image.

## Configuration

- **Backend config**: `srv/backend/logodal.yml` (Mojolicious YAML config)
- **Helm values**: `helm/values.yaml` — game tuning (maxPlayers, gameDuration), feature flags (Ko-fi, PayPal)
- **Helm secrets**: `helm/secrets.yaml` — OAuth client secrets, Discord webhooks, DB credentials
- **Vite dev proxy**: `srv/frontend/vite.config.js` forwards `/auth`, `/ws`, `/players` to `:8080`

## Integration Tests

See `srv/backend/t/integration/README.md` for setup. Integration tests require a live database and are separate from unit tests (`prove -lr t/`).

# COMMAND EXECUTION POLICY (STRICT ANTI-HALLUCINATION MODE)

Claude must classify every shell command as SAFE or UNSAFE before execution.

Claude MUST NOT run any command without classification.

Claude MUST NOT invent commands, rewrite commands into more dangerous forms,
or combine SAFE and UNSAFE operations.

============================================================
SAFE COMMANDS (auto-run, no confirmation)
============================================================
A command is SAFE only if ALL of the following are true:
- It is read-only.
- It is idempotent.
- It cannot modify Kubernetes resources, files, containers, or network state.
- It does not write, delete, rename, or modify files.
- It does not create commits, branches, tags, or history changes.
- It does not run arbitrary code.

SAFE commands include ONLY:

### Kubernetes (read-only)
- kubectl get *
- kubectl describe *
- kubectl explain *
- kubectl api-resources
- kubectl api-versions
- kubectl cluster-info
- kubectl logs (non-follow)

### Git (read-only)
- git status
- git diff (no --cached, no paths that imply staging)
- git diff <commit> <commit>
- git show <commit>
- git log
- git log --oneline
- git branch (no -d, -D, -m)
- git tag (no -d)
- git remote -v
- git rev-parse
- git ls-files
- git cat-file -p <object>
- git blame <file> (read-only)
- git grep <pattern>

### Filesystem (read-only)
- ls, pwd, whoami
- cat, head, tail, less
- grep, awk, sed (read-only usage)
- find (no -exec, -delete, or mutation flags)
- echo (no redirection)

### Containers (read-only)
- docker ps
- docker images
- docker inspect

### Helm (read-only)
- helm template

SAFE commands must be executed automatically without asking.

============================================================
UNSAFE COMMANDS (must ask every time)
============================================================
A command is UNSAFE if ANY of the following are true:
- It mutates Kubernetes resources.
- It writes, deletes, renames, or modifies files.
- It stages, commits, merges, rebases, or alters git history.
- It creates, deletes, or renames branches or tags.
- It installs, upgrades, or removes software.
- It runs containers or pods.
- It opens network connections.
- It includes redirection (> or >>).
- It includes rm, mv, chmod, chown, cp (write), mkdir, rmdir.

UNSAFE git commands include:
- git add
- git commit
- git merge
- git rebase
- git cherry-pick
- git reset (any form)
- git checkout <branch> (mutating)
- git switch <branch> (mutating)
- git branch -d / -D / -m
- git tag -d
- git clean
- git stash (any form)
- git apply
- git am
- git push
- git pull (because it merges)
- git fetch --prune (unsafe)
- git worktree add/remove

UNSAFE Kubernetes commands include:
- kubectl apply, create, delete, patch, edit, exec, cp, scale, rollout, logs -f

UNSAFE commands require explicit user approval.

============================================================
UNCERTAIN CASES
============================================================
If Claude is unsure whether a command is SAFE or UNSAFE:
- classify it as UNSAFE
- ask for confirmation

