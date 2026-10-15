CREATE DATABASE IF NOT EXISTS app;

USE app;

CREATE TABLE customers (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

CREATE TABLE orders (
    id INT NOT NULL AUTO_INCREMENT,
    customer_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_orders_customer (customer_id),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(id)
) ENGINE=InnoDB;

CREATE TABLE audit_log (
    id BIGINT NOT NULL AUTO_INCREMENT,
    event_text VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

INSERT INTO customers (name, email) VALUES
('Alice', 'alice@example.com'),
('Bob', 'bob@example.com'),
('Carol', 'carol@example.com');

INSERT INTO orders (customer_id, amount, status) VALUES
(1, 100.00, 'NEW'),
(1, 250.50, 'PAID'),
(2, 75.00, 'PAID'),
(3, 999.99, 'NEW');

INSERT INTO audit_log (event_text) VALUES
('Initial customers created'),
('Initial orders created');

CREATE DATABASE IF NOT EXISTS replica_excluded;

USE replica_excluded;

CREATE TABLE secret_data (
    id INT NOT NULL AUTO_INCREMENT,
    payload VARCHAR(100) NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

INSERT INTO secret_data (payload) VALUES
('secret-1'),
('secret-2');
