const shop = db.getSiblingDB("shop");

shop.dropDatabase();

print("Creating shop database...");

// -------------------------
// Customers
// -------------------------

const customerBatchSize = 1000;
const customerCount = 10000;

for (let start = 1; start <= customerCount; start += customerBatchSize) {
    const docs = [];

    for (
        let i = start;
        i < start + customerBatchSize && i <= customerCount;
        i++
    ) {
        docs.push({
            customerId: i,
            name: `Customer ${i}`,
            email: `customer${i}@example.com`,
            city: [
                "Moscow",
                "Saint Petersburg",
                "Kazan",
                "Novosibirsk",
                "Yekaterinburg"
            ][i % 5],
            age: 18 + (i % 53),
            active: i % 10 !== 0,
            createdAt: new Date(
                Date.now() - (i % 730) * 24 * 60 * 60 * 1000
            )
        });
    }

    shop.customers.insertMany(docs);
}

print(`Customers inserted: ${shop.customers.countDocuments()}`);

// -------------------------
// Orders
// -------------------------

const orderBatchSize = 1000;
const orderCount = 100000;

const statuses = [
    "NEW",
    "PAID",
    "SHIPPED",
    "DELIVERED",
    "CANCELLED"
];

for (let start = 1; start <= orderCount; start += orderBatchSize) {
    const docs = [];

    for (
        let i = start;
        i < start + orderBatchSize && i <= orderCount;
        i++
    ) {
        const customerId = (i % customerCount) + 1;

        docs.push({
            orderId: i,
            customerId: customerId,
            status: statuses[i % statuses.length],
            amount: Number((10 + ((i * 13.37) % 4990)).toFixed(2)),
            itemsCount: 1 + (i % 10),
            createdAt: new Date(
                Date.now() - (i % 365) * 24 * 60 * 60 * 1000
            ),
            paymentMethod: [
                "card",
                "cash",
                "sbp"
            ][i % 3]
        });
    }

    shop.orders.insertMany(docs);
}

print(`Orders inserted: ${shop.orders.countDocuments()}`);

print("");
print("Collections:");
printjson(shop.getCollectionNames());

print("");
print("Customers count:");
print(shop.customers.countDocuments());

print("");
print("Orders count:");
print(shop.orders.countDocuments());
