// Заполнение коллекций MongoDB тестовыми данными для интернет-магазина

// Очистка существующих данных
db.categories.deleteMany({});
db.products.deleteMany({});
db.customers.deleteMany({});
db.orders.deleteMany({});
db.order_items.deleteMany({});
db.suppliers.deleteMany({});
db.shipments.deleteMany({});

print("Существующие данные очищены");

// Вставка категорий
db.categories.insertMany([
  { _id: 1, category_name: "Электроника", parent_id: null },
  { _id: 2, category_name: "Смартфоны", parent_id: 1 },
  { _id: 3, category_name: "Ноутбуки", parent_id: 1 },
  { _id: 4, category_name: "Одежда", parent_id: null },
  { _id: 5, category_name: "Мужская одежда", parent_id: 4 },
  { _id: 6, category_name: "Женская одежда", parent_id: 4 },
  { _id: 7, category_name: "Книги", parent_id: null },
  { _id: 8, category_name: "Художественная литература", parent_id: 7 },
  { _id: 9, category_name: "Техническая литература", parent_id: 7 },
  { _id: 10, category_name: "Спорт", parent_id: null },
  { _id: 11, category_name: "Фитнес", parent_id: 10 },
  { _id: 12, category_name: "Туризм", parent_id: 10 }
]);

print("Категории добавлены");

// Вставка поставщиков
db.suppliers.insertMany([
  { _id: 1, name: "ТехноМир", country: "Россия" },
  { _id: 2, name: "ЭлектронГрупп", country: "Китай" },
  { _id: 3, name: "МодаСтиль", country: "Турция" },
  { _id: 4, name: "КнижныйДом", country: "Россия" },
  { _id: 5, name: "СпортМакс", country: "Германия" },
  { _id: 6, name: "ГлобалТек", country: "США" },
  { _id: 7, name: "АзиатТрейд", country: "Япония" },
  { _id: 8, name: "ЕвроМода", country: "Италия" }
]);

print("Поставщики добавлены");

// Вставка товаров
db.products.insertMany([
  { _id: 1, name: "iPhone 15 Pro", category_id: 2, price: 89990, stock: 25 },
  { _id: 2, name: "Samsung Galaxy S24", category_id: 2, price: 79990, stock: 30 },
  { _id: 3, name: "MacBook Pro M3", category_id: 3, price: 199990, stock: 15 },
  { _id: 4, name: "Dell XPS 13", category_id: 3, price: 129990, stock: 20 },
  { _id: 5, name: "Мужская рубашка", category_id: 5, price: 2990, stock: 50 },
  { _id: 6, name: "Женское платье", category_id: 6, price: 4990, stock: 40 },
  { _id: 7, name: "Джинсы мужские", category_id: 5, price: 3990, stock: 35 },
  { _id: 8, name: "Куртка женская", category_id: 6, price: 7990, stock: 25 },
  { _id: 9, name: "Война и мир", category_id: 8, price: 890, stock: 100 },
  { _id: 10, name: "JavaScript для начинающих", category_id: 9, price: 1990, stock: 60 },
  { _id: 11, name: "Гантели 10кг", category_id: 11, price: 2990, stock: 30 },
  { _id: 12, name: "Рюкзак туристический", category_id: 12, price: 4990, stock: 20 },
  { _id: 13, name: "iPad Air", category_id: 2, price: 59990, stock: 18 },
  { _id: 14, name: "ThinkPad X1", category_id: 3, price: 159990, stock: 12 },
  { _id: 15, name: "Кроссовки Nike", category_id: 11, price: 8990, stock: 45 },
  { _id: 16, name: "Палатка 4-местная", category_id: 12, price: 12990, stock: 15 },
  { _id: 17, name: "Python для всех", category_id: 9, price: 2490, stock: 80 },
  { _id: 18, name: "Свитер мужской", category_id: 5, price: 3990, stock: 30 },
  { _id: 19, name: "Сумка женская", category_id: 6, price: 2990, stock: 25 },
  { _id: 20, name: "Мастер и Маргарита", category_id: 8, price: 690, stock: 90 }
]);

print("Товары добавлены");

