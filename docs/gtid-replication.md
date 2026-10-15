# Асинхронная GTID-репликация Source-Replica

## Цель работы

Настроить два экземпляра Percona Server for MySQL по топологии:

```text
Source -> Replica
```

Необходимо:

- настроить асинхронную репликацию;
- использовать GTID;
- загрузить данные на Source;
- запустить Replica уже с начальными данными;
- перевести Replica в режим read-only;
- настроить выборочную репликацию;
- исключить из репликации отдельную таблицу и отдельную базу данных;
- проверить работу репликации на практике.

## Используемое ПО

Для работы использовался `Percona Server for MySQL 8.0.41-32`. Были запущены два независимых экземпляра сервера.

Source:

```text
server-id	= 101
port		= 3310
```

Replica:

```text
server-id	= 102
port		3311
```

UUID серверов:

Source:

```text
4dd4a746-c7d6-11f1-a979-00155d6b5f28
```

Replica:

```text
715561b8-c7d6-11f1-aa77-00155d6b5f28
```

UUID различаются, что необходимо для корректной работы репликации.

## Схема

```text
                asynchronous GTID replication

Source ------------------------------------------> Replica

127.0.0.1:3310                                   127.0.0.1:3311
server-id=101                                    server-id=102

GTID=ON                                          GTID=ON
binary log=ON                                    relay log
binlog_format=ROW                                read_only=ON
                                                  super_read_only=ON
```

## Настройка Source

На Cource были включены binary log и GTID:

```ini
server-id=101

log-bin=source-bin
binlog_format=ROW

gtid_mode=ON
enforce_gtid_consistency=ON
```

Проверка показала:

```text
server_id                = 101
port                     = 3310
gtid_mode                = ON
enforce_gtid_consistency = ON
log_bin                  = 1
binlog_format            = ROW
```

## Настройка Replica

На Replica настроены:

```ini
server-id=102

log-bin=replica-bin
relay-log=replica-relay-bin

binlog_format=ROW

gtid_mode=ON
enforce_gtid_consistency=ON

log_replica_updates=ON

read_only=ON
super_read_only=ON

skip_replica_start=ON
```

Проверка:

```text
server_id                = 102
port                     = 3311
gtid_mode                = ON
enforce_gtid_consistency = ON
read_only                = 1
super_read_only          = 1
```

## Тестовые данные

На Source была создана база:

```text
app
```

В ней созданы таблицы:

```text
customers
orders
audit_log
```

Также была создана отдельная база:

```text
replica_excluded
```

с таблицей:

```text
secret_data
```

Логика выборочной репликации:

```text
app.customers		реплицируется
app.orders		реплицируется

app.audit_log		не реплицируется
replica_excluded	не рпелицируется
```

## Начальная загрузка Replica

Replica должна была стартовать не с пустой базы, а уже с начальными данными. Для этого на Source был создан логический dump:

```bash
mysqldump \
  --single-transaction \
  --set-gtid-purged=ON \
  --routines \
  --triggers \
  --databases app \
  --ignore-table=app.audit_log \
  > initial.sql
```

В dump присутствовал GTID-набор:

```sql
SET @@GLOBAL.GTID_PURGED=
'4dd4a746-c7d6-11f1-a979-00155d6b5f28:1-12';
```

Это означает, что Replica после загрузки snapshot знает:

```text
GTID 1-12 уже содержатся в начальных данных
```

После импорта dump на Replica:

```text
GTID_EXECUTED =
4dd4a746-c7d6-11f1-a979-00155d6b5f28:1-12

GTID_PURGED =
4dd4a746-c7d6-11f1-a979-00155d6b5f28:1-12
```

Таким образом, Replica была запущена сразу с начальными данными.

## Настройка выборочной репликации

На реплика были добавлены фильтры:

```ini
replicate-wild-ignore-table=replica_excluded.%
replicate-wild-ignore-table=app.audit_log
```

Их наличие было подтверждено через Performance Schema:

```text
FILTER_NAME:
REPLICATE_WILD_IGNORE_TABLE

FILTER_RULE:
replica_excluded.%,app.audit_log

CONFIGURED_BY:
STARTUP_OPTIONS
```

После загрузки начального dump на Replica присутствовали:

```text
app.customers
app.orders
```

При этом отсутствовали:

```text
app.audit_log
replica_excluded
```

## Настройка replication channel

На replica был настроен Source:

```sql
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST='127.0.0.1',
    SOURCE_PORT=3310,
    SOURCE_USER='repl',
    SOURCE_PASSWORD='repl_password',
    SOURCE_AUTO_POSITION=1,
    GET_SOURCE_PUBLIC_KEY=1;
```

После этого репликация была запущена:

```sql
START REPLICA;
```

Параметр:

```text
SOURCE_AUTO_POSITION=1
```

означает использование GTID auto-position.

При этом не требуется вручную задавать:

```text
binary log file
binery log position
```

Replica сама определяет, какие GTID ей ещё необходимо получить.

## Проверка состояния репликации

После запуска:

```text
Source_Host: 127.0.0.1
Source_Port: 3310

Replica_IO_Running: Yes
Replica_SQL_Running: Yes

Seconds_Behind_Source: 0

Last_IO_Error:
Last_SQL_Error:

Auto_Position: 1
```

