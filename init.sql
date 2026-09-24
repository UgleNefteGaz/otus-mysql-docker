CREATE DATABASE IF NOT EXISTS production_mysql
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE production_mysql;


-- ============================================================
-- PRODUCTS
-- ============================================================

CREATE TABLE IF NOT EXISTS products (
    product_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    article VARCHAR(50) NOT NULL,
    name VARCHAR(200) NOT NULL,
    unit VARCHAR(20) NOT NULL,

    PRIMARY KEY (product_id),
    UNIQUE KEY uq_products_article (article)
) ENGINE=InnoDB;


-- ============================================================
-- PRODUCTION ORDERS
-- ============================================================

CREATE TABLE IF NOT EXISTS production_orders (
    order_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_number VARCHAR(50) NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    planned_quantity DECIMAL(18,3) UNSIGNED NOT NULL,
    status ENUM(
        'Created',
        'InProgress',
        'Completed',
        'Cancelled'
    ) NOT NULL DEFAULT 'Created',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (order_id),
    UNIQUE KEY uq_production_orders_number (order_number),

    CONSTRAINT fk_production_orders_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT
) ENGINE=InnoDB;


-- ============================================================
-- PRODUCTION BATCHES
-- ============================================================

CREATE TABLE IF NOT EXISTS production_batches (
    batch_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    batch_number VARCHAR(50) NOT NULL,
    planned_quantity DECIMAL(18,3) UNSIGNED NOT NULL,
    actual_quantity DECIMAL(18,3) UNSIGNED NULL,
    status ENUM(
        'Planned',
        'InProgress',
        'Completed',
        'Cancelled'
    ) NOT NULL DEFAULT 'Planned',

    PRIMARY KEY (batch_id),
    UNIQUE KEY uq_production_batches_number (batch_number),

    CONSTRAINT fk_production_batches_order
        FOREIGN KEY (order_id)
        REFERENCES production_orders(order_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT
) ENGINE=InnoDB;


-- ============================================================
-- QUALITY CHECKS
-- ============================================================

CREATE TABLE IF NOT EXISTS quality_checks (
    quality_check_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    batch_id BIGINT UNSIGNED NOT NULL,
    result ENUM(
        'Pending',
        'Passed',
        'Failed'
    ) NOT NULL DEFAULT 'Pending',
    checked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes VARCHAR(500) NULL,

    PRIMARY KEY (quality_check_id),

    CONSTRAINT fk_quality_checks_batch
        FOREIGN KEY (batch_id)
        REFERENCES production_batches(batch_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT
) ENGINE=InnoDB;


-- ============================================================
-- INITIAL DATA
-- ============================================================

INSERT IGNORE INTO products (
    product_id,
    article,
    name,
    unit
)
VALUES
    (1, 'PRD-001', 'Шампунь 500 мл', 'шт'),
    (2, 'PRD-002', 'Маска для волос 400 мл', 'шт'),
    (3, 'PRD-003', 'Гель для душа 500 мл', 'шт');

INSERT IGNORE INTO production_orders (
    order_id,
    order_number,
    product_id,
    planned_quantity,
    status
)
VALUES
    (1, 'PO-2026-001', 1, 10000.000, 'Completed'),
    (2, 'PO-2026-002', 2, 15000.000, 'InProgress'),
    (3, 'PO-2026-003', 3, 8000.000, 'Created');


INSERT IGNORE INTO production_batches (
    batch_id,
    order_id,
    batch_number,
    planned_quantity,
    actual_quantity,
    status
)
VALUES
    (1, 1, 'BATCH-001', 5000.000, 4980.000, 'Completed'),
    (2, 1, 'BATCH-002', 5000.000, 5000.000, 'Completed'),
    (3, 2, 'BATCH-003', 7500.000, NULL, 'InProgress'),
    (4, 2, 'BATCH-004', 7500.000, NULL, 'Planned');


INSERT IGNORE INTO quality_checks (
    quality_check_id,
    batch_id,
    result,
    notes
)
VALUES
    (1, 1, 'Passed', 'Партия соответствует требованиям'),
    (2, 2, 'Passed', 'Партия соответствует требованиям'),
    (3, 3, 'Pending', 'Контроль качества ещё не завершён');
