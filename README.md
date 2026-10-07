# MySQL в Docker

Учебный проект по запуску MySQL в Docker с автоматическим созданием собственной базы данных, пользовательской конфигурацией MySQL и нагрузочным тестированием с помощью Sysbench.

## Цель работы

В рамках задания выполнено:

- использован стартовый Docker-репозиторий;
- создан SQL-скрипт `init.sql`;
- настроено автоматическое создание собственной базы данных;
- добавлена пользовательская конфигурация MySQL;
- настроены параметры InnoDB;
- проверен повторный запуск контейнера;
- проведено нагрузочное тестирование с помощью Sysbench;
- результаты тестирования сохранены в репозитории.

## Структура проекта

```text
otus-mysql-docker/
├── README.md
├── catalog-schema.sql
├── generate_catalog.sql
├── pagination.sql
├── custom.conf/
│   └── my.cnf
├── docker-compose.yml
├── init.sql
└── results/
    └── sysbench-results.txt
```

## Docker Compose

Для запуска используется образ:

```text
mysql:8.0.15
```

MySQL внутри контейнера работает на стандартном порту:

```text
3306
```

На хосте он доступен через:

```text
3309
```

Основные volume mappings:

```text
data                  -> /var/lib/mysql
./init.sql            -> /init.sql
./custom.conf         -> /etc/mysql/conf.d
```

SQL-скрипт запускается через параметр MySQL:

```text
--init-file /init.sql
```

## Запуск контейнера

Запуск:

```bash
docker compose up -d otusdb
```

Проверка состояния:

```bash
docker compose ps
```

Просмотр логов:

```bash
docker compose logs --tail=100 otusdb
```

При успешном запуске MySQL должен перейти в состояние:

```text
ready for connections
```

## База данных

При запуске контейнера `init.sql` автоматически создаёт базу:

```text
production_mysql
```

Используется кодировка:

```text
utf8mb4
```

и collation:

```text
utf8mb4_unicode_ci
```

## Структура базы данных

Создаются четыре связанные таблицы:

```text
products
    |
    v
production_orders
    |
    v
production_batches
    |
    v
quality_checks
```

### products

Хранит выпускаемую продукцию.

Основные поля:

```text
product_id
article
name
unit
```

### production_orders

Хранит производственные заказы.

Основные поля:

```text
order_id
order_number
product_id
planned_quantity
status
created_at
```

Связь:

```text
production_orders.product_id
    ->
products.product_id
```

### production_batches

Хранит производственные партии.

Основные поля:

```text
batch_id
order_id
batch_number
planned_quantity
actual_quantity
status
```

Связь:

```text
production_batches.order_id
    ->
production_orders.order_id
```

### quality_checks

Хранит результаты контроля качества партий.

Основные поля:

```text
quality_check_id
batch_id
result
checked_at
notes
```

Связь:

```text
quality_checks.batch_id
    ->
production_batches.batch_id
```

Все таблицы используют:

```text
ENGINE=InnoDB
```

## Начальные данные

При запуске контейнера автоматически добавляются:

```text
products:        3
production_orders: 3
production_batches: 4
quality_checks:  3
```

Для повторного безопасного выполнения `init.sql` используются:

```sql
CREATE DATABASE IF NOT EXISTS
CREATE TABLE IF NOT EXISTS
INSERT IGNORE
```

Это позволяет повторно запускать контейнер без создания дублирующихся данных.

## Проверка базы

Список баз данных:

```bash
docker compose exec otusdb \
  mysql -u root -p12345 \
  -e "SHOW DATABASES;"
```

Список таблиц:

```bash
docker compose exec otusdb \
  mysql -u root -p12345 production_mysql \
  -e "SHOW TABLES;"
```

Проверка данных:

```bash
docker compose exec otusdb \
  mysql -u root -p12345 production_mysql \
  -e "
SELECT * FROM products;
SELECT * FROM production_orders;
SELECT * FROM production_batches;
SELECT * FROM quality_checks;
"
```

## Проверка повторного запуска

До перезапуска контейнера:

```bash
docker compose exec otusdb \
  mysql -u root -p12345 production_mysql \
  -e "
SELECT COUNT(*) AS products FROM products;
SELECT COUNT(*) AS orders_count FROM production_orders;
SELECT COUNT(*) AS batches FROM production_batches;
SELECT COUNT(*) AS quality_checks FROM quality_checks;
"
```

