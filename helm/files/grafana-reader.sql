-- Read-only role for Grafana's game-stats dashboards. Run by the
-- grafana-reader hook Job as postgres after every install/upgrade, so this
-- file is the whole truth about what Grafana may read: revoke everything,
-- then grant exactly what's listed.
--
-- Deliberately absent: players.email and players.real_name, and the sessions,
-- player_identities and player_passkeys tables. A dashboard can't leak what
-- its role can't select.
\set ON_ERROR_STOP on

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'grafana_reader') THEN
    CREATE ROLE grafana_reader LOGIN;
  END IF;
END
$$;

ALTER ROLE grafana_reader WITH LOGIN PASSWORD :'reader_password';
-- A slow dashboard query must never hold up the game.
ALTER ROLE grafana_reader SET default_transaction_read_only = on;
ALTER ROLE grafana_reader SET statement_timeout = '30s';

-- Revoking table privileges also revokes column privileges, so this resets
-- every grant below.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM grafana_reader;

GRANT CONNECT ON DATABASE logodal TO grafana_reader;
GRANT USAGE ON SCHEMA public TO grafana_reader;
GRANT SELECT ON games, plays TO grafana_reader;
-- brain is non-null for the AI players; dashboards use it to tell bots from people.
GRANT SELECT (id, nickname, language, lifetime_score, created_at, last_login_at, is_anonymous, brain)
  ON players TO grafana_reader;
