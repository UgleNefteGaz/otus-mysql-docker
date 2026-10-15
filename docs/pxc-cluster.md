# Percona XtraDB Cluster: кластер из трёх нод и проверка отказоустойчивости

## Цель работы

Развернуть Percona XtraDB Cluster из трёх узлов и проверить:

- состояние кластера на каждой ноде;
- синхронную репликацию данных между нодами;
- работу кластера при отказе одной ноды;
- восстановление отключённой ноды;
- поведение кластера при потере большинства нод;
- восстановление кворума после аварии.

В работе использовался Percona XtraDB Cluster:

```text
Percona XtraDB Cluster 8.0.41-32.1
WSREP 26.1.4.3
```

Лаборатория разворачивалась локально в WSL. Все три ноды являются отдельными процессами `mysqld`, но физическеи находятся на одном хосте. В production-среде ноды должны размещаться на независимых серверах или виртуальных машинах.

---

## 1. Архитектура кластера

Для трёх нод были назначены отдкльные порты MySQL, Galera. IST и SST.

| Нода | MySQL | SST | Galera | IST | server-id |
|---|---|---|---|---|---|
| node1 | 4000 | 4020 | 4030 | 4040 | 201 |
| node2 | 5000 | 5020 | 5030 | 5040 | 202 |
| node3 | 6000 | 6020 | 6030 | 6040 | 203 |

Схема:

```text
                    PXC cluster
                   cluster size = 3

          +-------------+-------------+
          |             |             |
        node1         node2         node3
       MySQL 4000    MySQL 5000    MySQL 6000
       Galera 4030   Galera 5030   Galera 6030
       IST 4040      IST 5040      IST 6040
       SST 4020      SST 5020      SST 6020
```

PXC работает в multi-primary режиме. После формирования кластера все три ноды равноправны и могут принимать SQL-запросы.

---

## 2. Установка Percona XtraDB Cluster

Использован binary tarball:

```text
Percona-XtraDB-Cluster_8.0.41-32.1_Linux.x86_64.glibc2.35.tar.gz
```

После распаковки версия сервера была проверена командой:

```bash
"$PXC_BASE/bin/mysqld" --version
```

Результат:

```text
Ver 8.0.41-32.1 for Linux on x86_64
Percona XtraDB Cluster binary (GPL) 8.0.41
WSREP version 26.1.4.3
```

Также была проверена библиотека Galera:

```bash
ls -lh "$PXC_VASE/lib/libgalera_smm.so"
```

И зависимости:

```bash
ldd "$PXC_BASE/bin/mysqld" | grep 'not found' || echo "mysqld dependencies OK"

ldd "$PXC_BASE/lib/libgalera_smm.so" \
    | grep 'not found' \
    || echo "Galera dependencies OK"
```

Результат:

```text
mysqld dependencies OK
Galera dependencies OK
```

Для SST установлен `socat`. PXC-дистрибутив также содержит встроенный Percona XtraBackup:

```text
bin/pxc_extra/pxb-8.0/bin/xtrabackup
bin/pxc_extra/pxb-8.0/bin/xbstream
```

---

## 3. Основные параметры PXC

На всех нодах использовались:

```ini
binlog_format=ROW

default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2

wsrep_on=ON

wsrep_cluster_name=pxc-lab

wsrep_sst_method=xtrabackup-v2

pxc_strict_mode=ENFORCING

wsrep_applier_threads=8
```

Для локальной лаборатории шифрование межузлового трафика было отключено:

```ini
pxc-encrypt-cluster-traffic=OFF
```

MySQL X Plugin также отключён, так как все три процесса работают на одом сервере и иначе использовали бы один порт `33060`:

```ini
mysqlx=0
```

---

## 4. Конфигурация node1

Основные параметры:

```ini
server-id=201

port=4000

wsrep_cluster_name=pxc-lab

wsrep_cluster_address=gcomm://127.0.0.1:5030,127.0.0.1:6030

wsrep_node_name=node1
wsrep_node_address=127.0.0.1:4030

wsrep_provider_options="gmcast.listen_addr=tcp://127.0.0.1:4030;ist.recv_addr=127.0.0.1:4040"

wsrep_sst_receive_address=127.0.0.1:4020
```