// Вставка клиентов
db.customers.insertMany([
  { _id: 1, full_name: "Иванов Иван Иванович", email: "ivanov@mail.ru", registration_date: new Date("2023-01-15") },
  { _id: 2, full_name: "Петрова Анна Сергеевна", email: "petrova@gmail.com", registration_date: new Date("2023-02-20") },
  { _id: 3, full_name: "Сидоров Михаил Петрович", email: "sidorov@yandex.ru", registration_date: new Date("2023-01-10") },
  { _id: 4, full_name: "Козлова Елена Владимировна", email: "kozlova@mail.ru", registration_date: new Date("2023-03-05") },
  { _id: 5, full_name: "Морозов Алексей Дмитриевич", email: "morozov@gmail.com", registration_date: new Date("2023-02-28") },
  { _id: 6, full_name: "Волкова Мария Александровна", email: "volkova@yandex.ru", registration_date: new Date("2023-03-15") },
  { _id: 7, full_name: "Новиков Дмитрий Сергеевич", email: "novikov@mail.ru", registration_date: new Date("2023-01-25") },
  { _id: 8, full_name: "Федорова Ольга Николаевна", email: "fedorova@gmail.com", registration_date: new Date("2023-02-10") },
  { _id: 9, full_name: "Лебедев Андрей Владимирович", email: "lebedev@yandex.ru", registration_date: new Date("2023-03-01") },
  { _id: 10, full_name: "Соколова Татьяна Игоревна", email: "sokolova@mail.ru", registration_date: new Date("2023-02-15") },
  { _id: 11, full_name: "Кузнецов Павел Андреевич", email: "kuznetsov@gmail.com", registration_date: new Date("2023-01-30") },
  { _id: 12, full_name: "Попова Екатерина Дмитриевна", email: "popova@yandex.ru", registration_date: new Date("2023-03-10") },
  { _id: 13, full_name: "Васильев Игорь Петрович", email: "vasiliev@mail.ru", registration_date: new Date("2023-02-05") },
  { _id: 14, full_name: "Семенова Наталья Владимировна", email: "semenova@gmail.com", registration_date: new Date("2023-01-20") },
  { _id: 15, full_name: "Голубев Сергей Александрович", email: "golubev@yandex.ru", registration_date: new Date("2023-03-20") }
]);

print("Клиенты добавлены");

// Вставка заказов
db.orders.insertMany([
  { _id: 1, customer_id: 1, order_date: new Date("2023-04-15"), total_amount: 89990 },
  { _id: 2, customer_id: 2, order_date: new Date("2023-04-20"), total_amount: 129980 },
  { _id: 3, customer_id: 3, order_date: new Date("2023-04-25"), total_amount: 7980 },
  { _id: 4, customer_id: 4, order_date: new Date("2023-05-01"), total_amount: 199990 },
  { _id: 5, customer_id: 5, order_date: new Date("2023-05-05"), total_amount: 11980 },
  { _id: 6, customer_id: 6, order_date: new Date("2023-05-10"), total_amount: 15990 },
  { _id: 7, customer_id: 7, order_date: new Date("2023-05-15"), total_amount: 4480 },
  { _id: 8, customer_id: 8, order_date: new Date("2023-05-20"), total_amount: 59990 },
  { _id: 9, customer_id: 9, order_date: new Date("2023-05-25"), total_amount: 21990 },
  { _id: 10, customer_id: 10, order_date: new Date("2023-06-01"), total_amount: 2880 },
  { _id: 11, customer_id: 11, order_date: new Date("2023-06-05"), total_amount: 17990 },
  { _id: 12, customer_id: 12, order_date: new Date("2023-06-10"), total_amount: 12990 },
  { _id: 13, customer_id: 1, order_date: new Date("2023-06-15"), total_amount: 3990 },
  { _id: 14, customer_id: 3, order_date: new Date("2023-06-20"), total_amount: 2490 },
  { _id: 15, customer_id: 5, order_date: new Date("2023-06-25"), total_amount: 8990 }
]);

print("Заказы добавлены");

