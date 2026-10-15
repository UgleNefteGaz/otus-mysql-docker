DROP DATABASE IF EXISTS pxc_demo;

CREATE DATABASE pxc_demo;
USE pxc_demo;

CREATE TABLE customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(id)
) ENGINE=InnoDB;

INSERT INTO customers(id, name, email) VALUES
(1, 'Alice', 'alice@example.com'),
(2, 'Bob', 'bob@example.com'),
(3, 'Carol', 'carol@example.com'),
(4, 'Dave', 'dave@example.com'),
(5, 'Eve', 'eve@example.com');

INSERT INTO orders(customer_id, amount, status) VALUES
(1, 100.00, 'PAID'),
(2, 250.50, 'PAID'),
(3, 75.25, 'NEW'),
(1, 499.99, 'PAID'),
(4, 1200.00, 'NEW'),
(5, 315.40, 'PAID');

SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM customers

UNION ALL

SELECT 'orders' AS table_name, COUNT(*) AS row_count
FROM orders;
