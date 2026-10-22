const shop = db.getSiblingDB("shop");

print("========================================");
print("1. FIND CUSTOMER BY customerId");
print("========================================");

printjson(
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
    )
);


print("");
print("========================================");
print("2. CUSTOMERS FROM MOSCOW, AGE >= 40");
print("========================================");

shop.customers
    .find(
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
    )
    .limit(10)
    .forEach(printjson);


print("");
print("========================================");
print("3. ORDERS FOR CUSTOMER 5000");
print("========================================");

shop.orders
    .find(
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
    .limit(10)
    .forEach(printjson);


print("");
print("========================================");
print("4. EXPENSIVE PAID ORDERS");
print("========================================");

shop.orders
    .find(
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
    .limit(10)
    .forEach(printjson);


print("");
print("========================================");
print("5. UPDATE ONE CUSTOMER");
print("========================================");

const updateOneResult = shop.customers.updateOne(
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

printjson(updateOneResult);

print("Customer after update:");

printjson(
    shop.customers.findOne(
        { customerId: 5000 },
        {
            _id: 0,
            customerId: 1,
            name: 1,
            vip: 1,
            updatedAt: 1
        }
    )
);


print("");
print("========================================");
print("6. UPDATE MANY ORDERS");
print("========================================");

const updateManyResult = shop.orders.updateMany(
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

printjson(updateManyResult);


print("");
print("========================================");
print("7. CHECK UPDATED ORDERS");
print("========================================");

print(
    "Orders with reviewRequired=true:",
    shop.orders.countDocuments({
        reviewRequired: true
    })
);

shop.orders
    .find(
        {
            reviewRequired: true
        },
        {
            _id: 0,
            orderId: 1,
            status: 1,
            amount: 1,
            reviewRequired: 1
        }
    )
    .limit(10)
    .forEach(printjson);
