USE catalog_test;

-- ============================================================
-- PAGINATION
-- ============================================================


-- ============================================================
-- 1. Требуемый общий порядок
-- ============================================================
-- Сначала товары "В наличии" по возрастанию цены,
-- затем товары "Распродан" по возрастанию цены.
--
-- status является ENUM:
-- 1 = В наличии
-- 2 = Распродан

SELECT
    product_id,
    title,
    category_id,
    price,
    rating,
    status
FROM products
ORDER BY status, price
LIMIT 50;


-- ============================================================
-- 2. Обычная OFFSET-пагинация
-- ============================================================
-- Работает функционально, но становится неэффективной
-- на глубоких страницах.
--
-- Например, для OFFSET 149950 MySQL должен обработать
-- большое количество предыдущих строк, чтобы вернуть только 50.

EXPLAIN
SELECT
    product_id,
    title,
    category_id,
    price,
    rating,
    status
FROM products
ORDER BY status, price
LIMIT 50 OFFSET 149950;


-- ============================================================
-- 3. Keyset pagination
-- ============================================================
-- Для последовательного просмотра страниц вместо OFFSET
-- используется значение последней цены предыдущей страницы.


-- Первая страница товаров "В наличии".

SELECT
    product_id,
    title,
    category_id,
    price,
    rating,
    status
FROM products
WHERE status = 'В наличии'
ORDER BY price
LIMIT 50;


-- Следующая страница.
-- :last_price заменяется последней ценой предыдущей страницы.
--
-- Например, после первой страницы:
-- last_price = 100.00

SELECT
    product_id,
    title,
    category_id,
    price,
    rating,
    status
FROM products
WHERE status = 'В наличии'
  AND price > 100.00
ORDER BY price
LIMIT 50;


-- После завершения товаров "В наличии"
-- начинается выдача товаров "Распродан".

SELECT
    product_id,
    title,
    category_id,
    price,
    rating,
    status
FROM products
WHERE status = 'Распродан'
ORDER BY price
LIMIT 50;


-- Пример глубокой страницы среди распроданных товаров.

SELECT
    product_id,
    title,
    category_id,
    price,
    rating,
    status
FROM products
WHERE status = 'Распродан'
  AND price > 99999.00
ORDER BY price
LIMIT 50;


-- ============================================================
-- 4. Проверка плана keyset pagination
-- ============================================================

EXPLAIN
SELECT
    product_id,
    title,
    category_id,
    price,
    rating,
    status
FROM products
WHERE status = 'Распродан'
  AND price > 99999.00
ORDER BY price
LIMIT 50;
