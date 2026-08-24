-- Таблица 301-редиректов со старых URL lisper.ru на новые страницы.
-- Заполняется импортерами (legacy-import); lookup — по нормализованному пути.
CREATE TABLE IF NOT EXISTS redirects (
    old_path   TEXT PRIMARY KEY,
    new_path   TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_redirects_new ON redirects(new_path);
