-- Drop browser/os breakdown from daily_stats, restore the original PK.

ALTER TABLE daily_stats DROP CONSTRAINT daily_stats_pkey;
ALTER TABLE daily_stats DROP COLUMN browser;
ALTER TABLE daily_stats DROP COLUMN os;
ALTER TABLE daily_stats ADD PRIMARY KEY (date, path, country, device, referrer, is_bot);