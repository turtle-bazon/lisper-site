ALTER TABLE daily_stats DROP CONSTRAINT daily_stats_pkey;
ALTER TABLE daily_stats ADD PRIMARY KEY (date, path, country, device, browser, os, referrer, is_bot);
ALTER TABLE daily_stats DROP COLUMN host;
ALTER TABLE page_views DROP COLUMN host;