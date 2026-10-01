CREATE DATABASE IF NOT EXISTS import_test
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE import_test;

DROP TABLE IF EXISTS users;

CREATE TABLE users (
    email VARCHAR(255) NOT NULL,
    city VARCHAR(100) NULL
);

LOAD DATA LOCAL INFILE '/tmp/users.csv'
INTO TABLE users
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(email, city);

SELECT
    email,
    city,
    city IS NULL AS city_is_null
FROM users
ORDER BY email;
