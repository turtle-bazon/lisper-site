-- Topic subscriptions: users follow topics, track unread replies.
CREATE TABLE topic_subscriptions (
    topic_id  INTEGER NOT NULL REFERENCES topics(id)  ON DELETE CASCADE,
    user_id   INTEGER NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    last_read_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (topic_id, user_id)
);
CREATE INDEX idx_sub_user ON topic_subscriptions(user_id);
