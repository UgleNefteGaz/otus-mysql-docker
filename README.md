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
