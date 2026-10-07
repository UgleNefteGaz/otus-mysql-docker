-- ============================================================
-- Оконные функции
-- Тестовые данные магазинов и продаж
-- ============================================================

CREATE DATABASE IF NOT EXISTS window_functions_test
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE window_functions_test;


-- ============================================================
-- Оконные функции
-- Тестовые данные магазинов и продаж
-- ============================================================

DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS stores;

CREATE TABLE stores (
    store_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    address VARCHAR(50) NOT NULL
);

CREATE TABLE sales (
    sale_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    store_id BIGINT UNSIGNED NOT NULL,
    `date` TIMESTAMP NOT NULL,
    sale_amount DECIMAL(10,2) NOT NULL,

    CONSTRAINT fk_sales_store
        FOREIGN KEY (store_id)
        REFERENCES stores (store_id)
);


-- ============================================================
-- 1. Генерация тестовых данных
-- ============================================================

DROP PROCEDURE IF EXISTS generate_sales_data;

DELIMITER //

CREATE PROCEDURE generate_sales_data()
BEGIN

    -- --------------------------------------------------------
    -- 10 магазинов
    -- --------------------------------------------------------

    INSERT INTO stores (address)
    VALUES
        ('Москва, Магазин 01'),
        ('Москва, Магазин 02'),
        ('Москва, Магазин 03'),
        ('Москва, Магазин 04'),
        ('Москва, Магазин 05'),
        ('Москва, Магазин 06'),
        ('Москва, Магазин 07'),
        ('Москва, Магазин 08'),
        ('Москва, Магазин 09'),
        ('Москва, Магазин 10');

    -- --------------------------------------------------------
    -- Временная таблица с цифрами от 0 до 9
    -- --------------------------------------------------------

    CREATE TEMPORARY TABLE digits (
        n TINYINT UNSIGNED PRIMARY KEY
    );

    INSERT INTO digits (n)
    VALUES
        (0), (1), (2), (3), (4),
        (5), (6), (7), (8), (9);

    -- --------------------------------------------------------
    -- Генерация последовательности 1..100000
    -- --------------------------------------------------------

    CREATE TEMPORARY TABLE seq_100000 (
        n INT UNSIGNED PRIMARY KEY
    );

    INSERT INTO seq_100000 (n)
    SELECT
        d1.n
        + d2.n * 10
        + d3.n * 100
        + d4.n * 1000
        + d5.n * 10000
        + 1
    FROM
        (
            SELECT 0 AS n UNION ALL
            SELECT 1 UNION ALL
            SELECT 2 UNION ALL
            SELECT 3 UNION ALL
            SELECT 4 UNION ALL
            SELECT 5 UNION ALL
            SELECT 6 UNION ALL
            SELECT 7 UNION ALL
            SELECT 8 UNION ALL
            SELECT 9
        ) AS d1
    CROSS JOIN
        (
            SELECT 0 AS n UNION ALL
            SELECT 1 UNION ALL
            SELECT 2 UNION ALL
            SELECT 3 UNION ALL
            SELECT 4 UNION ALL
            SELECT 5 UNION ALL
            SELECT 6 UNION ALL
            SELECT 7 UNION ALL
            SELECT 8 UNION ALL
            SELECT 9
        ) AS d2
    CROSS JOIN
        (
            SELECT 0 AS n UNION ALL
            SELECT 1 UNION ALL
            SELECT 2 UNION ALL
            SELECT 3 UNION ALL
            SELECT 4 UNION ALL
            SELECT 5 UNION ALL
            SELECT 6 UNION ALL
            SELECT 7 UNION ALL
            SELECT 8 UNION ALL
            SELECT 9
        ) AS d3
    CROSS JOIN
        (
            SELECT 0 AS n UNION ALL
            SELECT 1 UNION ALL
            SELECT 2 UNION ALL
            SELECT 3 UNION ALL
            SELECT 4 UNION ALL
            SELECT 5 UNION ALL
            SELECT 6 UNION ALL
            SELECT 7 UNION ALL
            SELECT 8 UNION ALL
            SELECT 9
        ) AS d4
    CROSS JOIN
        (
            SELECT 0 AS n UNION ALL
            SELECT 1 UNION ALL
            SELECT 2 UNION ALL
            SELECT 3 UNION ALL
            SELECT 4 UNION ALL
            SELECT 5 UNION ALL
            SELECT 6 UNION ALL
            SELECT 7 UNION ALL
            SELECT 8 UNION ALL
            SELECT 9
        ) AS d5;


    -- --------------------------------------------------------
    -- 100000 продаж
    --
    -- Магазин 1 получает ровно 72% продаж:
    -- 72000 из 100000.
    --
    -- Остальные 28000 распределяются между магазинами 2..10.
    -- --------------------------------------------------------

    INSERT INTO sales (
        store_id,
        `date`,
        sale_amount
    )
    SELECT
        CASE
            WHEN n <= 72000
                THEN 1
            ELSE
                2 + MOD(n - 72001, 9)
        END AS store_id,

        TIMESTAMPADD(
            SECOND,
            -FLOOR(
                RAND(n * 17) *
                TIMESTAMPDIFF(
                    SECOND,
                    DATE_SUB(NOW(), INTERVAL 2 YEAR),
                    NOW()
                )
            ),
            NOW()
        ) AS sale_date,

        ROUND(
            50 + RAND(n * 31) * 9950,
            2
        ) AS sale_amount
    FROM seq_100000;

    DROP TEMPORARY TABLE seq_100000;