Результат:

```text
products        3
orders_count    3
batches         4
quality_checks  3
```

После:

```bash
docker compose restart otusdb
```

количество записей осталось тем же:

```text
products        3
orders_count    3
batches         4
quality_checks  3
```

Таким образом, повторный запуск контейнера не создаёт дублирующиеся данные.

# Пользовательская конфигурация MySQL

Дополнительные параметры находятся в:

```text
custom.conf/my.cnf
```

Использованная конфигурация:

```ini
[mysqld]

# Authentication
default-authentication-plugin=mysql_native_password

# Character set
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# InnoDB
innodb_buffer_pool_size=256M
innodb_buffer_pool_instances=1
innodb_log_file_size=128M
innodb_file_per_table=ON

# Connections
max_connections=100

# Slow query log
slow_query_log=ON
long_query_time=1

[client]
default-character-set=utf8mb4

[mysql]
default-character-set=utf8mb4
```

## InnoDB Buffer Pool

Основной изменённый параметр:

```text
innodb_buffer_pool_size=256M
```

Buffer Pool используется InnoDB для хранения в оперативной памяти страниц таблиц и индексов.

Чем больше данных может храниться в Buffer Pool, тем реже MySQL требуется обращаться к диску.

Фактическое значение:

```text
268435456 bytes
```

что соответствует:

```text
256 MiB
```

## Другие параметры

Настроено:

```text
innodb_buffer_pool_instances = 1
innodb_log_file_size         = 128M
innodb_file_per_table        = ON
max_connections              = 100
slow_query_log               = ON
long_query_time              = 1
```

Также сервер и клиент MySQL используют:

```text
utf8mb4
```

Проверка параметров:

```bash
docker compose exec otusdb \
  mysql -u root -p12345 \
  -e "
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
SHOW VARIABLES LIKE 'innodb_buffer_pool_instances';
SHOW VARIABLES LIKE 'innodb_log_file_size';
SHOW VARIABLES LIKE 'innodb_file_per_table';
SHOW VARIABLES LIKE 'max_connections';
SHOW VARIABLES LIKE 'slow_query_log';
SHOW VARIABLES LIKE 'long_query_time';
SHOW VARIABLES LIKE 'character_set_server';
SHOW VARIABLES LIKE 'collation_server';
"
```

Фактические значения:

```text
innodb_buffer_pool_size       268435456
innodb_buffer_pool_instances  1
innodb_log_file_size          134217728
innodb_file_per_table         ON
max_connections               100
slow_query_log                ON
long_query_time               1.000000
character_set_server          utf8mb4
collation_server              utf8mb4_unicode_ci
```

# Тестирование производительности с Sysbench

Для нагрузочного тестирования использовался:

```text
sysbench 1.0.20
```

## Подготовка тестовой базы

Создана отдельная база:

```sql
CREATE DATABASE IF NOT EXISTS sbtest;
```

Подготовка данных:

```bash
sysbench oltp_read_write \
  --db-driver=mysql \
  --mysql-host=127.0.0.1 \
  --mysql-port=3309 \
  --mysql-user=root \
  --mysql-password=12345 \
  --mysql-db=sbtest \
  --tables=4 \
  --table-size=100000 \
  prepare
```

Sysbench создал:

```text
sbtest1
sbtest2
sbtest3
sbtest4
```

Каждая таблица содержала:

```text
100000 строк
```

Общий объём тестовых данных:

```text
400000 строк
```

## Параметры нагрузочного теста

Тест запускался командой:

```bash
sysbench oltp_read_write \
  --db-driver=mysql \
  --mysql-host=127.0.0.1 \
  --mysql-port=3309 \
  --mysql-user=root \
  --mysql-password=12345 \
  --mysql-db=sbtest \
  --tables=4 \
  --table-size=100000 \
  --threads=4 \
  --time=60 \
  --report-interval=10 \
  --percentile=95 \
  run
```

Параметры:

```text
Тип теста:           oltp_read_write
Количество таблиц:   4
Строк в таблице:     100000
Количество потоков:  4
Продолжительность:   60 секунд
Процентиль:          95
```