// Вставка элементов заказов
db.order_items.insertMany([
  { _id: 1, order_id: 1, product_id: 1, quantity: 1, unit_price: 89990 },
  { _id: 2, order_id: 2, product_id: 2, quantity: 1, unit_price: 79990 },
  { _id: 3, order_id: 2, product_id: 5, quantity: 1, unit_price: 2990 },
  { _id: 4, order_id: 2, product_id: 6, quantity: 1, unit_price: 4990 },
  { _id: 5, order_id: 3, product_id: 7, quantity: 2, unit_price: 3990 },
  { _id: 6, order_id: 4, product_id: 3, quantity: 1, unit_price: 199990 },
  { _id: 7, order_id: 5, product_id: 8, quantity: 1, unit_price: 7990 },
  { _id: 8, order_id: 5, product_id: 9, quantity: 1, unit_price: 890 },
  { _id: 9, order_id: 5, product_id: 10, quantity: 1, unit_price: 1990 },
  { _id: 10, order_id: 6, product_id: 11, quantity: 1, unit_price: 2990 },
  { _id: 11, order_id: 6, product_id: 12, quantity: 1, unit_price: 4990 },
  { _id: 12, order_id: 6, product_id: 15, quantity: 1, unit_price: 8990 },
  { _id: 13, order_id: 7, product_id: 9, quantity: 2, unit_price: 890 },
  { _id: 14, order_id: 7, product_id: 17, quantity: 1, unit_price: 2490 },
  { _id: 15, order_id: 8, product_id: 13, quantity: 1, unit_price: 59990 },
  { _id: 16, order_id: 9, product_id: 14, quantity: 1, unit_price: 159990 },
  { _id: 17, order_id: 9, product_id: 18, quantity: 1, unit_price: 3990 },
  { _id: 18, order_id: 9, product_id: 19, quantity: 1, unit_price: 2990 },
  { _id: 19, order_id: 10, product_id: 20, quantity: 2, unit_price: 690 },
  { _id: 20, order_id: 10, product_id: 10, quantity: 1, unit_price: 1990 },
  { _id: 21, order_id: 11, product_id: 15, quantity: 2, unit_price: 8990 },
  { _id: 22, order_id: 12, product_id: 16, quantity: 1, unit_price: 12990 },
  { _id: 23, order_id: 13, product_id: 7, quantity: 1, unit_price: 3990 },
  { _id: 24, order_id: 14, product_id: 17, quantity: 1, unit_price: 2490 },
  { _id: 25, order_id: 15, product_id: 15, quantity: 1, unit_price: 8990 }
]);

print("Элементы заказов добавлены");

// Вставка поставок
db.shipments.insertMany([
  { _id: 1, order_id: 1, shipment_date: new Date("2023-04-16"), status: "Доставлено" },
  { _id: 2, order_id: 2, shipment_date: new Date("2023-04-21"), status: "Доставлено" },
  { _id: 3, order_id: 3, shipment_date: new Date("2023-04-26"), status: "В пути" },
  { _id: 4, order_id: 4, shipment_date: new Date("2023-05-02"), status: "Доставлено" },
  { _id: 5, order_id: 5, shipment_date: new Date("2023-05-06"), status: "Доставлено" },
  { _id: 6, order_id: 6, shipment_date: new Date("2023-05-11"), status: "В пути" },
  { _id: 7, order_id: 7, shipment_date: new Date("2023-05-16"), status: "Доставлено" },
  { _id: 8, order_id: 8, shipment_date: new Date("2023-05-21"), status: "Обработка" },
  { _id: 9, order_id: 9, shipment_date: new Date("2023-05-26"), status: "Доставлено" },
  { _id: 10, order_id: 10, shipment_date: new Date("2023-06-02"), status: "Доставлено" },
  { _id: 11, order_id: 11, shipment_date: new Date("2023-06-06"), status: "В пути" },
  { _id: 12, order_id: 12, shipment_date: new Date("2023-06-11"), status: "Обработка" },
  { _id: 13, order_id: 13, shipment_date: new Date("2023-06-16"), status: "Доставлено" },
  { _id: 14, order_id: 14, shipment_date: new Date("2023-06-21"), status: "Доставлено" },
  { _id: 15, order_id: 15, shipment_date: new Date("2023-06-26"), status: "В пути" }
]);

print("Поставки добавлены");

print("Все тестовые данные успешно добавлены в MongoDB!");
