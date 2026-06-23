DROP INDEX IF EXISTS idx_sessions_token;
DROP INDEX IF EXISTS idx_posts_topic;
DROP INDEX IF EXISTS idx_topics_last_post;
DROP INDEX IF EXISTS idx_topics_category;

DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS topics;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS users;
