-- ============================================================
-- TEST CATALOG SCHEMA
-- ============================================================
-- MySQL 8.0.15
--
-- Учебная схема для задания по типам данных,
-- генерации 200000 товаров и пагинации.
-- ============================================================

CREATE DATABASE IF NOT EXISTS catalog_test
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE catalog_test;

DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;

CREATE TABLE categories (
    category_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(32) NOT NULL
) ENGINE=InnoDB;


CREATE TABLE products (
    product_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(32) NOT NULL,
    category_id BIGINT UNSIGNED NOT NULL,
    price DECIMAL(10,2) UNSIGNED NOT NULL,
    rating TINYINT UNSIGNED NOT NULL,
    status ENUM('В наличии', 'Распродан') NOT NULL,

    CONSTRAINT uq_products_price
        UNIQUE (price),

    CONSTRAINT fk_products_category
        FOREIGN KEY (category_id)
        REFERENCES categories (category_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT
) ENGINE=InnoDB;


-- MySQL 8.0.15 принимает синтаксис CHECK,
-- но ещё не применяет CHECK как реальное ограничение.
-- Поэтому диапазоны price и rating защищаются триггерами.

DELIMITER //

CREATE TRIGGER trg_products_validate_insert
BEFORE INSERT ON products
FOR EACH ROW
BEGIN
    IF NEW.price <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Product price must be greater than 0';
    END IF;

    IF NEW.rating < 1 OR NEW.rating > 5 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Product rating must be between 1 and 5';
    END IF;
END//

CREATE TRIGGER trg_products_validate_update
BEFORE UPDATE ON products
FOR EACH ROW
BEGIN
    IF NEW.price <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Product price must be greater than 0';
    END IF;

    IF NEW.rating < 1 OR NEW.rating > 5 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Product rating must be between 1 and 5';
    END IF;
END//

DELIMITER ;


-- Индекс для сортировки и постраничной выдачи.
CREATE INDEX idx_products_status_price
ON products (status, price);
