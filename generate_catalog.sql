DROP PROCEDURE IF EXISTS generate_catalog;

DELIMITER //

CREATE PROCEDURE generate_catalog()
BEGIN
    DECLARE v_category_no INT UNSIGNED DEFAULT 1;
    DECLARE v_category_id BIGINT UNSIGNED;
    DECLARE v_price_base INT UNSIGNED;

    -- Временная последовательность от 1 до 10000
    DROP TEMPORARY TABLE IF EXISTS seq_10000;

    CREATE TEMPORARY TABLE seq_10000 (
        n INT UNSIGNED NOT NULL PRIMARY KEY
    );

    INSERT INTO seq_10000 (n)
    SELECT
        ones.n
        + tens.n * 10
        + hundreds.n * 100
        + thousands.n * 1000
        + 1
    FROM
        (
            SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2
            UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
            UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
            UNION ALL SELECT 9
        ) AS ones
    CROSS JOIN
        (
            SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2
            UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
            UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
            UNION ALL SELECT 9
        ) AS tens
    CROSS JOIN
        (
            SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2
            UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
            UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
            UNION ALL SELECT 9
        ) AS hundreds
    CROSS JOIN
        (
            SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2
            UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
            UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
            UNION ALL SELECT 9
        ) AS thousands;

    START TRANSACTION;

    WHILE v_category_no <= 20 DO

        INSERT INTO categories (title)
        VALUES (
            CONCAT(
                'Категория ',
                LPAD(v_category_no, 2, '0')
            )
        );

        -- Требование задания:
        -- получаем ID только что созданной категории.
        SET v_category_id = LAST_INSERT_ID();

        SET v_price_base = (v_category_no - 1) * 10000;

        INSERT INTO products (
            title,
            category_id,
            price,
            rating,
            status
        )
        SELECT
            CONCAT(
                'Товар ',
                LPAD(v_price_base + n, 6, '0')
            ),
            v_category_id,

            -- Цена глобально уникальна:
            -- от 1.00 до 200000.00.
            v_price_base + n,

            -- Рейтинг от 1 до 5.
            MOD(v_price_base + n - 1, 5) + 1,

            -- Примерно половина товаров каждого статуса.
            IF(
                MOD(v_price_base + n, 2) = 0,
                'В наличии',
                'Распродан'
            )
        FROM seq_10000;

        SET v_category_no = v_category_no + 1;

    END WHILE;

    COMMIT;

    DROP TEMPORARY TABLE seq_10000;
END//

DELIMITER ;
