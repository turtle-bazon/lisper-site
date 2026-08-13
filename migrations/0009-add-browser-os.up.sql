-- Analytics: browser and OS breakdown, persisted through the daily rollup.
-- device stayed as the coarse parent; browser/os give a finer view and are
-- part of the PK so the rollup keeps them separate per (browser, os).

ALTER TABLE daily_stats DROP CONSTRAINT daily_stats_pkey;
ALTER TABLE daily_stats ADD COLUMN browser TEXT NOT NULL DEFAULT 'Unknown';
ALTER TABLE daily_stats ADD COLUMN os TEXT NOT NULL DEFAULT 'Unknown';
ALTER TABLE daily_stats ADD PRIMARY KEY (date, path, country, device, browser, os, referrer, is_bot);