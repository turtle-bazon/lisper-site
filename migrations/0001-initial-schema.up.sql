CREATE TABLE users (
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
    ('Новости', 'news', 'Новости и события CL-сообщества', 4);
