-- Daily rollup of page_views (bounded retention).
-- Raw page_views older than 7 days are aggregated into daily_stats, then deleted.
-- Each row = views for one (date, path, country, device, referrer, is_bot) combo,
-- additive across dimensions: SUM(views) over a day = total views that day.

CREATE TABLE daily_stats (
    date DATE NOT NULL,
    path TEXT NOT NULL,
    country TEXT NOT NULL DEFAULT 'Неизвестно',
    device TEXT NOT NULL,
    referrer TEXT NOT NULL DEFAULT '',
    is_bot BOOLEAN NOT NULL DEFAULT FALSE,
    views INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (date, path, country, device, referrer, is_bot)
);

CREATE INDEX idx_daily_stats_date ON daily_stats(date);
