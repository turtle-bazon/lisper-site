-- Analytics: page views + IP country geo data

CREATE TABLE page_views (
    id SERIAL PRIMARY KEY,
    visitor_id TEXT NOT NULL,
    path TEXT NOT NULL,
    referrer TEXT,
    user_agent TEXT,
    ip TEXT,
    country TEXT,
    is_bot BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_page_views_created_at ON page_views(created_at);
CREATE INDEX idx_page_views_visitor_id ON page_views(visitor_id);
CREATE INDEX idx_page_views_path ON page_views(path);

CREATE TABLE ip_country (
    network CIDR NOT NULL PRIMARY KEY,
    country_code CHAR(2),
    country_name TEXT NOT NULL
);

CREATE INDEX idx_ip_country_network ON ip_country(network);