---

## 5. Конфигурация node2

```ini
server-id=202

port=5000

wsrep_cluster_name=pxc-lab

wsrep_cluster_address=gcomm://127.0.0.1:4030,127.0.0.1:6030

wsrep_node_name=node2
wsrep_node_address=127.0.0.1:5030

wsrep_provider_options="gmcast.listen_addr=tcp://127.0.0.1:5030;ist.recv_addr=127.0.0.1:5040"

wsrep_sst_receive_address=127.0.0.1:5020
```

---

## 6. Конфигурация node3

```ini
server-id=203

port=6000

wsrep_cluster_name=pxc-lab

wsrep_cluster_address=gcomm://127.0.0.1:4030,127.0.0.1:5030

wsrep_node_name=node3
wsrep_node_address=127.0.0.1:6030

wsrep_provider_options="gmcast.listen_addr=tcp://127.0.0.1:6030;ist.recv_addr=127.0.0.1:6040"

wsrep_sst_receive_address=127.0.0.1:6020
```

---

## 7. Инициализация нод

Для каждой ноды был создан отдельный `datadir`. Инициализация выполнялась с отключённым WSREP:

```bash
for n in 1 2 3; do
    "$PXC_BASE/bin/mysqld" \
        --defaults-file="$LAB/conf/node${n}.cnf" \
        --initialize-insecure \
        --wsrep_on=OFF \
        --user=root
done
```

После инициализации были созданы три независимых MySQL datadir.

---

## 8. Bootstrap первой ноды

Первый узел нового кластера был запущен с параметром:

```bash
"$PXC_BASE/bin/mysqld" \
  --defaults-file="$LAB/conf/node1.cnf" \
  --wsrep-new-cluster \
  --daemonize
```

`--wsrep-new-cluster` используется только при создании нового Primary Component. После запуска состояние `node1`:

```text
wsrep_cluster_size          1
wsrep_cluster_status        Primary
wsrep_connected             ON
wsrep_local_state_comment   Synced
wsrep_ready                 ON
```

---

## 9. Подключение node2 и node3

Остальные ноды запускались без `wsrep-new-cluster`.

Node2:

```bash
"$PXC_BASE/bin/mysqld" \
  --defaults-file="$LAB/conf/node2.cnf" \
  --daemonize
```

Node3:

```bash
"$PXC_BASE/bin/mysqld" \
  --defaults-file="$LAB/conf/node3.cnf" \
  --daemonize
```

После подключения всех нод статус был проверен на каждом узле:

```sql
SHOW STATUS WHERE Variable_name IN (
    'wsrep_cluster_size',
    'wsrep_cluster_status',
    'wsrep_connected',
    'wsrep_local_state_comment',
    'wsrep_ready'
);
```

На всех трёх нодах был получен одинаковый результат:

```text
wsrep_cluster_size          3
wsrep_cluster_status        Primary
wsrep_connected             ON
wsrep_local_state_comment   Synced
wsrep_ready                 ON
```

Таким образом, кластер состоял из трёх синхронизированных узлов.

---

## 10. Загрузка тестовых данных

На `node1` была создана база:

```sql
CREATE DATABASE pxc_demo;
```

В ней были созданы таблицы:

```text
customers
orders
```

Структура талицы `customers`:

```sql
CREATE TABLE customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL
) ENGINE=InnoDB;
```

Структура таблицы `orders`:

```sql
CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(id)
) ENGINE=InnoDB;
```

Для получения предсказуемых значений внешнего ключа ID клиентов были заданы явно:

```sql
INSERT INTO customers(id,name,email) VALUES
(1,'Alice','alice@example.com'),
(2,'Bob','bob@example.com'),
(3,'Carol','carol@example.com'),
(4,'Dave','dave@example.com'),
(5,'Eve','eve@example.com');
```

Причина явного указания ID заключается в том, что PXC использует `wsrep_auto_increment_control` и автоматически управляет параметрами `AUTO_INCREMENT`, чтобы уменьшить вероятность конфликтов при записи одновременно на разные ноды. В таблицу `orders` были добавлены 6 строк.

