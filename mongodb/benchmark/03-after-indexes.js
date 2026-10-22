const shop = db.getSiblingDB("shop");

function printStats(title, explain) {
    print("");
    print("========================================");
    print(title);
    print("========================================");

    print("nReturned:", explain.executionStats.nReturned);
    print("executionTimeMillis:", explain.executionStats.executionTimeMillis);
    print("totalDocsExamined:", explain.executionStats.totalDocsExamined);
    print("totalKeysExamined:", explain.executionStats.totalKeysExamined);

    print("winningPlan:");
    printjson(explain.queryPlanner.winningPlan);
}

// 1. Поиск клиента по customerId
const customerExplain = shop.customers
    .find({ customerId: 5000 })
    .explain("executionStats");

printStats(
    "1. customers: customerId = 5000",
    customerExplain
);

// 2. Поиск заказов клиента
const ordersByCustomerExplain = shop.orders
    .find({ customerId: 5000 })
    .explain("executionStats");

printStats(
    "2. orders: customerId = 5000",
    ordersByCustomerExplain
);

// 3. Выборка по status + amount
const paidExpensiveExplain = shop.orders
    .find({
        status: "PAID",
        amount: { $gte: 4000 }
    })
    .explain("executionStats");

printStats(
    "3. orders: status = PAID and amount >= 4000",
    paidExpensiveExplain
);
