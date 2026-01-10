-- Wordwank PostgreSQL Schema
-- Version: 0.2.0

BEGIN;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Players
CREATE TABLE IF NOT EXISTS players (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nickname TEXT UNIQUE,               -- Pronounceable alias
    real_name TEXT,                     -- From OAuth provider
    email TEXT UNIQUE,                  -- Optional, for account recovery
    language TEXT NOT NULL DEFAULT 'en',
    lifetime_score INTEGER NOT NULL DEFAULT 0,   -- Cumulative score across all games
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE
);

-- Linked Identitites (OAuth providers)
CREATE TABLE IF NOT EXISTS player_identities (
    id BIGSERIAL PRIMARY KEY,
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,             -- 'google', 'apple', etc.
    provider_id TEXT NOT NULL,          -- The 'sub' or unique ID from provider
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(provider, provider_id)
);

-- Passkey Credentials (WebAuthn)
CREATE TABLE IF NOT EXISTS player_passkeys (
    id BIGSERIAL PRIMARY KEY,
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    credential_id BYTEA UNIQUE NOT NULL,
    public_key BYTEA NOT NULL,
    sign_count BIGINT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Stateful Sessions
CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,               -- Session ID (long random string)
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Games (individual rounds)
CREATE TABLE IF NOT EXISTS games (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rack TEXT[] NOT NULL,               -- The 7 tiles dealt
    letter_values JSONB NOT NULL,       -- Per-letter scores for this round
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    finished_at TIMESTAMP WITH TIME ZONE -- NULL if in progress
);

-- Plays (entries made during a game)
CREATE TABLE IF NOT EXISTS plays (
    id BIGSERIAL PRIMARY KEY,
    game_id UUID NOT NULL,
    player_id UUID NOT NULL,
    word TEXT NOT NULL,
    score INTEGER NOT NULL,            -- Base score calculated at time of play
    is_auto_submit BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Constraints
    CONSTRAINT fk_game FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE CASCADE,
    CONSTRAINT fk_player FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
);

-- Indexing for speed
CREATE INDEX idx_plays_game ON plays(game_id);
CREATE INDEX idx_plays_player ON plays(player_id);
CREATE INDEX idx_sessions_expiry ON sessions(expires_at);

COMMIT;
