USE catalog_test;

-- ============================================================
-- Производители
-- ============================================================

CREATE TABLE manufacturers (
    manufacturer_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(50) NOT NULL,
    UNIQUE KEY uq_manufacturers_title (title)
);

INSERT INTO manufacturers (title)
VALUES
    ('Производитель 01'),
    ('Производитель 02'),
    ('Производитель 03'),
    ('Производитель 04'),
    ('Производитель 05'),
    ('Производитель 06'),
    ('Производитель 07'),
    ('Производитель 08'),
    ('Производитель 09'),
    ('Производитель 10');


-- Сначала разрешаем NULL, потому что в products уже есть данные.
ALTER TABLE products
    ADD COLUMN manufacturer_id BIGINT UNSIGNED NULL;


-- Распределяем существующие товары между 10 производителями.
UPDATE products
SET manufacturer_id = 1 + MOD(product_id - 1, 10);


-- После заполнения запрещаем NULL.
ALTER TABLE products
    MODIFY manufacturer_id BIGINT UNSIGNED NOT NULL;


-- Индекс нужен и для JOIN, и для фильтрации по производителю.
CREATE INDEX idx_products_manufacturer
    ON products (manufacturer_id);


ALTER TABLE products
    ADD CONSTRAINT fk_products_manufacturer
        FOREIGN KEY (manufacturer_id)
        REFERENCES manufacturers (manufacturer_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;


-- ============================================================
-- Процедура выборки товаров
-- ============================================================

DROP PROCEDURE IF EXISTS get_products;

DELIMITER //

CREATE PROCEDURE get_products(
    IN p_category_id BIGINT UNSIGNED,
    IN p_min_price DECIMAL(10,2),
    IN p_max_price DECIMAL(10,2),
    IN p_manufacturer_id BIGINT UNSIGNED,
    IN p_min_rating TINYINT UNSIGNED,
    IN p_status VARCHAR(20),
    IN p_title VARCHAR(100),
    IN p_sort_field VARCHAR(30),
    IN p_sort_direction VARCHAR(4),
    IN p_page INT UNSIGNED,
    IN p_page_size INT UNSIGNED
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_page INT UNSIGNED;
    DECLARE v_page_size INT UNSIGNED;
    DECLARE v_offset INT UNSIGNED;
    DECLARE v_sort_field VARCHAR(30);
    DECLARE v_sort_direction VARCHAR(4);

    -- --------------------------------------------------------
    -- Постраничная выдача
    -- --------------------------------------------------------

    SET v_page =
        CASE
            WHEN p_page IS NULL OR p_page < 1 THEN 1
            ELSE p_page
        END;

    SET v_page_size =
        CASE
            WHEN p_page_size IS NULL THEN 20
            WHEN p_page_size < 1 THEN 1
            WHEN p_page_size > 100 THEN 100
            ELSE p_page_size
        END;

    SET v_offset = (v_page - 1) * v_page_size;


    -- --------------------------------------------------------
    -- Проверка диапазона цены
    -- --------------------------------------------------------

    IF p_min_price IS NOT NULL
       AND p_max_price IS NOT NULL
       AND p_min_price > p_max_price THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Минимальная цена не может быть больше максимальной';
    END IF;


    -- --------------------------------------------------------
    -- Проверка статуса
    -- --------------------------------------------------------

    IF p_status IS NOT NULL
       AND p_status NOT IN ('В наличии', 'Распродан') THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Некорректный статус товара';
    END IF;


    -- --------------------------------------------------------
    -- Допустимые поля сортировки
    -- --------------------------------------------------------

    SET v_sort_field =
        CASE
            WHEN p_sort_field IN (
                'product_id',
                'title',
                'price',
                'rating',
                'category',
                'manufacturer'
            )
            THEN p_sort_field
            ELSE 'product_id'
        END;

    SET v_sort_direction =
        CASE
            WHEN UPPER(p_sort_direction) = 'DESC' THEN 'DESC'
            ELSE 'ASC'
        END;


    -- --------------------------------------------------------
    -- Выборка
    -- --------------------------------------------------------

    SELECT
        p.product_id,
        p.title,
        c.category_id,
        c.title AS category,
        m.manufacturer_id,
        m.title AS manufacturer,
        p.price,
        p.rating,
        p.status
    FROM products p
    INNER JOIN categories c
        ON c.category_id = p.category_id
    INNER JOIN manufacturers m
        ON m.manufacturer_id = p.manufacturer_id
    WHERE
        (p_category_id IS NULL
            OR p.category_id = p_category_id)

        AND (p_min_price IS NULL
            OR p.price >= p_min_price)

        AND (p_max_price IS NULL
            OR p.price <= p_max_price)

        AND (p_manufacturer_id IS NULL
            OR p.manufacturer_id = p_manufacturer_id)

        AND (p_min_rating IS NULL
            OR p.rating >= p_min_rating)

        AND (p_status IS NULL
            OR p.status = p_status)

        AND (p_title IS NULL
            OR p.title LIKE CONCAT('%', p_title, '%'))

    ORDER BY

        CASE
            WHEN v_sort_field = 'product_id'
             AND v_sort_direction = 'ASC'
            THEN p.product_id
        END ASC,

        CASE
            WHEN v_sort_field = 'product_id'
             AND v_sort_direction = 'DESC'
            THEN p.product_id
        END DESC,

        CASE
            WHEN v_sort_field = 'title'
             AND v_sort_direction = 'ASC'
            THEN p.title
        END ASC,

        CASE
            WHEN v_sort_field = 'title'
             AND v_sort_direction = 'DESC'
            THEN p.title
        END DESC,

        CASE
            WHEN v_sort_field = 'price'
             AND v_sort_direction = 'ASC'
            THEN p.price
        END ASC,

        CASE
            WHEN v_sort_field = 'price'
             AND v_sort_direction = 'DESC'
            THEN p.price
        END DESC,

        CASE
            WHEN v_sort_field = 'rating'
             AND v_sort_direction = 'ASC'
            THEN p.rating
        END ASC,

        CASE
            WHEN v_sort_field = 'rating'
             AND v_sort_direction = 'DESC'
            THEN p.rating
        END DESC,

        CASE
            WHEN v_sort_field = 'category'
             AND v_sort_direction = 'ASC'
            THEN c.title
        END ASC,

        CASE
            WHEN v_sort_field = 'category'
             AND v_sort_direction = 'DESC'
            THEN c.title
        END DESC,

        CASE
            WHEN v_sort_field = 'manufacturer'
             AND v_sort_direction = 'ASC'
            THEN m.title
        END ASC,

        CASE
            WHEN v_sort_field = 'manufacturer'
             AND v_sort_direction = 'DESC'
            THEN m.title
        END DESC,

        -- Детерминированный порядок при одинаковом основном поле.
        p.product_id ASC

    LIMIT v_page_size OFFSET v_offset;

END//

DELIMITER ;


-- ============================================================
-- Пользователь client
-- ============================================================

CREATE USER IF NOT EXISTS 'client'@'%'
    IDENTIFIED BY 'Client123!';

GRANT EXECUTE
    ON PROCEDURE catalog_test.get_products
    TO 'client'@'%';

-- ============================================================
-- Пользователь manager
-- ============================================================

CREATE USER IF NOT EXISTS 'manager'@'%'
    IDENTIFIED BY 'Manager123!';

GRANT EXECUTE
    ON PROCEDURE catalog_test.get_orders
    TO 'manager'@'%';


-- ============================================================
-- Заказы и позиции заказов
-- ============================================================

CREATE TABLE IF NOT EXISTS orders (
    order_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    status ENUM('Новый', 'Оплачен', 'Отменён') NOT NULL
);

CREATE TABLE IF NOT EXISTS order_items (
    order_item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL,
    unit_price DECIMAL(10,2) UNSIGNED NOT NULL,

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
        ON DELETE CASCADE
        ON UPDATE RESTRICT,

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES products (product_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT
);

CREATE INDEX idx_orders_created_at
    ON orders (created_at);

CREATE INDEX idx_order_items_order
    ON order_items (order_id);

CREATE INDEX idx_order_items_product
    ON order_items (product_id);


-- ============================================================
-- Генерация тестовых заказов
-- ============================================================

DROP PROCEDURE IF EXISTS generate_orders;

DELIMITER //

CREATE PROCEDURE generate_orders()
BEGIN
    DECLARE v_product_count INT;

    -- Повторный запуск генератора начинает с чистых заказов.
    DELETE FROM order_items;
    DELETE FROM orders;

    -- --------------------------------------------------------
    -- Временный список реально существующих product_id
    -- --------------------------------------------------------

    CREATE TEMPORARY TABLE tmp_products (
        row_num INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        product_id BIGINT UNSIGNED NOT NULL,
        price DECIMAL(10,2) UNSIGNED NOT NULL
    );

    INSERT INTO tmp_products (product_id, price)
    SELECT
        product_id,
        price
    FROM products
    ORDER BY product_id;

    SELECT COUNT(*)
    INTO v_product_count
    FROM tmp_products;


    -- --------------------------------------------------------
    -- 10000 заказов за последние 30 дней
    -- --------------------------------------------------------

    INSERT INTO orders (
        created_at,
        status
    )
    SELECT
        TIMESTAMPADD(
            SECOND,
            -FLOOR(
                RAND(n * 17) *
                TIMESTAMPDIFF(
                    SECOND,
                    DATE_SUB(NOW(), INTERVAL 30 DAY),
                    NOW()
                )
            ),
            NOW()
        ),

        CASE
            WHEN MOD(n, 10) = 0 THEN 'Отменён'
            WHEN MOD(n, 3) = 0 THEN 'Новый'
            ELSE 'Оплачен'
        END

    FROM (
        SELECT
              d1.n
            + d2.n * 10
            + d3.n * 100
            + d4.n * 1000
            + 1 AS n
        FROM
            (
                SELECT 0 AS n UNION ALL SELECT 1 UNION ALL
                SELECT 2 UNION ALL SELECT 3 UNION ALL
                SELECT 4 UNION ALL SELECT 5 UNION ALL
                SELECT 6 UNION ALL SELECT 7 UNION ALL
                SELECT 8 UNION ALL SELECT 9
            ) d1
        CROSS JOIN
            (
                SELECT 0 AS n UNION ALL SELECT 1 UNION ALL
                SELECT 2 UNION ALL SELECT 3 UNION ALL
                SELECT 4 UNION ALL SELECT 5 UNION ALL
                SELECT 6 UNION ALL SELECT 7 UNION ALL
                SELECT 8 UNION ALL SELECT 9
            ) d2
        CROSS JOIN
            (
                SELECT 0 AS n UNION ALL SELECT 1 UNION ALL
                SELECT 2 UNION ALL SELECT 3 UNION ALL
                SELECT 4 UNION ALL SELECT 5 UNION ALL
                SELECT 6 UNION ALL SELECT 7 UNION ALL
                SELECT 8 UNION ALL SELECT 9
            ) d3
        CROSS JOIN
            (
                SELECT 0 AS n UNION ALL SELECT 1 UNION ALL
                SELECT 2 UNION ALL SELECT 3 UNION ALL
                SELECT 4 UNION ALL SELECT 5 UNION ALL
                SELECT 6 UNION ALL SELECT 7 UNION ALL
                SELECT 8 UNION ALL SELECT 9
            ) d4
    ) numbers;


    -- --------------------------------------------------------
    -- По 3 позиции на каждый заказ
    -- --------------------------------------------------------

    INSERT INTO order_items (
        order_id,
        product_id,
        quantity,
        unit_price
    )
    SELECT
        o.order_id,
        tp.product_id,

        1 + MOD(o.order_id + item_no, 5) AS quantity,

        tp.price

    FROM orders o

    CROSS JOIN (
        SELECT 1 AS item_no
        UNION ALL
        SELECT 2
        UNION ALL
        SELECT 3
    ) items

    INNER JOIN tmp_products tp
        ON tp.row_num =
           1 + MOD(
               o.order_id * 17 + item_no * 101,
               v_product_count
           );


    DROP TEMPORARY TABLE tmp_products;
END//

DELIMITER ;


-- ============================================================
-- Отчёт по продажам
-- ============================================================

DROP PROCEDURE IF EXISTS get_orders;

DELIMITER //

CREATE PROCEDURE get_orders(
    IN p_period VARCHAR(10),
    IN p_group_by VARCHAR(20)
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_period_start DATETIME;

    -- --------------------------------------------------------
    -- Проверка периода
    -- --------------------------------------------------------

    CASE p_period
        WHEN 'hour' THEN
            SET v_period_start = DATE_SUB(NOW(), INTERVAL 1 HOUR);

        WHEN 'day' THEN
            SET v_period_start = DATE_SUB(NOW(), INTERVAL 1 DAY);

        WHEN 'week' THEN
            SET v_period_start = DATE_SUB(NOW(), INTERVAL 1 WEEK);

        ELSE
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                    'Период должен быть hour, day или week';
    END CASE;


    -- --------------------------------------------------------
    -- Проверка уровня группировки
    -- --------------------------------------------------------

    IF p_group_by NOT IN (
        'product',
        'category',
        'manufacturer'
    ) THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Группировка должна быть product, category или manufacturer';
    END IF;


    -- --------------------------------------------------------
    -- По товару
    -- --------------------------------------------------------

    IF p_group_by = 'product' THEN

        SELECT
            p.product_id AS group_id,
            p.title AS group_name,
            COUNT(DISTINCT o.order_id) AS orders_count,
            SUM(oi.quantity) AS products_quantity,
            SUM(oi.quantity * oi.unit_price) AS sales_amount

        FROM orders o

        INNER JOIN order_items oi
            ON oi.order_id = o.order_id

        INNER JOIN products p
            ON p.product_id = oi.product_id

        WHERE o.created_at >= v_period_start
          AND o.created_at < NOW()
          AND o.status = 'Оплачен'

        GROUP BY
            p.product_id,
            p.title

        ORDER BY sales_amount DESC;


    -- --------------------------------------------------------
    -- По категории
    -- --------------------------------------------------------

    ELSEIF p_group_by = 'category' THEN

        SELECT
            c.category_id AS group_id,
            c.title AS group_name,
            COUNT(DISTINCT o.order_id) AS orders_count,
            SUM(oi.quantity) AS products_quantity,
            SUM(oi.quantity * oi.unit_price) AS sales_amount

        FROM orders o

        INNER JOIN order_items oi
            ON oi.order_id = o.order_id

        INNER JOIN products p
            ON p.product_id = oi.product_id

        INNER JOIN categories c
            ON c.category_id = p.category_id

        WHERE o.created_at >= v_period_start
          AND o.created_at < NOW()
          AND o.status = 'Оплачен'

        GROUP BY
            c.category_id,
            c.title

        ORDER BY sales_amount DESC;


    -- --------------------------------------------------------
    -- По производителю
    -- --------------------------------------------------------

    ELSEIF p_group_by = 'manufacturer' THEN

        SELECT
            m.manufacturer_id AS group_id,
            m.title AS group_name,
            COUNT(DISTINCT o.order_id) AS orders_count,
            SUM(oi.quantity) AS products_quantity,
            SUM(oi.quantity * oi.unit_price) AS sales_amount

        FROM orders o

        INNER JOIN order_items oi
            ON oi.order_id = o.order_id

        INNER JOIN products p
            ON p.product_id = oi.product_id

        INNER JOIN manufacturers m
            ON m.manufacturer_id = p.manufacturer_id

        WHERE o.created_at >= v_period_start
          AND o.created_at < NOW()
          AND o.status = 'Оплачен'

        GROUP BY
            m.manufacturer_id,
            m.title

        ORDER BY sales_amount DESC;

    END IF;

END//

DELIMITER ;
