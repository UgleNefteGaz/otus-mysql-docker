const shop = db.getSiblingDB("shop");

print("Creating indexes...");

printjson(
    shop.customers.createIndex(
        { customerId: 1 },
        { name: "idx_customers_customerId" }
    )
);

printjson(
    shop.orders.createIndex(
        { customerId: 1 },
        { name: "idx_orders_customerId" }
    )
);

printjson(
    shop.orders.createIndex(
        { status: 1, amount: 1 },
        { name: "idx_orders_status_amount" }
    )
);

print("");
print("Customers indexes:");
printjson(shop.customers.getIndexes());

print("");
print("Orders indexes:");
printjson(shop.orders.getIndexes());
