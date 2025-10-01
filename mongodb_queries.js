// MongoDB запросы для интернет-магазина

const mongodbQueries = [
  {
    id: 1,
    title: "Список товаров с указанием их категорий",
    description: "Получить список всех товаров с названиями их категорий",
    query: `db.products.aggregate([
  {
    $lookup: {
      from: "categories",
      localField: "category_id",
      foreignField: "_id",
      as: "category"
    }
  },
  {
    $unwind: "$category"
  },
  {
    $project: {
      _id: 1,
      name: 1,
      price: 1,
      stock: 1,
      "category_name": "$category.category_name"
    }
  }
])`
  },
  {
    id: 2,
    title: "Количество товаров в каждой категории",
    description: "Определить количество товаров в каждой категории",
    query: `db.products.aggregate([
  {
    $lookup: {
      from: "categories",
      localField: "category_id",
      foreignField: "_id",
      as: "category"
    }
  },
  {
    $unwind: "$category"
  },
  {
    $group: {
      _id: "$category.category_name",
      count: { $sum: 1 }
    }
  },
  {
    $sort: { count: -1 }
  }
])`
  },
  {
    id: 3,
    title: "Клиенты с заказами выше определенной суммы",
    description: "Найти клиентов, совершивших заказы на сумму выше 50000 рублей",
    query: `db.customers.aggregate([
  {
    $lookup: {
      from: "orders",
      localField: "_id",
      foreignField: "customer_id",
      as: "orders"
    }
  },
  {
    $match: {
      "orders.total_amount": { $gt: 50000 }
    }
  },
  {
    $project: {
      _id: 1,
      full_name: 1,
      email: 1,
      "total_orders": { $size: "$orders" },
      "max_order_amount": { $max: "$orders.total_amount" }
    }
  }
])`
  },
  {
    id: 4,
    title: "Товары от нескольких поставщиков",
    description: "Определить товары, которые поставляются более чем одним поставщиком (по аналогии с заказами)",
    query: `db.products.aggregate([
  {
    $lookup: {
      from: "order_items",
      localField: "_id",
      foreignField: "product_id",
      as: "order_items"
    }
  },
  {
    $match: {
      "order_items": { $exists: true, $ne: [] }
    }
  },
  {
    $addFields: {
      "order_count": { $size: "$order_items" }
    }
  },
  {
    $match: {
      "order_count": { $gt: 1 }
    }
  },
  {
    $project: {
      _id: 1,
      name: 1,
      price: 1,
      "order_count": 1
    }
  }
])`
  },
  {
    id: 5,
    title: "Категории и количество товаров",
    description: "Получить список категорий и количество товаров в каждой из них",
    query: `db.categories.aggregate([
  {
    $lookup: {
      from: "products",
      localField: "_id",
      foreignField: "category_id",
      as: "products"
    }
  },
  {
    $project: {
      _id: 1,
      category_name: 1,
      parent_id: 1,
      "product_count": { $size: "$products" }
    }
  },
  {
    $sort: { product_count: -1 }
  }
])`
  },
  {
    id: 6,
    title: "Клиенты без заказов",
    description: "Найти клиентов, которые не сделали ни одного заказа",
    query: `db.customers.aggregate([
  {
    $lookup: {
      from: "orders",
      localField: "_id",
      foreignField: "customer_id",
      as: "orders"
    }
  },
  {
    $match: {
      "orders": { $size: 0 }
    }
  },
  {
    $project: {
      _id: 1,
      full_name: 1,
      email: 1,
      registration_date: 1
    }
  }
])`
  },
  {
    id: 7,
    title: "Поставщики и количество товаров",
    description: "Определить поставщиков и количество различных товаров, которые они поставляют",
    query: `db.suppliers.aggregate([
  {
    $lookup: {
      from: "products",
      localField: "_id",
      foreignField: "supplier_id",
      as: "products"
    }
  },
  {
    $project: {
      _id: 1,
      name: 1,
      country: 1,
      "product_count": { $size: "$products" }
    }
  },
  {
    $sort: { product_count: -1 }
  }
])`
  },
  {
    id: 8,
    title: "Заказы с одинаковыми товарами",
    description: "Найти заказы, содержащие одинаковые товары в одинаковом количестве",
    query: `db.orders.aggregate([
  {
    $lookup: {
      from: "order_items",
      localField: "_id",
      foreignField: "order_id",
      as: "items"
    }
  },
  {
    $match: {
      "items": { $exists: true, $ne: [] }
    }
  },
  {
    $addFields: {
      "item_signature": {
        $map: {
          input: "$items",
          as: "item",
          in: {
            product_id: "$$item.product_id",
            quantity: "$$item.quantity"
          }
        }
      }
    }
  },
  {
    $group: {
      _id: "$item_signature",
      orders: { $push: "$_id" },
      count: { $sum: 1 }
    }
  },
  {
    $match: {
      count: { $gt: 1 }
    }
  }
])`
  },
  {
    id: 9,
    title: "Товары без заказов",
    description: "Определить товары, которые ни разу не были заказаны",
    query: `db.products.aggregate([
  {
    $lookup: {
      from: "order_items",
      localField: "_id",
      foreignField: "product_id",
      as: "order_items"
    }
  },
  {
    $match: {
      "order_items": { $size: 0 }
    }
  },
  {
    $project: {
      _id: 1,
      name: 1,
      price: 1,
      stock: 1
    }
  }
])`
  },
  {
    id: 10,
    title: "Клиенты по месяцам регистрации",
    description: "Получить клиентов, зарегистрированных в один и тот же месяц, с указанием их заказов",
    query: `db.customers.aggregate([
  {
    $addFields: {
      "registration_month": {
        $dateToString: {
          format: "%Y-%m",
          date: "$registration_date"
        }
      }
    }
  },
  {
    $lookup: {
      from: "orders",
      localField: "_id",
      foreignField: "customer_id",
      as: "orders"
    }
  },
  {
    $group: {
      _id: "$registration_month",
      customers: {
        $push: {
          customer_id: "$_id",
          full_name: "$full_name",
          email: "$email",
          order_count: { $size: "$orders" },
          total_spent: { $sum: "$orders.total_amount" }
        }
      },
      customer_count: { $sum: 1 }
    }
  },
  {
    $match: {
      customer_count: { $gt: 1 }
    }
  },
  {
    $sort: { _id: 1 }
  }
])`
  },
  {
    id: 11,
    title: "Суммарный объем продаж по категориям",
    description: "Определить суммарный объем продаж по категориям товаров",
    query: `db.products.aggregate([
  {
    $lookup: {
      from: "categories",
      localField: "category_id",
      foreignField: "_id",
      as: "category"
    }
  },
  {
    $unwind: "$category"
  },
  {
    $lookup: {
      from: "order_items",
      localField: "_id",
      foreignField: "product_id",
      as: "order_items"
    }
  },
  {
    $unwind: "$order_items"
  },
  {
    $group: {
      _id: "$category.category_name",
      total_sales: { $sum: { $multiply: ["$order_items.quantity", "$order_items.unit_price"] } },
      total_quantity: { $sum: "$order_items.quantity" }
    }
  },
  {
    $sort: { total_sales: -1 }
  }
])`
  },
  {
    id: 12,
    title: "Самые дорогие заказы по категориям",
    description: "Найти клиентов, сделавших самый дорогой заказ в каждой категории товаров",
    query: `db.orders.aggregate([
  {
    $lookup: {
      from: "order_items",
      localField: "_id",
      foreignField: "order_id",
      as: "items"
    }
  },
  {
    $unwind: "$items"
  },
  {
    $lookup: {
      from: "products",
      localField: "items.product_id",
      foreignField: "_id",
      as: "product"
    }
  },
  {
    $unwind: "$product"
  },
  {
    $lookup: {
      from: "categories",
      localField: "product.category_id",
      foreignField: "_id",
      as: "category"
    }
  },
  {
    $unwind: "$category"
  },
  {
    $group: {
      _id: "$category.category_name",
      max_order_amount: { $max: "$total_amount" },
      orders: {
        $push: {
          order_id: "$_id",
          customer_id: "$customer_id",
          total_amount: "$total_amount"
        }
      }
    }
  },
  {
    $unwind: "$orders"
  },
  {
    $match: {
      $expr: { $eq: ["$orders.total_amount", "$max_order_amount"] }
    }
  },
  {
    $lookup: {
      from: "customers",
      localField: "orders.customer_id",
      foreignField: "_id",
      as: "customer"
    }
  },
  {
    $unwind: "$customer"
  },
  {
    $project: {
      category: "$_id",
      max_amount: "$max_order_amount",
      customer_name: "$customer.full_name",
      customer_email: "$customer.email",
      order_id: "$orders.order_id"
    }
  }
])`
  },
  {
    id: 13,
    title: "Связь поставщиков и клиентов через товары",
    description: "Получить поставщиков и клиентов, связанных через товары, которые они поставляют и покупают",
    query: `db.suppliers.aggregate([
  {
    $lookup: {
      from: "products",
      localField: "_id",
      foreignField: "supplier_id",
      as: "supplied_products"
    }
  },
  {
    $unwind: "$supplied_products"
  },
  {
    $lookup: {
      from: "order_items",
      localField: "supplied_products._id",
      foreignField: "product_id",
      as: "order_items"
    }
  },
  {
    $unwind: "$order_items"
  },
  {
    $lookup: {
      from: "orders",
      localField: "order_items.order_id",
      foreignField: "_id",
      as: "order"
    }
  },
  {
    $unwind: "$order"
  },
  {
    $lookup: {
      from: "customers",
      localField: "order.customer_id",
      foreignField: "_id",
      as: "customer"
    }
  },
  {
    $unwind: "$customer"
  },
  {
    $group: {
      _id: {
        supplier_id: "$_id",
        supplier_name: "$name",
        customer_id: "$customer._id",
        customer_name: "$customer.full_name"
      },
      products: {
        $addToSet: {
          product_name: "$supplied_products.name",
          quantity: "$order_items.quantity"
        }
      }
    }
  },
  {
    $project: {
      supplier: {
        id: "$_id.supplier_id",
        name: "$_id.supplier_name"
      },
      customer: {
        id: "$_id.customer_id",
        name: "$_id.customer_name"
      },
      shared_products: "$products"
    }
  }
])`
  },
  {
    id: 14,
    title: "Товары с низким средним объемом продаж",
    description: "Определить товары, по которым средний объем продаж ниже 2 единиц",
    query: `db.products.aggregate([
  {
    $lookup: {
      from: "order_items",
      localField: "_id",
      foreignField: "product_id",
      as: "order_items"
    }
  },
  {
    $match: {
      "order_items": { $exists: true, $ne: [] }
    }
  },
  {
    $addFields: {
      "avg_quantity": { $avg: "$order_items.quantity" },
      "total_quantity": { $sum: "$order_items.quantity" },
      "order_count": { $size: "$order_items" }
    }
  },
  {
    $match: {
      "avg_quantity": { $lt: 2 }
    }
  },
  {
    $project: {
      _id: 1,
      name: 1,
      price: 1,
      avg_quantity: 1,
      total_quantity: 1,
      order_count: 1
    }
  },
  {
    $sort: { avg_quantity: 1 }
  }
])`
  },
  {
    id: 15,
    title: "Рейтинг клиентов по сумме заказов",
    description: "Получить клиентов с указанием их места в рейтинге по сумме заказов",
    query: `db.customers.aggregate([
  {
    $lookup: {
      from: "orders",
      localField: "_id",
      foreignField: "customer_id",
      as: "orders"
    }
  },
  {
    $addFields: {
      "total_spent": { $sum: "$orders.total_amount" },
      "order_count": { $size: "$orders" }
    }
  },
  {
    $match: {
      "total_spent": { $gt: 0 }
    }
  },
  {
    $sort: { total_spent: -1 }
  },
  {
    $group: {
      _id: null,
      customers: {
        $push: {
          customer_id: "$_id",
          full_name: "$full_name",
          email: "$email",
          total_spent: "$total_spent",
          order_count: "$order_count"
        }
      }
    }
  },
  {
    $unwind: {
      path: "$customers",
      includeArrayIndex: "rank"
    }
  },
  {
    $addFields: {
      "customers.rank": { $add: ["$rank", 1] }
    }
  },
  {
    $replaceRoot: { newRoot: "$customers" }
  },
  {
    $project: {
      rank: 1,
      customer_id: 1,
      full_name: 1,
      email: 1,
      total_spent: 1,
      order_count: 1
    }
  }
])`
  }
];

// Экспорт для использования в других модулях
if (typeof module !== 'undefined' && module.exports) {
  module.exports = mongodbQueries;
}