## Результат Sysbench

```text
SQL statistics:
    queries performed:
        read:                            328692
        write:                           93912
        other:                           46956
        total:                           469560

    transactions:                        23478  (391.20 per sec.)
    queries:                             469560 (7824.06 per sec.)
    ignored errors:                      0      (0.00 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          60.0146s
    total number of events:              23478

Latency (ms):
         min:                            7.65
         avg:                           10.22
         max:                           37.65
         95th percentile:               12.30
         sum:                       239931.53

Threads fairness:
    events (avg/stddev):           5869.5000/4.15
    execution time (avg/stddev):   59.9829/0.00
```

## Анализ результата

Средняя производительность составила:

```text
391.20 транзакций в секунду
7824.06 SQL-запросов в секунду
```

За 60 секунд выполнено:

```text
23478 транзакций
469560 SQL-запросов
```

Средняя задержка:

```text
10.22 ms
```

95-й процентиль:

```text
12.30 ms
```

Это означает, что 95% транзакций завершались не дольше чем примерно за 12.30 мс.

Максимальная зафиксированная задержка:

```text
37.65 ms
```

Во время теста ошибок и переподключений не было:

```text
ignored errors: 0
reconnects:     0
```

Промежуточные результаты:

```text
10s: 375.47 TPS
20s: 396.41 TPS
30s: 393.10 TPS
40s: 394.30 TPS
50s: 391.30 TPS
60s: 396.80 TPS
```

TPS в течение теста находился примерно в диапазоне:

```text
375-397 транзакций в секунду
```

Это показывает достаточно стабильную работу MySQL на протяжении всего теста.

Полный необработанный вывод Sysbench находится в:

```text
results/sysbench-results.txt
```

# Работа с каталогом товаров

## Цель

В рамках дополнительного задания реализована тестовая база `catalog_test` для проверки типов данных, генерации большого объёма данных и эффективной постраничной выборки в MySQL.

Работа выполнялась на `MySQL 8.0.15`.

## Корректировка типов данных

Исходная структура таблиц `categories` и `products` была проанализирована и скорректирована.

Основные изменения:

- `products.category_id` изменён с `VARCHAR(32)` на `BIGINT UNSIGNED`, чтобы тип внешнего ключа совпадал с `categories.category_id`;
- `price` изменён с `INT` на `DECIMAL(10,2) UNSIGNED`;
- для `price` добавлены `NOT NULL` и `UNIQUE`;
- `rating` изменён с `INT` на `TINYINT UNSIGNED`;
- `status` изменён с `VARCHAR(32)` на `ENUM('В наличии', 'Распродан')`;
- обязательные поля объявлены `NOT NULL`;
- создан внешний ключ между товарами и категориями.

Цена должна быть строго больше нуля, а рейтинг должен находиться в диапазоне от 1 до 5.

Используемая версия MySQL 8.0.15 ещё не применяет `CHECK` как полноценное ограничение, поэтому проверки диапазонов цены и рейтинга реализованы триггерами `BEFORE INSERT` и `BEFORE UPDATE`.

Практически проверено, что база отклоняет:

- цену `0`;
- рейтинг `6`;
- неизвестное значение `status`;
- ссылку на несуществующую категорию.

Корректная запись успешно добавляется. Полная схема находится в `catalog-schema.sql`.

## Генерация тестовых данных

Создана хранимая процедура:

```text
generate_catalog
```

Процедура:

1. создаёт 20 категорий;
2. после вставки каждой категории получает её идентификатор через `LAST_INSERT_ID()`;
3. создаёт 10000 товаров для текущей категории;
4. формирует глобально уникальные цены;
5. назначает рейтинг от 1 до 5;
6. распределяет товары между статусами `В наличии` и `Распродан`.

Для генерации 10000 строк используется временная последовательность, сформированная через `CROSS JOIN`. Вместо выполнения 10000 отдельных `INSERT` для каждой категории используется один `INSERT ... SELECT`.

Фактический результат:

```text
Категорий:		20
Товаров:		200000
Товаров в категории:	10000
Уникальных цен:		200000
Минимальная цена:	1.00
Максимальная цена:	200000.00
```

Время генерации на тестовой системе составило примерно `3 секунды`.

