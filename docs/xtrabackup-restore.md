# Восстановление отдельной таблицы из XtraBackup

## Задача

Исходный backup был создан командой:

```bash
sudo xtrabackup \
  --user=root \
  --password="password" \
  --backup \
  --stream=xbstream \
  --target-dir=/tmp/backup \
| gzip - \
| openssl aes-256-cbc -salt -pbkdf2 -k "password" \
> backup.xbs.gz.aes
```

Требовалось восстановить только таблицу `world.city` и выполнить запрос:

```sql
SELECT 'city' AS t_name, COUNT(*) AS cnt FROM city
UNION ALL
SELECT 'city (RUS)', COUNT(*) FROM city WHERE countrycode = 'RUS'
UNION ALL
SELECT 'country', COUNT(*) FROM country
UNION ALL
SELECT 'countrylanguage', COUNT(*) FROM countrylanguage;
```

## Исходные данные

Backup: `backup.xbs.gz.aes`. По умолчанию также должен был присутствовать `world.dump.sql`. Однако файл структуры в матриалах отсутствовал. Структура таблиц была восстановлена из SDI, содержащегося непосредственно в InnoDB `.ibd`.

## Структура backup

Файл предсталяет собой несколько последовательно применённых форматов:

```text
backup.xbs.gz.aes
        |
        | AES-256-CBC decrypt
        v
backup.xbs.gz
        |
        | gzip decompress
        v
backup.xbs
        |
        | xbstream extract
        v
physical XtraBackup
```

## Расшифровка

```bash
openssl aes-256-cbc \
  -d \
  -pbkdf2 \
  -pass pass:password \
  -in backup.xbs.gz.aes \
  -out work/backup.xbs.gz
```

Проверка `gzip`:

```bash
gzip -t work/backup.xbs.gz
```

## Распаковка gzip

```bash
gzip -dc work/backup.xbs.gz > work/backup.xbs
```

## Извлечение xbstream

Использовался образ `percona/percona-xtrabackup:8.0`. Версия XtraBackup: `8.0.35036`. Извлечение:

```bash
docker run --rm -i \
  --user 0:0 \
  -v "$PWD/work:/work" \
  --entrypoint xbstream \
  percona/percona-xtrabackup:8.0 \
  -x -C /work/backup-extracted \
  < work/backup.xbs
```

После распаковки присутсвовали:

```text
world/city.ibd
world/country.ibd
world/countrylanguage.ibd
```

## Информация о backup

`xtrabackup_info`:

```text
tool_name = xtrabackup
tool_version = 8.0.35-32
server_version = 8.0.41-32
```

`xtrabackup_checkpoints`:

```text
backup_type = full-backuped
from_lsn = 0
to_lsn = 20485107
last_lsn = 20485107
```

## Perpare и export

Для применения redo и подготовки transportable tablesapce выполнено:

```bash
docker run --rm \
  --user 0:0 \
  --v "$PWD/work:/work" \
  --entrypoint xtrabackup:8.0 \
  --prepare \
  --export \
  --target-dir=/work/backup-extracted
```

После этого:

```text
backup_type = full prepared
```

Для `city` были получены:

```text
world/city.ibd
world/city.cfg
```

`city.ibd` содержит данные таблицы. `city.cfg` содержит метаданные, сформированные XtraBackup специально для transportable tablespace.

## Восстановление структуры без world.dump.sql

Поскольку `world.dump.sql` отсутствовал, структура была извлечена из SDI внутри `.ibd`. Для этого использовалась утилита:

```text
ibd2sdi
```

Пример:

```bash
ibd2sdi city.ibd > city-sdi.json
```

Из SDI была восстановлена структура:

```text
city
country
countrylanguage
```

Для `city` были определены:

```text
ID		INT AUTO_INCREMENT PRIMARY KEY
Name		CHAR(35)
CountryCode	CHAR(3)
District	CHAR(20)
Population	INT
```

Также присутствуют:

```text
INDEX CountryCode
FOREIGN KEY CountryCode -> country.Code
```

Внутренние поля:

```text
DB_TRX_ID
DB_ROLL_PTR
```

не выключаются в `CREATE TABLE`, поскольку создаются и обслуживаются самим InnoDB.

## Совместимая версия сервера

Backup был сделан на `Percona Server 8.0.42-32`. Имеющийся учебный MySQL работал на `MySQL 8.0.15`. Физический tablespace от более новой версии не импортировался в старый MySQL. Для восстановления был запущен отедльный экземпляр:

```text
Percona Server 8.0.41-32
port 3307
```

Percona Server был запущен из Linux Generic binary tarball и использовал отдельный datadir.

## Восстановление tablespace

Сначала была создана пустая таблица `world.city` с идентичной структурой. Проверка:

```sql
SHOW CREATE TABLE world.city;
```

Затем штатный tablespace пустой таблицы был отсоединён:

```sql
SET FOREIGN_KEY_CHECKS=0;

ALTER TABLE world.city
    DISCARD TABLESPACE;
```

После этого в каталог `datadir/world/` были помещены `city.ibd` и `city.cfg` из подготовленного XtraBackup. Затем выполнен импорт:

```sql
SET FOREIGN_KEY_CHECKS=0;

ALTER TABLE world.city
    IMPORT TABLESPACE;
```

Команда завершилась успешно.

## Проверка восстановленных данных

```sql
SELECT COUNT(*)
FROM world.city;
```

Результат:

```text
4800
```

Количество городов России:

```sql
SELECT COUNT(*)
FROM world.city
WHERE CountryCode = 'RUS';
```

Результат:

```text
190
```

## Итоговый запрос задания

```sql
USE world;

SELECT 'city' AS t_name, COUNT(*) AS cnt FROM city
UNION ALL
SELECT 'city (RUS)', COUNT(*) FROM city WHERE countrycode = 'RUS'
UNION ALL
SELECT 'country', COUNT(*) FROM country
UNION ALL
SELECT 'countrylanguage', COUNT(*) FROM countrylanguage;
```

Получено:

```text
+-----------------+------+
| t_name          | cnt  |
+-----------------+------+
| city            | 4080 |
| city (RUS)      |  190 |
| country         |    0 |
| countrylanguage |    0 |
+-----------------+------+
```

Таким образом, из полного физического XtraBackup была восстановлена только таблица `world.city`, а таблицы `country` и `countrylanguage` созданы только структурно и не восстанавливались из физического backup.

## Общая схема восстановления

```text
encrypted backup
       |
       | openssl decrypt
       v
gzip stream
       |
       | gzip decompress
       v
xbstream
       |
       | xbstream extract
       v
physical backup
       |
       | xtrabackup --prepare --export
       v
city.ibd + city.cfg
       |
       | CREATE TABLE
       | DISCARD TABLESPACE
       | copy files
       | IMPORT TABLESPACE
       v
world.city
4080 rows
```

## Вывод

XtraBackup позволяет восстанавливать не только полный экземпляр MySQL, но и отдельные InnDB-таблицы через механизм Transportable Tablespaces. Для восстановления отдельной таблицы необходимы:

1. подготовленный физический backup;
2. `xtrabackup --prepare --export`;
3. `.ibd` и `.cfg` нужной таблицы;
4. идентичная структура таблицы;
5. совместимая версия MySQL/Percona Server;
6. `DISCARD TABLESPACE`;
7. `IMPORT TABLESPACE`.

В данной работе структура была дополнительно восстановлена из SDI, поскольку предусмотренный заданием `world.dump.sql` отсутствовал.
