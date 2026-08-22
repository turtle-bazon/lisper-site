-- Откат импорта старого форума: удаляем архивные категории
-- (темы/посты уйдут по каскаду? нет — FK без ON DELETE, поэтому
-- сначала чистим контент, потом колонки).
DELETE FROM posts WHERE old_msg_id IS NOT NULL;
DELETE FROM topics WHERE old_thread_id IS NOT NULL;
DELETE FROM categories WHERE archived = TRUE;

DROP INDEX IF EXISTS idx_posts_old_msg;
DROP INDEX IF EXISTS idx_topics_old_thread;
ALTER TABLE posts DROP COLUMN old_reply_to;
ALTER TABLE posts DROP COLUMN old_author;
ALTER TABLE posts DROP COLUMN old_msg_id;
ALTER TABLE topics DROP COLUMN old_author;
ALTER TABLE topics DROP COLUMN old_thread_id;
ALTER TABLE categories DROP COLUMN archived;