Скрипт находится в `generate_catalog.sql`.

## Сортировка товаров

По условию задания требуется:

1. сначала вывести все товары `В наличии`;
2. внутри этой группы отсортировать товары по возрастанию цены;
3. затем вывести товары `Распродан`;
4. внутри второй группы также отсортировать товары по возрастанию цены.

Поле `status` определено как `ENUM('В наличии', 'Распродан')`. Базовая выборка:

```sql
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
```

Дополнительно создан индекс:

```sql
CREATE INDEX idx_products_status_price
ON products (status, price);
```

## Постраничная выдача

Обычная пагинация MySQL может использовать:

```sql
LIMIT 50 OFFSET 149950
```

`EXPLAIN` показал:

```text
type = ALL
rows = 199390
Using filesort
```

Для последовательной навигации используется keyset pagination. Вместо номера страницы сохраняется значение последней цены предыдущей страницы.

Пример:

```sql
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
```

Для этого запроса `EXPLAIN` показал:

```text
type = range
key = uq_products_price
Using index condition
Using where
```

`Using filesort` отсутствует.

Таким образом, для последовательного просмотра большого количества данных keyset pagination эффективнее глубокого `OFFSET`.

При необходимости перехода сразу на произвольную страницу, например страницу 1000, можно использовать `OFFSET`. Для последовательных переходов `Следующая` и `Предыдущая` предпочтительнее keyset pagination. Полный набор запросов находится в `pagination.sql`.

## Импорт данных из CSV

Для проверки импорта используется файл:

```text
data/users.csv
```

Содержимое:

```text
admin@example.com,Москва
user@example.com,Волгоград
quest@example.com,\N
```

Файл содержит две колонки:

```text
email
city
```

Значение `\N` используется для представления `NULL`.

### LOAD DATA

Для импорта данных используется `LOAD DATA LOCAL INFILE`.

На сервере MySQL предварительно включена переменная:

```sql
SET GLOBAL local_infile = 1;
```

Импорт выполняется запросом:

```sql
LOAD DATA LOCAL INFILE '/tmp/users.csv'
INTO TABLE users
CHARACTER SET utf8mb4
FIELD TERMINATED BY ','
LINES TERMINATED BY '\n'
(email, city);
```

Клиент MySQL запускается с параметром:

```text
--local-infile=1
```

После иморта загружено 3 записи.

Значение `\N` для пользователя `guest@example.com` было преобразовано в SQL `NULL`.

### mysqlimport

Перед проверкой второго способа таблица была очищена:

```sql
TRUNCATE TABLE users;
```

Импорт выполнен утилиой:

```bash
mysqlimport \
  --local \
  --users=root \
  --password \
  --default-character-set=utf8mb4 \
  --fields-terminated-by=',' \
  --lines-terminated-by='\n' \
  --column=email,city \
  import_test \
  /tmp/users.csv
```

Результат:

```text
Records: 3
Deleted: 0
Skipped: 0
Warnings: 0
```

Итоговая проверка показала 3 записи в таблице `users`.

Оба способа успешно загрузили исходный CSV:

- `LOAD DATA LOCAL INFILE`;
- `mysqlimport`.

## Агрегация данных

В `aggregate-queries.sql` реализованы практические примеры агрегации данных каталога.

### CASE и HAVING

Для каждой категории рассчитываются:

- общее количество товаров;
- количество товаров в наличии;
- количество распроданных товаров.

Для условного подсчёта используется:

```sql
SUM(
    CASE
        WHEN p.status = 'В наличии' THEN 1
        ELSE 0
    END
)
```

После группировки используется `HAVING` для фильтрации категорий по рассчитанному агрегатному значению.

На тестовом наборе категория содержит:

```text
Всего товаров:	10000
В наличии:	5000
Распродано:	5000
```

### ROLLUP и GROUPING()

Для группировки товаров по категориям и статусам используется:

```sql
GROUP BY
    c.title,
    p.status
WITH ROLLUP
```

`ROLLUP` формирует промежуточные и общие итоги.

Для определения итоговых строк используется функция `GROUPING()`:

```sql
CASE
    WHEN GROUPING(c.title) =1 THEN 'ИТОГО'
    ELSE c.title
END
```

Общее количество товаров:

```text
200000
```

