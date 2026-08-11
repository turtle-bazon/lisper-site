CREATE TABLE ip_country (
    network CIDR NOT NULL PRIMARY KEY,
    country_code CHAR(2),
    country_name TEXT NOT NULL
);

CREATE INDEX idx_ip_country_network ON ip_country(network);
