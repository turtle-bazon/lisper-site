-- Geo moved to in-memory MaxMind DB (cl-maxminddb) - drop the PostgreSQL copy
DROP TABLE IF EXISTS ip_country;
