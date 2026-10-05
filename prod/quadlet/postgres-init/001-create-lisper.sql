-- Pre-create the app role and database.
-- Runs once by the official postgres image initdb on first startup
-- of an empty data dir (files in /docker-entrypoint-initdb.d are
-- executed alphabetically; this is 001-*).
--
-- lisper applies its own migrations (embedded in the binary) at startup,
-- so the schema is created by the app, not here.

CREATE ROLE lisper WITH LOGIN PASSWORD 'lisper';
CREATE DATABASE lisper OWNER lisper;
GRANT ALL PRIVILEGES ON DATABASE lisper TO lisper;
