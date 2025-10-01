// Инициализация коллекций MongoDB для интернет-магазина

// Переключение на базу данных shop
db = db.getSiblingDB('shop');

// Создание коллекций
db.createCollection("categories");
db.createCollection("products");
db.createCollection("customers");
db.createCollection("orders");
db.createCollection("order_items");
db.createCollection("suppliers");
db.createCollection("shipments");

print("Коллекции MongoDB созданы успешно!");
