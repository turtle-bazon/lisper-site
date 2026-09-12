-- Blog: add tags column (comma-separated lowercase slugs).
ALTER TABLE blog_posts ADD COLUMN tags TEXT NOT NULL DEFAULT '';
