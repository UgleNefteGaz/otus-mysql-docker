-- ============================================================
-- Агрегация данных каталога
-- ============================================================

USE catalog_test;


-- ============================================================
-- 1. GROUP BY + CASE + HAVING
-- ============================================================
-- Для каждой категории считаем:
-- - общее количество товаров;
-- - количество товаров в наличии;
-- - количество распроданных товаров.
--
-- HAVING оставляет категории, где в наличии не менее 5000 товаров.

SELECT
    c.category_id,
    c.title AS category,
    COUNT(*) AS total_products,

    SUM(
        CASE
            WHEN p.status = 'В наличии' THEN 1
            ELSE 0
        END
    ) AS in_stock,

    SUM(
        CASE
            WHEN p.status = 'Распродан' THEN 1
            ELSE 0
        END
    ) AS sold_out

FROM categories c
JOIN products p
    ON p.category_id = c.category_id

GROUP BY
    c.category_id,
    c.title

HAVING SUM(
    CASE
        WHEN p.status = 'В наличии' THEN 1
        ELSE 0
    END
) >= 5000

ORDER BY c.category_id;


-- ============================================================
-- 1.2 GROUP BY + ROLLUP + GROUPING()
-- ============================================================
-- Количество предложений по категориям и статусам.
--
-- ROLLUP добавляет:
-- - итог по каждой категории;
-- - общий итог по всему каталогу.
--
-- GROUPING() позволяет определить итоговые строки.

SELECT
    CASE
        WHEN GROUPING(c.title) = 1 THEN 'ИТОГО'
        ELSE c.title
    END AS category,

    CASE
        WHEN GROUPING(p.status) = 1 THEN 'ВСЕ СТАТУСЫ'
        ELSE p.status
    END AS status,

    COUNT(*) AS product_count

FROM categories c
JOIN products p
    ON p.category_id = c.category_id

GROUP BY
    c.title,
    p.status
WITH ROLLUP;


-- ============================================================
-- 2. Список товаров + MIN/MAX/COUNT по категории
-- ============================================================
-- Расширяем предыдущий список товаров.
--
-- Для каждого товара дополнительно выводим:
-- - минимальную цену в его категории;
-- - максимальную цену в его категории;
-- - количество предложений в категории.
--
-- Оконные функции не сворачивают список товаров.

SELECT
    p.product_id,
    p.title,
    c.title AS category,
    p.price,
    p.rating,
    p.status,

    MIN(p.price) OVER (
        PARTITION BY p.category_id
    ) AS min_price_in_category,

    MAX(p.price) OVER (
        PARTITION BY p.category_id
    ) AS max_price_in_category,

    COUNT(*) OVER (
        PARTITION BY p.category_id
    ) AS offers_in_category

FROM products p
JOIN categories c
    ON c.category_id = p.category_id

ORDER BY
    p.status,
    p.price

LIMIT 50;


-- ============================================================
-- 3. Самый дешёвый и самый дорогой товар каждой категории
-- ============================================================

WITH category_prices AS (
    SELECT
        p.product_id,
        p.title,
        p.category_id,
        c.title AS category,
        p.price,

        MIN(p.price) OVER (
            PARTITION BY p.category_id
        ) AS min_price,

        MAX(p.price) OVER (
            PARTITION BY p.category_id
        ) AS max_price

    FROM products p
    JOIN categories c
        ON c.category_id = p.category_id
)

SELECT
    category_id,
    category,
    title,
    price,

    CASE
        WHEN price = min_price AND price = max_price
            THEN 'Минимальная и максимальная'
        WHEN price = min_price
            THEN 'Минимальная'
        WHEN price = max_price
            THEN 'Максимальная'
    END AS price_type

FROM category_prices

WHERE price = min_price
   OR price = max_price

ORDER BY
    category_id,
    price;


-- ============================================================
-- 4. ROLLUP количества товаров по категориям
-- ============================================================

SELECT
    CASE
        WHEN GROUPING(c.category_id) = 1 THEN 'ИТОГО'
        ELSE MAX(c.title)
    END AS category,

    COUNT(*) AS product_count

FROM categories c
JOIN products p
    ON p.category_id = c.category_id

GROUP BY c.category_id
WITH ROLLUP;
