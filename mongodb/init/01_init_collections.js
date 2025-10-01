// Инициализация коллекций MongoDB для интернет-магазина

// Создание коллекции categories
db.createCollection("categories");

// Создание коллекции products
db.createCollection("products");

// Создание коллекции customers
db.createCollection("customers");

// Создание коллекции orders
db.createCollection("orders");

// Создание коллекции order_items
db.createCollection("order_items");

// Создание коллекции suppliers
db.createCollection("suppliers");

// Создание коллекции shipments
db.createCollection("shipments");

print("Коллекции MongoDB созданы успешно!");
