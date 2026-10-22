# MongoDB: установка, работа с данными и сравнение индексов

## Цель работы

Необходимо:

- установить MongoDB;
- заполнить MongoDB тестовыми данными;
- выполнить несколько запросов на выборку;
- выполнить обновление данных;
- создать индексы;
- сравнить производительность запросов до и после создания индексов.

MongoDB была развёрнута в Docker.

---

## 1. Окружение

Использовались:

```text
Docker 29.8.1
Docker Compose 5.5.1
MongoDB Community Server 8.0.34
```

Контейнер: `mongodb-lab`. MongoDB доступна локально: `127.0.0.1:27017`.

---

## 2. Docker Compose

Для запуска MongoDB использован файл `mongodb/compose.yaml`. Конфигурация следующая:

```yaml
services:
  mongodb:
    image: mongodb/mongodb-community-server:8.0-ubi8
    container_name: mongodb-lab

    ports:
      - "127.0.0.1:27017:27017"

    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: mongo_123

    volumes:
      - mongodb_data:/fata/db

    restart: unless-stopped

volumes:
  mongodb_data:
```

Контейнер запускается командой `docker compose up -d`.

Проверка состояние контейнера: `docker compose ps`. Результат:

```text
NAME          IMAGE                                       STATUS
mongodb-lab   mongodb/mongodb-community-server:8.0-ubi8   Up
```

Проверка подключения:

```bash
docker exec mongodb-lab mongosh \
  --username root \
  --password mongo_123 \
  --authenticationDatabase admin \
  --eval 'db.runCommand({ ping: 1 })'
```

Результат:

```text
{ ok: 1 }
```

Проверка версии:

```bash
docker exec mongodb-lab mongosh \
  --username root \
  --password mongo_123 \
  --authenticationDatabase admin \
  --quiet \
  --eval 'db.version()'
```

Результат:

```text
8.0.34
```

---

# Работа с данными

## 3. Тестовая база

Создана база данных `shop`. В ней используются две коллекции: `customers` и `orders`. Для загрузки данных используется `mongodb/init/01-init-data.js`

---

## 4. Коллекция customers

Создано `10000 документов`. Пример документа:

```javascript
{
    customerId: 5000,
    name: "Customer 5000",
    email: "customer5000@example.com",
    city: "Moscow",
    age: 48,
    active: true,
    createdAt: ISODate(...)
}
```

Поля:

```text
customerId
name
email
city
age
active
createdAt
```

---

## 5. Коллекция orders

Создано `100000 документов`. Пример документа:

```javascript
{
    orderId: 5000,
    customerId: 5001,
    status: "NEW",
    amount: 1860.00,
    itemsCount: 1,
    createdAt: ISODate(...),
    paymentMethod: "card"
}
```

Используемые статусы:

```text
NEW
PAID
SHIPPED
DELIVERES
CANCELLED
```

Способы оплаты:

```text
card
cash
sbp
```

---

## 6. Проверка количества данных

Проверка:

```javascript
const db = db.getSiblingDB("shop");

print("customers =", db.customers.countDocuments());
print("orders =", db.orders.countDocuments());
```

Результат:

```text
customers = 10000
orders = 100000
```

---

# Запросы на выборку

## 7. Поиск клиента

Поиск клиента по `customerId`:

```javascript
shop.customers.findOne(
    { customerId: 5000 },
    {
        _id: 0,
        customerId: 1,
        name: 1,
        email: 1,
        city: 1,
        age: 1,
        active: 1
    }
);
```

---

## 8. Выборка клиентов по нескольким условиям

Пример:

```javascript
shop.customers.find(
    {
        city: "Moscow",
        age: { $gte: 40 }
    },
    {
        _id: 0,
        customerId: 1,
        name: 1,
        city: 1,
        age: 1
    }
).limit(10);
```

Здесь используются:

```text
равенство по city
$gte по age
проекция полей
limit()
```

---

## 9. Заказы конкретного клиента

```javascript
shop.orders.find(
    {
        customerId: 5000
    },
    {
        _id: 0,
        orderId: 1,
        customerId: 1,
        status: 1,
        amount: 1,
        createdAt: 1
    }
)
.sort({ createdAt: -1 })
.limit(10);
```

---

## 10. Поиск дорогих оплаченных заказов

