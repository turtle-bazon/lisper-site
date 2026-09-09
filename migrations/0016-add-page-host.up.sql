-- Analytics: per-domain reporting. host goes into both page_views (raw) and
-- daily_stats (rollup), so the breakdown survives retention.

ALTER TABLE page_views ADD COLUMN host TEXT;
ALTER TABLE daily_stats DROP CONSTRAINT daily_stats_pkey;
ALTER TABLE daily_stats ADD COLUMN host TEXT NOT NULL DEFAULT 'unknown';
ALTER TABLE daily_stats ADD PRIMARY KEY (date, path, country, device, browser, os, referrer, is_bot, host);