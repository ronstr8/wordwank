-- Migration: Add brain column to players table
-- Version: 0.3.0
-- Date: 2026-03-02

ALTER TABLE players ADD COLUMN IF NOT EXISTS brain JSONB;
-- Seed initial AI data if they don't exist
INSERT INTO players (id, nickname, brain) VALUES
('00000000-0000-4000-a000-000000000001', 'Yertyl', '{"schedule": {"mon": ["00:00-12:00"], "tue": ["00:00-12:00"], "wed": ["00:00-12:00"], "thu": ["00:00-12:00"], "fri": ["00:00-12:00"], "sat": ["00:00-12:00"], "sun": ["00:00-12:00"]}, "character_prompt": "You are Yertyl, a slow, thoughtful, and slightly grumpy turtle who hates being rushed. You speak in short, punchy sentences and occasionally complain about the speed of younger ’wankers’.", "wait_seconds_base": 15, "rnd_word_count": 3, "min_score_to_play": 1, "min_score_to_win": 40}')
ON CONFLICT (id) DO UPDATE SET brain = EXCLUDED.brain;

INSERT INTO players (id, nickname, brain) VALUES
('00000000-0000-4000-a000-000000000002', 'Flash', '{"schedule": {"mon": ["12:00-23:59"], "tue": ["12:00-23:59"], "wed": ["12:00-23:59"], "thu": ["12:00-23:59"], "fri": ["12:00-23:59"], "sat": ["12:00-23:59"], "sun": ["12:00-23:59"]}, "character_prompt": "You are Flash, a hyper-active, caffeine-fueled speedster who talks too fast and thinks everyone else is too slow. Use lots of exclamation marks and energetic words.", "wait_seconds_base": 5, "rnd_word_count": 5, "min_score_to_play": 5, "min_score_to_win": 35}')
ON CONFLICT (id) DO UPDATE SET brain = EXCLUDED.brain;

INSERT INTO players (id, nickname, brain) VALUES
('00000000-0000-4000-a000-000000000003', 'Wanko', '{"schedule": {"all": ["18:00-22:00"]}, "probability": 0.2, "character_prompt": "You are Wanko, a self-proclaimed ’wank master’ who is overly confident and uses too many puns about ’wanking words’. You think you are the best at this game.", "wait_seconds_base": 8, "rnd_word_count": 8, "min_score_to_play": 10, "min_score_to_win": 25}')
ON CONFLICT (id) DO UPDATE SET brain = EXCLUDED.brain;

INSERT INTO players (id, nickname, brain) VALUES
('00000000-0000-4000-a000-000000000004', 'Scrabbler', '{"schedule": {"all": ["09:00-17:00"]}, "character_prompt": "You are Scrabbler, a serious, competitive linguist who thinks Wordwank is beneath them but plays it anyway. Use sophisticated vocabulary and sound slightly superior.", "wait_seconds_base": 12, "rnd_word_count": 10, "min_score_to_play": 15, "min_score_to_win": 20}')
ON CONFLICT (id) DO UPDATE SET brain = EXCLUDED.brain;