---

## 11. Проверка данных на всех нодах

На каждой ноде были выполнены:

```sql
USE pxc_demo;

SHOW TABLES;

SELECT COUNT(*) AS customers_count
FROM customers;

SELECT COUNT(*) AS orders_count
FROM orders;
```

На всех трёх узлах результат был одинаковым:

```text
Tables_in_pxc_demo
------------------
customers
orders

customers_count
---------------
5

orders_count
------------
6
```

Содержимое `customers`:

```text
+----+-------+
| id | name  |
+----+-------+
|  1 | Alice |
|  2 | Bob   |
|  3 | Carol |
|  4 | Dave  |
|  5 | Eve   |
+----+-------+
```

Таким образом, данные, записанные через одну ноду, присутствовали на всех трёх узлах.

---

# Проверка отказоустойчивости

## 12. Отказ одной ноды

Для имитации отказа была остаровлена `node3`. После этого на `node1` и `node2`:

```text
wsrep_cluster_size          2
wsrep_cluster_status        Primary
wsrep_connected             ON
wsrep_local_state_comment   Synced
wsrep_ready                 ON
```

Кластер сохранил Primary Component, так как две из трёх нод продолжали работать.

---

## 13. Запись после отказа node3

Во время отсутствия `node3` через `node1` была выполнена запись:

```sql
INSERT INTO pxc_demo.customers(id,name,email)
VALUES (100,'Failover Test','failover@example.com');
```

На `node1`:

```text
+-----+---------------+----------------------+
| id  | name          | email                |
+-----+---------------+----------------------+
| 100 | Failover Test | failover@example.com |
+-----+---------------+----------------------+
```

После этого запись была прочитана через `node2`:

```sql
SET SESSION wsrep_sync_wait=1;

SELECT id,name,email
FROM pxc_demo.customers
WHERE id=100;
```

Результат:

```text
+-----+---------------+----------------------+
| id  | name          | email                |
+-----+---------------+----------------------+
| 100 | Failover Test | failover@example.com |
+-----+---------------+----------------------+
```

Количество клиентов:

```text
customers_count = 6
```

Таким образом, отказ одной из трёх нод не остановил работу кластера.

---

## 14. Возврат node3

`node3` была запущена обычным способом:

```bash
"$PXC_BASE/bin/mysqld" \
  --defaults-file="$LAB/conf/node3.cnf" \
  --daemonize
```

После подключения:

```text
wsrep_cluster_size          3
wsrep_cluster_status        Primary
wsrep_connected             ON
wsrep_local_state_comment   Synced
wsrep_ready                 ON
```

Строка, созданная во время отсутствия `node3`, появилась на ней:

```text
+-----+---------------+----------------------+
| id  | name          | email                |
+-----+---------------+----------------------+
| 100 | Failover Test | failover@example.com |
+-----+---------------+----------------------+
```

---

## 15. Восстановление node3 через IST

При первом коротком отключении `node3` восстановилась через IST. В логе присутствовали сообщения:

```text
Prepared IST receiver for 14-16
xtrabackup_ist received from donor: Running IST
Receiving IST: 3 writesets, seqnos 14-16
Receiving IST... 100.0%
IST received
```

Донором автоматически была выбрана `node2`. "IST" означает "Incremental State Transfer". В этом случае нода получает только недостающие writeset'ы, а не полную копию базы.

---

# Потеря кворума

## 16. Аварийное отключение двух нод

Для проверки поведения PXC при потере большинства `node2` и `node3` были аварийно остановлены через `SIGKILL`:

```bash
kill -9 \
  "$(cat "$LAB/node2/run/mysql.pid")" \
  "$(cat "$LAB/node3/run/mysql.pid")"
```

После этого в кластере осталаь только `node1`. Её состояние:

```text
wsrep_cluster_size          1
wsrep_cluster_status        non-Primary
wsrep_connected             ON
wsrep_local_state_comment   Initialized
wsrep_ready                 OFF
```

Оставшаяся нода потеряла кворум.