END//

DELIMITER ;



-- ============================================================
-- 2. Нарастающий итог продаж по магазинам и месяцам
-- ============================================================

WITH monthly_sales AS (
    SELECT
        store_id,
        DATE_FORMAT(`date`, '%Y-%m-01') AS sale_month,
        SUM(sale_amount) AS monthly_amount
    FROM sales
    GROUP BY
        store_id,
        DATE_FORMAT(`date`, '%Y-%m-01')
)
SELECT
    store_id,
    sale_month,
    monthly_amount,
    SUM(monthly_amount) OVER (
        PARTITION BY store_id
        ORDER BY sale_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM monthly_sales
ORDER BY
    store_id,
    sale_month;



-- ============================================================
-- 3. 7-дневное скользящее среднее по самому плодовитому магазину
--    за последний месяц
-- ============================================================

WITH RECURSIVE
top_store AS (
    SELECT
        store_id
    FROM sales
    GROUP BY store_id
    ORDER BY COUNT(*) DESC, store_id
    LIMIT 1
),

params AS (
    SELECT
        DATE_SUB(
            DATE_SUB(CURDATE(), INTERVAL 1 DAY),
            INTERVAL 1 MONTH
        ) AS report_start,
        DATE_SUB(CURDATE(), INTERVAL 1 DAY) AS report_end
),

calendar AS (
    SELECT
        DATE_SUB(report_start, INTERVAL 6 DAY) AS sale_date,
        report_start,
        report_end
    FROM params

    UNION ALL

    SELECT
        DATE_ADD(sale_date, INTERVAL 1 DAY),
        report_start,
        report_end
    FROM calendar
    WHERE sale_date < report_end
),

daily_sales AS (
    SELECT
        DATE(s.`date`) AS sale_sate,
        SUM(s.sale_amount) AS daily_amount
    FROM sales AS s
    JOIN top_store AS ts
        ON ts.store_id = s.store_id
    CROSS JOIN params AS P
    WHERE s.`date` >= DATE_SUB(p.report_start, INTERVAL 6 DAY)
        AND s.`date` < DATE_ADD(p.report_end, INTERVAL 1 DAY)
    GROUP BY DATE(s.`date`)
),

daily_complete AS (
    SELECT
        c.sale_date,
        c.report_start,
        c.report_end,
        COALESCE(ds.daily_amount, 0) AS daily)_amount
    FROM calendar AS c
    LEFT JOIN daily_sales AS ds
        ON ds.sale_date = c.sale_date
),