Оба replication thread работают. Ошибки отсуствуют. Отставание Replica от Source равно нулю.

## Проверка обычной репликации

На Source был добавлен новый клиент:

```text
ID		= 5
customer_id	= 4
amount		= 500.00
status		= PAID
```

После выполнения транзакций данные появились на Replica в том же виде. GTID после выполнения операций:

```text
Retrieved_Gtid_Set:
4dd4a746-c7d6-11f1-a979-00155d6b5f28:13-14

Executed_Gtid_Set:
4dd4a746-c7d6-11f1-a979-00155d6b5f28:1-14
```

`Retrieved_Gtid_Set` содержит GTID, полученные через replication channel. `Executed_Gtid_Set` содержит все GTID, которые Replica считает уже обработанными. GTID `1-12` были получены из initial dump. GTID `13-14` были получены уже через репликацию.

## Проверка выборочной репликации

После запуска replication channel на Source были добавлены данные в исключённые объекты. В таблицу `app.audit_log` была добавлена новая запись. В таблицу `replica_excluded.secret_data` также была добавлена новая запись. На Source после этого:

```text
audit_log	= 3 строки
secret_data	= 3 строки
```

На Replica по-прежнему существовали только `app.customers` и `app.orders`. Таблица `app.audit_log` и база `replica_excluded` не появились. Таким образом, мы убедились, что фильтрация работает.

## GTID и отфильтрованные транзакции

После операций с исключёнными таблицами Replica имела:

```text
Retrieved_Gtid_Set:
4dd4a746-c7d6-11f1-a979-00155d6b5f28:13-16

Executed_Gtid_Set:
4dd4a746-c7d6-11f1-a979-00155d6b5f28:1-16
```

GTID отфильтрованных транзакций также считаются обработанными. Это необходимо, чтобы Replica не пыталась получить и обработать эти транзакции повторно. Логика такая:

```text
GTID получен
    |
    v
проверка replication filter
    |
    +---- объект разрешён ----> применить изменения
    |
    +---- объект исключён ----> отбросить изменения
                                GTID всё равно обработан
```

## Проверка режима read-only

На Replica были включены:

```ini
read_only=ON
super_read_only=ON
```

Была выполнена попытка прямой записи:

```sql
INSERT INTO app.customers (name, email)
VALUES ('Should Fail', 'fail@example.com');
```

Replica вернула:

```text
ERROR 1290 (HY000):
The MySQL server is running with the --super-read-only option
so it cannot execute this statement
```

Таким образом, обычный клиент не может изменять данные Replica. При этом replication applier продолжает применять изменения, полученные от Source.

## Демонстрация асинхронной репликации

Для проверки асинхронного поведения на Replica был остановлен только SQL thread:

```sql
STOP REPLICA SQL_THREAD;
```

После этого состояние стало:

```text
Replica_IO_Running: Yes
Replica_SQL_Running: No
```

IO thread продолжил получать данные Source. SQL thread перестал применять изменения к локальным таблицам. После этого на Source была выполнена транзакция:

```sql
INSERT INTO app.customers (name, email)
VALUES ('Async Test', 'async@example.com');
```

На Source запись сразу стала доступна:

```text
ID	= 5
Name	= Async Test
Email	= async@example.com
```

При этом на Replica запись отсутствовала. Это показывает асинхронную модель:

```text
Source COMMIT
     |
     v
Source подтверждает транзакцию клиенту
     |
     v
Replica IO thread получает событие
     |
     v
relay log
     |
     X
Replica SQL thread остановлен
```

Source не ждёт, пока Replica применит транзакцию. После запуска SQL thread:

```sql
START REPLICA SQL_THREAD;
```

запись:


```text
Async Test
async@example.com
```

появилась на Replica. Таким образом, асинхронность репликации была подтверждена экспериментально.

## Финальное состояние

В конце проверки:

```text
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
Seconds_Behind_Source: 0

Last_IO_Error:
Last_SQL_Error:

Retrieved_Gtid_Set:
4dd4a746-c7d6-11f1-a979-00155d6b5f28:13-17

Executed_Gtid_Set:
4dd4a746-c7d6-11f1-a979-00155d6b5f28:1-17

Auto_Position: 1
```

Условно историю GTID можно представить так:

```text
1-12
начальный snapshot

13-14
обычные реплицируемые транзакции

15-16
транзакции исключённых объектов

17
Async Test
```

## Результат

Настроена асинхронная GTID-репликация: `Percona Source -> Percona Replica`. Все требования выплолнены:

Все требования выполнены:

```text
GTID                         ON
SOURCE_AUTO_POSITION         1

Source                       server-id 101
Replica                      server-id 102

initial database             загружена до запуска репликации

read_only                    ON
super_read_only              ON

app.customers                реплицируется
app.orders                   реплицируется

app.audit_log                исключена
replica_excluded.*           исключена

Replica_IO_Running           Yes
Replica_SQL_Running          Yes
Seconds_Behind_Source        0

Last_IO_Error                отсутствует
Last_SQL_Error               отсутствует
```
