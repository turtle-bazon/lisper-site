(in-package :lisper)

;;; Embedded migration SQL files
;;; Generated from migrations/*.sql — do not edit manually

(defvar *migrations*
  '((1 . ((:up . "CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(30) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT NOT NULL DEFAULT '',
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE topics (
    id SERIAL PRIMARY KEY,
    category_id INTEGER NOT NULL REFERENCES categories(id),
    user_id INTEGER NOT NULL REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_post_at TIMESTAMP NOT NULL DEFAULT NOW(),
    post_count INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    topic_id INTEGER NOT NULL REFERENCES topics(id),
    user_id INTEGER NOT NULL REFERENCES users(id),
    body TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    token VARCHAR(64) NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_topics_category ON topics(category_id);
CREATE INDEX idx_topics_last_post ON topics(last_post_at DESC);
CREATE INDEX idx_posts_topic ON posts(topic_id);
CREATE INDEX idx_sessions_token ON sessions(token);

INSERT INTO categories (name, slug, description, sort_order) VALUES
    ('Общее', 'general', 'Общие вопросы о Common Lisp', 1),
    ('Проекты', 'projects', 'Делитесь своими проектами', 2),
    ('Помощь', 'help', 'Задавайте вопросы, получайте ответы', 3),
    ('Новости', 'news', 'Новости и события CL-сообщества', 4);")
          (:down . "DROP INDEX IF EXISTS idx_sessions_token;
DROP INDEX IF EXISTS idx_posts_topic;
DROP INDEX IF EXISTS idx_topics_last_post;
DROP INDEX IF EXISTS idx_topics_category;

DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS topics;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS users;")))
    (2 . ((:up . "ALTER TABLE users ADD COLUMN muted_until TIMESTAMP DEFAULT NULL;")
          (:down . "ALTER TABLE users DROP COLUMN muted_until;")))
    (3 . ((:up . "CREATE TABLE settings (
    key VARCHAR(50) PRIMARY KEY,
    value TEXT NOT NULL
);

INSERT INTO settings (key, value) VALUES ('forum_closed', 'false');")
          (:down . "DROP TABLE IF EXISTS settings;")))
    (4 . ((:up . "CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    action VARCHAR(50) NOT NULL,
    target_type VARCHAR(50),
    target_id INTEGER,
    details TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_user_id ON audit_log(user_id);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at);")
          (:down . "DROP TABLE IF EXISTS audit_log;")))))

(defun get-available-migrations ()
  "Return sorted list of (version name) from embedded migrations."
  (sort (mapcar (lambda (entry)
                  (list (car entry)
                        (format nil "migration-~A" (car entry))))
                *migrations*)
        #'< :key #'first))

(defun get-migration-sql (version direction)
  "Get SQL for a migration version and direction (:up or :down)."
  (let ((entry (assoc version *migrations*)))
    (when entry
      (cdr (assoc direction (cdr entry))))))