moving_average AS (
    SELECT
        sale_date,
        report_start,
        report_end,
        daily_amount,
        AVG(daily_amount) OVER (
            ORDER BY sale_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS moving_avg_7d
    FROM daily_complete
)

SELECT
    sale_date,
    daily_amount,
    ROUND(moving_avg_7d, 2) AS moving_avg_7d
FROM moving_average
WHERE sale_date >= report_start
    AND sale_date <= report_end
ORDER BY sale_date;



-- ============================================================
-- 4. Учтённые граничные случаи
-- ============================================================

-- 1. Неравномерное распределение продаж
--
-- Самый активный магазин получает ровно 72% продаж:
--
--     72000 из 100000
--
-- Распределение задаётся детерминированно, поэтому выполнение
-- условия задания не зависит от случайной генерации.


-- 2. Несколько магазинов с одинаковым количеством продаж
--
-- Самый плодовитый магазин определяется выражением:
--
--     ORDER BY COUNT(*) DESC, store_id
--
-- Если несколько магазинов имеют одинаковое максимальное
-- количество продаж, выбирается магазин с меньшим store_id.
-- Результат остаётся детерминированным.


-- 3. Сначала выполняется месячная агрегация
--
-- Для расчёта нарастающего итога исходные продажи сначала
-- группируются до уровня:
--
--     магазин + месяц
--
-- Только после этого к месячным суммам применяется оконная
-- функция SUM() OVER (...).


-- 4. Нарастающий итог считается отдельно для каждого магазина
--
-- Используется:
--
--     PARTITION BY store_id
--
-- Поэтому при переходе к другому магазину накопление
-- начинается заново.


-- 5. Рамка нарастающего итога указана явно
--
-- Используется:
--
--     ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
--
-- В расчёт входит каждая строка от первого месяца текущего
-- магазина до текущего месяца включительно.


-- 6. ROWS работает со строками, а не с календарными днями
--
-- Выражение:
--
--     ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
--
-- означает текущую строку и 6 предыдущих строк.
--
-- Если дни без продаж отсутствовали бы в наборе данных,
-- 7 строк могли бы соответствовать более чем 7 календарным дням.
--
-- Поэтому перед расчётом среднего создаётся непрерывный
-- календарь.


-- 7. Дни без продаж учитываются как 0
--
-- Календарь соединяется с фактическими дневными продажами
-- через LEFT JOIN.
--
-- Для отсутствующих продаж используется:
--
--     COALESCE(daily_amount, 0)
--
-- Благодаря этому каждый календарный день присутствует
-- в окне и день без продаж участвует в среднем как 0.


-- 8. Первому дню отчётного периода нужны предыдущие 6 дней
--
-- Для полноценного 7-дневного среднего первого отображаемого
-- дня во входные данные добавляются 6 дней до report_start.
--
-- Например:
--
--     отображаемый день: 2026-09-06
--
-- Для его среднего используются данные:
--
--     2026-08-31
--     2026-09-01
--     2026-09-02
--     2026-09-03
--     2026-09-04
--     2026-09-05
--     2026-09-06
--
-- Фильтрация отображаемого периода выполняется только после
-- расчёта оконной функции.


-- 9. Текущий день не используется
--
-- Продажи текущего календарного дня ещё не завершены.
-- Включение такого дня искажало бы дневную сумму и
-- 7-дневное скользящее среднее.
--
-- Поэтому:
--
--     report_end = CURDATE() - 1 DAY
--
-- В отчёт попадает только последний полностью завершённый день.


-- 10. Первый и последний месяцы двухлетнего набора могут
--     содержать неполный месяц
--
-- Продажи генерируются за два года относительно текущего
-- момента, а не от первого числа месяца.
--
-- Поэтому первый и последний месяцы набора могут содержать
-- меньше дней, чем остальные.
--
-- Это корректное поведение и не нарушает расчёт
-- нарастающего итога.


-- 11. DATE/TIMESTAMP и верхняя граница периода
--
-- Для дневной выборки верхняя граница задаётся как:
--
--     date < report_end + INTERVAL 1 DAY
--
-- Это позволяет включить все продажи последнего дня независимо
-- от времени внутри TIMESTAMP и избежать сравнения с
-- 23:59:59.