---
## 17. Проверка SQL без кворума

Был выполнен запрос:

```sql
SELECT COUNT(*)
FROM pxc_demo.customers;
```

Получена ошибка:

```text
ERROR 1047 (08S01):
WSREP has not yet prepared node for application use
```

Аналогично бал заблокирован и `INSERT`:

```sql
INSERT INTO pxc_demo.customers(id,name,email)
VALUES (101,'No Quorum','noquorum@example.com');
```

Результат:

```text
ERROR 1047 (08S01):
WSREP has not yet prepared node for application use
```

Таким образом, при потере большинства нод PXC блокирует application-запросы. Это предотвращает split-brain и появление нескольких независимых версий данных.

---

## 18. Кворум

При одинаковом весе нод Primary Component должен содержать больше половины голосов. Для трёх нод:

```text
3/3 -> Primary
2/3 -> Primary
1/3 -> non-Primary
```

Для семи нод:

```text
7/7 -> Primary
6/7 -> Primary
5/7 -> Primary
4/7 -> Primary
3/7 -> non-Primary
2/7 -> non-Primary
1/7 -> non-Primary
```

Формула минимального большинства:

```text
floor(N / 2) + 1
```

Например:

```text
3 ноды -> минимум 2
5 нод  -> минимум 3
7 нод  -> минимум 4
9 нод  -> минимум 5
```

---

# Восстановление после потери кворума

## 19. Запуск второй ноды

После аварии была запущена `node2`:

```bash
"$PXC_BASE/bin/mysqld" \
  --defaults-file="$LAB/conf/node2.cnf" \
  --daemonize
```

`node1` и `node2` смогли увидеть друг друга на уровне Galera, и:

```text
wsrep_cluster_size = 2
```

Однако компонент продолжал оставаться:

```text
wsrep_cluster_status = non-Primary
wsrep_ready = OFF
```

То есть простого запуска второй ноды после уже произошедшей потери кворума оказалось недостаточно.

---
## 20. Восстановление Primary Component

Так как было точно известно, что:

```text
node1 - жива
node2 - запущена нами
node3 - остановлена нами
другого Primary Component не существует
```

на `node1` был выполнен:

```sql
SET GLOBAL wsrep_provider_options='pc.bootstrap=YES';
```

Перед восстановлением:

```text
wsrep_last_commited = 16
```

После обновления Galera view обе ноды перешли в состояние:

```text
wsrep_cluster_size          2
wsrep_cluster_status        Primary
wsrep_connected             ON
wsrep_local_state_comment   Synced
wsrep_ready                 ON
wsrep_last_committed        17
```

Таким образом, Primary Component был успешно восстановлен. Важно:

```text
pc.bootstrap=YES
```

можно использовать только тогда, когда достоверно известно, что другого Primary Component не существует. В противном случае возможно создание split-brain.

---

## 21. Проверка SQL после восстановления кворума

Через `node2` была выполнена запись:

```sql
INSERT INTO pxc_demo.customers(id,name,email)
VALUES (102,'Quorum Restored','quorum@example.com');
```

Результат:

```text
+-----+-----------------+--------------------+
| id  | name            | email              |
+-----+-----------------+--------------------+
| 102 | Quorum Restored | quorum@example.com |
+-----+-----------------+--------------------+
```

Через `node1` эта же строка была успешно прочитана:

```text
+-----+-----------------+--------------------+
| id  | name            | email              |
+-----+-----------------+--------------------+
| 102 | Quorum Restored | quorum@example.com |
+-----+-----------------+--------------------+
```

Количество записей:

```text
customers_count = 7
```

Таким образом, после восстановления Primary Component кластер снова начал выполнять запросы.

---

## 22. Возврат node3 после восстановления кворума

После этого была запущена `node3`. Итоговый статус всех трёх узлов:

