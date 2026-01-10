-- Migration: Add lifetime_score column to players table
-- Version: 0.2.0
-- Date: 2026-01-10

ALTER TABLE players ADD COLUMN IF NOT EXISTS lifetime_score INTEGER NOT NULL DEFAULT 0;