```javascript
shop.orders.find(
    {
        status: "PAID",
        amount: { $gte: 4000 }
    },
    {
        _id: 0,
        orderId: 1,
        customerId: 1,
        status: 1,
        amount: 1
    }
)
.sort({ amount: -1 })
.limit(10);
```

---

# Обновление данных

## 11. updateOne

Для одного клиента было добавлено поле:

```text
vip = true
```

Запрос:

Запрос:

```javascript
shop.customers.updateOne(
    {
        customerId: 5000
    },
    {
        $set: {
            vip: true,
            updatedAt: new Date()
        }
    }
);
```

Результат:

```text
matchedCount: 1
modifiedCount: 1
```

Проверка:

```javascript
shop.customers.findOne(
    { customerId: 5000 },
    {
        _id: 0,
        customerId: 1,
        name: 1,
        vip: 1
    }
);
```

Результат:

```text
{
  customerId: 5000,
  name: 'Customer 5000',
  vip: true
}
```

---

## 12. updateMany

Для дорогих отменённых заказов установлено:

```text
reviewRequired = true
```

Запрос:

```javascript
shop.orders.updateMany(
    {
        status: "CANCELLED",
        amount: { $gte: 4000 }
    },
    {
        $set: {
            reviewRequired: true,
            updatedAt: new Date()
        }
    }
);
```

Результат:

```text
matchedCount: 4005
modifiedCount: 4005
```

Проверка количества:

```javascript
shop.orders.countDocuments({
    reviewRequired: true
});
```

Результат:

```text
4005
```

Пример изменённого документа:

```text
{
  orderId: 299,
  status: 'CANCELLED',
  amount: 4007.63,
  reviewRequired: true
}
```

---

# Проверка производительности без индексов

## 13. Методика

Для анализа использован:

```javascript
.explain("executionstats")
```

Сравнивались:

```text
winningPlan
executionTimeMillis
totalDocsExamined
totalKeysExamined
nReturned
```

До создания дополнительных индексов в коллекциях существовал только стандартный индекс `_id_`.

---

## 14. Поиск customers по customerId без индекса

Запрос:

```javascript
shop.customers
    .find({ customerId: 5000 })
    .explain("executionStats");
```

Результат:

```text
nReturned: 1
executionTimeMillis: 3
totalDocsExamined: 10000
totalKeysExamined: 0
```

План:

```text
COLLSCAN
```

MongoDB просмотрела все 10000 документов, чтобы найти один документ.

---

## 15. Поиск orders по customerId без индекса

Запрос:

```javascript
shop.orders
    .find({ customerId: 5000 })
    .explain("executionStats");
```

Результат:

```text
nReturned: 10
executionTimeMillis: 25
totalDocsExamined: 100000
totalKeysExamined: 0
```

Пдан:

```text
COLLSCAN
```

Для возврата 10 документов MongoDB просмотрела 100000 документов.

---

## 16. Поиск по status и amount без индекса

Запрос:

```javascript
shop.orders
    .find({
        status: "PAID",
        amount: { $gte: 4000 }
    })
    .explain("executionStats");
```

Результат:

```text
nReturned: 4005
executionTimeMillis: 27
totalDocsExamined: 100000
totalKeysExamined: 0
```

План:

```text
COLLSCAN
```

MongoDB снова прочитала всю коллекцию.

---

# Создание индексов

## 17. Индекс customers.customerId

Создан индекс:

```javascript
shop.customers.createIndex(
    { customerId: 1 },
    { name: "idx_customers_customerId" }
);
```

---

## 18. Индекс orders.customerId

```javascript
shop.orders.createIndex(
    { customerId: 1 },
    { name: "idx_orders_customerId" }
);
```

---

## 19. Составной индекс status + amount

```javascript
shop.orders.createIndex(
    {
        status: 1,
        amount: 1
    },
    {
        name: "idx_orders_status_amount"
    }
);
```

Индекс соответствует запросу:

```javascript
{
    status: "PAID",
    amount: { $gte: 4000 }
}
```

Первое поле используется для точного сравнения, второе для диапазона.

---

## 20. Список индексов

В `customers`:

```text
_id_
idx_customers_customerId
```

В `orders`:

```text
_id_
idx_orders_customerId
idx_orders_status_amount
```

---

# Производительность после создания индексов

## 21. customers.customerId

После создания: `idx_customers_customerId` результат следующий:

```text
nReturned: 1
executionTimeMillis: 1
totalDocsExamined: 1
totalKeysExamined: 1
```

План:

```text
FETCH
  IXSCAN
```

Использованный индекс: `idx_customers_customerId`. Границы индекса: `[5000, 5000]`.

---

## 22. orders_customerId

Результат:

```text
nReturned: 10
executionTimeMillis: 0
totalDocsExamined: 10
totalKeysExamined: 10
```

План:

```text
FETCH
  IXSCAN
```

Индекс: `idx_orders_customerId`. До индекса MongoDB просматривала 100000 документов, а после - уже 10 документов.

---

## 23. status + amount

После создания `idx_orders_status_amount` результат следующий:

```text
nReturned: 4005
executionTimeMillis: 5
totalDocsExamined: 4005
totalKeysExamined: 4005
```

План:

```text
FETCH
  IXSCAN
```

MongoDB использовала:

```text
status = "PAID"
amount >= 4000
```

Границы индекса:

```text
status:
["PAID", "PAID"]

amount:
[4000, +infinity]
```

---

# Сравнение производительности

## 24. Итоговая таблица

| Запрос | План до | План после | Docs до | Docs после | Keys после | Время до | Время после |
|---|---|---|---|---|---|---|---|
| `customers.customerId = 5000` | COLLSCAN | FETCH + IXSCAN | 10000 | 1 | 1 | 3 ms | 1 ms |
| `orders.customerId = 5000` | COLLSACN | FETCH + IXSCAN | 100000 | 10 | 10 | 25 ms | 0 ms |
| `status = PAID AND amount >= 4000` | COLLSAN | FETCH + IXSCAN | 100000 | 4005 | 4005 | 27 ms | 5 ms |

---

## 25. Эффект индекса customers.customerId

Количество просмотренных документов уменьшилось:

```text
10000 -> 1
```

---

## 26. Эффект индекса orders.customerId

Количество просмотренных документов:

```text
100000 -> 1
```

---

## 27. Эффект составного индекса status + amount

Количество просмотренных документов:

```text
100000 -> 4005
```

При этом MongoDB просмотрела практически только те документы, которые соответствуют запросу:

```text
nReturned = 4005
totalDocsExamined = 4005
```

---

## 28. COLLSCAN и IXSCAN

До индексов использовался `COLLSCAN`. Это означает полный просмотр документов коллекции. После создания индексов использовалась схема `FETCH/IXSCAN`, в которой `IXSCAN` выполняет поиск по индексу, а `FETCH` получает найденные документы из коллекции. Таким образом, MongoDB больше не выполняет полный просмотр коллекции.

---

## 29. executionTimeMillis

Время выполнения также уменьшилось:

```text
customers:
3 ms -> 1 ms

orders by customerId:
25 ms -> 0 ms

status + amount:
27 ms -> 5 ms
```

Значение `0 ms` не означает абсолютное нулевое время выполнения. Операция выполнилась быстрее точности, с которой значение отображается в миллисекундах. Поэтому главным показателем эффективности индексса в этой работе являются:

```text
totalDocsExamined
totalKeysExamined
nReturned
winningPlan
```

---

# Структура файлов

```text
mongodb/
├── compose.yaml
├── init/
│   └── 01-load-data.js
├── queries/
│   └── 01-queries.js
└── benchmark/
    ├── 01-before-indexes.js
    ├── 02-create-indexes.js
    └── 03-after-indexes.js
```

---

# Вывод

В ходе работы была развёрнута MongoDB Community Server 8.0.34 в Docker. Создана база данных `shop` и две коллекции: `customers` на 10000 документов и `orders` на 100000 документов. Были выполнены:

```text
findOne()
find()
sort()
limit()
countDocuments()
updateOne()
updateMany()
```

Для анализа производительности использован: `explain("executionStats")`. До создания индексов запросы выполняли `COLLSCAN` и просматривали целиком коллекции размером 10000 или 100000 документов. После создания индексов использовался `IXSCAN`. Для поиска одного клиента количество просмотренных документов уменьшилось с 10000 до 1, для поиска заказов одного клиента - с 100000 до 10, а для запроса по `status` и `amount` - с 100000 до 4005. Таким образом, индексы значительно уменьшили объём данных, который MongoDB необходимо просматривать для выполнения запросов, и сократили время их выполнения.