```text
NODE1
wsrep_cluster_size          3
wsrep_cluster_status        Primary
wsrep_connected             ON
wsrep_last_committed        19
wsrep_local_state_comment   Synced
wsrep_ready                 ON

NODE2
wsrep_cluster_size          3
wsrep_cluster_status        Primary
wsrep_connected             ON
wsrep_last_committed        19
wsrep_local_state_comment   Synced
wsrep_ready                 ON

NODE3
wsrep_cluster_size          3
wsrep_cluster_status        Primary
wsrep_connected             ON
wsrep_last_committed        19
wsrep_local_state_comment   Synced
wsrep_ready                 ON
```

На всех трёх `customers_count = 7` и присутствует строка `102  Quorum Restored  quorum@example.com`.

---

## 23. Восстановление node3 через SST

После аварийного сценария `node3` уже не смогла восстановиться только через IST. Galera сначала проверила возможность IST:

```text
Check if state gap can be serviced using IST
Prepared IST receiver
```

После проверки истории было зафиксировано:

```text
Resetting GCache seqno map due to different histories
```

После чего был выполнен полный SST:

```text
Proceeding with SST
Waiting for SST streaming to complete
Decompressing the backup
Preparing the backup
Moving the backup
SST completed
```

Донором была автоматически выбрана `node1`. После SST:

```text
SST received: ...:19
Installed new state from SST: ...:19
```

`node3` снова перешла в состояние:

```text
Primary
Synced
wsrep_ready = ON
```

---

# IST и SST

В ходе работы были практически продемонстрированы оба механизма синхронизации PXC.

## IST

Incremental State Transfer используется, если донор имеет необходимые writeset'ы в GCache. Преимущество в том, что передаются только пропущенные изменения. В первом эксперименте `node3` получила несколько недостающих writeset'ов через IST.

## SST

State Snapshot Transfer используется, если IST невозможно выполнить или история узла требует полной синхронизации. В нашем втором эксперименте `node3` получила полный snapshot через `xtrabackup-v2`, после чего автоматически вернулась в кластер.

---

# Итоговая схема эксперимента

```text
Исходное состояние

node1 + node2 + node3
       3/3 Primary
            |
            |
        node3 DOWN
            |
            v
node1 + node2
       2/3 Primary
       SQL работает
            |
            |
        node3 START
            |
            v
         IST
            |
            v
       3/3 Primary


Дополнительный аварийный тест

node1 + node2 + node3
       3/3 Primary
            |
            |
      kill -9 node2
      kill -9 node3
            |
            v
         node1
       1/3 non-Primary
       wsrep_ready=OFF
       SQL заблокирован
            |
            |
        START node2
            |
            v
node1 + node2
       non-Primary
            |
            |
 pc.bootstrap=YES на node1
            |
            v
node1 + node2
       2/3 Primary
       SQL работает
            |
            |
        START node3
            |
            v
          SST
            |
            v
node1 + node2 + node3
       3/3 Primary
       все Synced
```

---

# Вывод

В ходе работы был развёрнут Percona XtraDB Cluster из трёх нод. Было подтверждено:

1. Все три узла входят в один Primary Component:
```text
wsrep_cluster_size = 3
wsrep_cluster_status = Primary
```
2. Данные автоматически синхронизируются между всеми нодами.
3. При отказе одной ноды оставшиеся две сохраняют кворум и продолжают выполнять чтение и запись.
4. После возврата отключённой ноды она автоматически синхронизируется с кластером.
5. При коротком отставании может использоваться механизм IST.
6. При невозможности IST выполняется полный SST через XtraBackup.
7. При аварийном отказе двух нод из трёх оставшаяся нода теряет кворум:
```text
wsrep_cluster_status = non-Primary
wsrep_ready = OFF
```
8. Без кворума PXC блокирует обычные application-запросы:
```text
ERROR 1047:
WSREP has not yet prepared node for application use
```
9. После подтверждения отсутствия другого Primary Component кластер может быть восстановлен:
```sql
SET GLOBAL wsrep_provider_options='pc.bootstrap=YES';
```
10. После восстановления Primary Component остальные ноды могут снова присоединиться и синхронизироваться.

Таким образом, Percona XtraDB Cluster обеспечивает multi-primary репликацию, контроль кворума и защиту от split-brain, а также позволяет автоматически восстанавливать отставшие узлы через мехнизмы IST и SST.