### Минимальная, максимальная цена и количество предложений

К каждой строке списка товаров добавлены агрегаты по категории с помощью оконных функций:

```sql
MIN(price) OVER (PARTITION BY category_id)
MAX(price) OVER (PARTITION BY category_id)
COUNT(*) OVER (PARTITION BY category_id)
```

Это позволяет сохранить исходный список товаров и одновременно показать:

- минимальную цену в категории;
- максимальную цену в категории;
- количество предложений в категории.

### Самый дешёвый и самый дорогой товар

С помощью оконных функций для каждой категории определяются:

```text
MIN(price)
MAX(price)
```

После этого выбираются товары, цена которых совпадает с минимальной или максимальной ценой категории.

На тестовом наборе из 20 категорий получено:

```text
20 минимальных товаров
20 максимальных товаров
40 строк всего
```

### Количество товаров с ROLLUP

Количество товаров группируется по категориям:

```sql
GROUP BY c.category_id
WITH ROLLUP
```

Результат:

```text
Категория 01	10000
Категория 02	10000
...
Категория 20	10000
ИТОГО		200000
```

### Оконные функции

В `window-functions.sql` реализована практическая работа с оконными функциямии MySQL 8.

 Создаются таблицы:

```text
stores
sales
```

Хранимая процедура `generate_sales_data()` генерирует:

```text
10 магазинов
100000 продаж
2 года истории
```

Продажи распределены неравномерно. Первый магазин получает:

```text
72000 из 100000 продаж
72%
```

Оставшиеся 28% распределяются между остальными девятью магазинами.

#### Нарастающий итог по месяцам

Продажи сначала агрегируются по магазину и месяцу, после чего используется оконная функция:

```sql
SUM(monthly_amount) OVER (
    PARTITION BY store_id
    ORDER BY sale_month
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)
```

`PARTITION BY store_id` создаёт независимое окно для каждого магазина. `ORDER BY sale_month` определяет порядок накопления. Рамка:

 ```sql
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
```

означает расчёт суммы от первого месяца магазина до текущего месяца включительно.

#### 7-дневное скользящее среднее

Самый плодовитый магазин определяется по количеству продаж:

```sql
ORDER BY COUNT(*) DESC, store_id
LIMIT 1
```

Для дневных сумм применяется:

```sql
AVG(daily_amount) OVER (
    ORDER BY sale_date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
)
```

Это текущий день и шесть предыдущих строк.

Чтобы семь строк всегда соответствовали семи календарным дням, перед расчётом создаётся непрерывный календарь. Дни без продаж добавляются через `LEFT JOIN`, а отсутствующая сумма заменяется на `0` через `COALESCE`. Для корректного среднего в начале отчётного периода в расчёт дополнительно включаются 6 предыдущих дней. Они участвуют в оконной функции, но не отображаются в итоговом результате. Текущий незавершённый день исключается из отчёта. Последним днём периода является предыдущий полностью заврешённый календарный день.

Учтены следующие граничные случаи:

- неравномерное распределение продаж между магазинами;
- одинаковое количество продаж у нескольких магазинов;
- независимый нарастающий итог для каждого магазина;
- отсутствие продаж в отдельные календарные дни;
- первые шесть дней скользящего окна;
- назавершённый текущий день;
- неполные первый и последний месяцы двухлетнего периода;
- корректная обработка временной верхней границы для `TIMESTAMP`.

Фактическая проверка тестовых данных показала:

```text
stores: 10
sales: 100000
самый плодовитый магазин: 72000 продаж
доля самого плодовитого магазина: 72.00%
```

# Итог

В рамках работы была создана воспроизводимая среда MySQL в Docker.

Контейнер автоматически:

- запускает MySQL 8.0.15;
- создаёт базу `production_mysql`;
- создаёт связанные таблицы InnoDB;
- добавляет начальные данные;
- использует пользовательский конфигурационный файл;
- применяет настроенный InnoDB Buffer Pool;
- поддерживает корректную работу с UTF-8.

Дополнительно проведён нагрузочный тест Sysbench с использованием 4 потоков и 400000 тестовых строк.

При тесте `oltp_read_write` сервер показал около 391 TPS и 7824 QPS при средней задержке 10.22 мс и без ошибок.
