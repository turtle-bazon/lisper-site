-- Analytics: track which UI language each page view was served in.

ALTER TABLE page_views ADD COLUMN lang TEXT;

CREATE INDEX idx_page_views_lang ON page_views(lang);
