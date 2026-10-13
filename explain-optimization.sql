USE catalog_test;

-- ============================================================
-- Исходный сложный запрос
-- ============================================================
--
-- Продажи товаров за последнюю неделю.
-- Выводятся только товары, выручка которых выше средней
-- выручки товара внутри соответствующей категории.
-- ============================================================

SELECT
    p.product_id,
    p.title AS product,
    c.title AS category,
    m.title AS manufacturer,

    COUNT(DISTINCT o.order_id) AS orders_count,
    SUM(oi.quantity) AS products_quantity,
    SUM(oi.quantity * oi.unit_price) AS sales_amount

FROM orders AS o

INNER JOIN order_items AS oi
    ON oi.order_id = o.order_id

INNER JOIN products AS p
    ON p.product_id = oi.product_id

INNER JOIN categories AS c
    ON c.category_id = p.category_id

INNER JOIN manufacturers AS m
    ON m.manufacturer_id = p.manufacturer_id

WHERE
    o.status = 'Оплачен'
    AND o.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)

GROUP BY
    p.product_id,
    p.title,
    c.category_id,
    c.title,
    m.manufacturer_id,
    m.title

HAVING
    SUM(oi.quantity * oi.unit_price) >
    (
        SELECT AVG(category_product_sales.sales_amount)
        FROM (
            SELECT
                p2.product_id,
                SUM(oi2.quantity * oi2.unit_price) AS sales_amount

            FROM orders AS o2

            INNER JOIN order_items AS oi2
                ON oi2.order_id = o2.order_id

            INNER JOIN products AS p2
                ON p2.product_id = oi2.product_id

            WHERE
                o2.status = 'Оплачен'
                AND o2.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
                AND p2.category_id = c.category_id

            GROUP BY
                p2.product_id
        ) AS category_product_sales
    )

ORDER BY
    sales_amount DESC;


-- ============================================================
-- Оптимизация 1
-- Устранение коррелированного DEPENDENT SUBQUERY
-- ============================================================

WITH weekly_product_sales AS (
    SELECT
        p.product_id,
        p.title AS product,

        c.category_id,
        c.title AS category,

        m.manufacturer_id,
        m.title AS manufacturer,

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

    INNER JOIN manufacturers m
        ON m.manufacturer_id = p.manufacturer_id

    WHERE
        o.status = 'Оплачен'
        AND o.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)

    GROUP BY
        p.product_id,
        p.title,
        c.category_id,
        c.title,
        m.manufacturer_id,
        m.title
),

sales_with_average AS (
    SELECT
        product_id,
        product,
        category_id,
        category,
        manufacturer_id,
        manufacturer,
        orders_count,
        products_quantity,
        sales_amount,

        AVG(sales_amount) OVER (
            PARTITION BY category_id
        ) AS category_avg_sales

    FROM weekly_product_sales
)

SELECT
    product_id,
    product,
    category,
    manufacturer,
    orders_count,
    products_quantity,
    sales_amount

FROM sales_with_average

WHERE sales_amount > category_avg_sales

ORDER BY sales_amount DESC;


-- ============================================================
-- Оптимизация 2
-- Составной индекс для фильтрации заказов
-- ============================================================

CREATE INDEX idx_orders_status_created_at
    ON orders (status, created_at);

ANALYZE TABLE orders;
