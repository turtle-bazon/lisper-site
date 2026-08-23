-- Импортированные статьи/wiki/старые посты блога: хранят готовый HTML
-- (рендерится как .legacy-html без markdown-парсера).
ALTER TABLE blog_posts ADD COLUMN is_html BOOLEAN NOT NULL DEFAULT FALSE;
