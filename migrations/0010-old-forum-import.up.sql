-- Старый форум lisper.ru: флаг архивности категорий + поля для
-- сохранения оригинальных авторов/id из старой базы.
ALTER TABLE categories ADD COLUMN archived BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE topics ADD COLUMN old_thread_id INTEGER;
ALTER TABLE topics ADD COLUMN old_author VARCHAR(100);
ALTER TABLE posts ADD COLUMN old_msg_id INTEGER;
ALTER TABLE posts ADD COLUMN old_author VARCHAR(100);
ALTER TABLE posts ADD COLUMN old_reply_to INTEGER;

CREATE INDEX idx_topics_old_thread ON topics(old_thread_id);
CREATE INDEX idx_posts_old_msg ON posts(old_msg_id);
