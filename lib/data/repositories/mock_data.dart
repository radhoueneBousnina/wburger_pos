import '../models/order_models.dart';
import '../models/stock_models.dart';

// ============================================================
// MOCK CATEGORIES
// ============================================================
final List<Category> mockCategories = [
  const Category(id: 'cat1', name: 'Burgers', iconEmoji: '🍔'),
  const Category(id: 'cat2', name: 'Chicken', iconEmoji: '🍗'),
  const Category(id: 'cat3', name: 'Sides', iconEmoji: '🍟'),
  const Category(id: 'cat4', name: 'Drinks', iconEmoji: '🥤'),
  const Category(id: 'cat5', name: 'Desserts', iconEmoji: '🍦'),
  const Category(id: 'cat6', name: 'Combos', iconEmoji: '🎁'),
];

// ============================================================
// MOCK PRODUCTS
// ============================================================
final List<Product> mockProducts = [
  // Burgers
  const Product(
    id: 'p1',
    categoryId: 'cat1',
    name: 'W Classic Burger',
    description: 'Beef patty, cheddar, lettuce, tomato, pickles',
    price: 12.5,
    imageUrl: 'assets/images/product_images.png',
  ),
  const Product(
    id: 'p2',
    categoryId: 'cat1',
    name: 'W Double',
    description: 'Double beef, double cheddar, special sauce',
    price: 16.9,
    imageUrl: 'assets/images/product_images.png',
  ),
  const Product(
    id: 'p3',
    categoryId: 'cat1',
    name: 'W Smash',
    description: 'Crispy smash patty, caramelized onions, mayo',
    price: 13.5,
    imageUrl: 'assets/images/product_images.png',
  ),
  const Product(
    id: 'p4',
    categoryId: 'cat1',
    name: 'W BBQ Burger',
    description: 'Beef patty, BBQ sauce, cheddar, crispy onions',
    price: 14.9,
    imageUrl: 'assets/images/product_images.png',
  ),
  // Chicken
  const Product(
    id: 'p5',
    categoryId: 'cat2',
    name: 'W Crispy Chicken',
    description: 'Crispy fried chicken fillet, coleslaw, pickles',
    price: 12.0,
    imageUrl: 'assets/images/product_images.png',
  ),
  const Product(
    id: 'p6',
    categoryId: 'cat2',
    name: 'W Spicy Chicken',
    description: 'Spicy crispy chicken, jalapeños, sriracha mayo',
    price: 13.5,
    imageUrl: 'assets/images/product_images.png',
  ),
  const Product(
    id: 'p7',
    categoryId: 'cat2',
    name: 'Chicken Strips x4',
    description: '4 crispy chicken strips with dipping sauce',
    price: 9.5,
    imageUrl: 'assets/images/product_images.png',
  ),
  // Sides
  const Product(
    id: 'p8',
    categoryId: 'cat3',
    name: 'Classic Fries',
    description: 'Golden crispy fries, lightly salted',
    price: 4.5,
    imageUrl: 'assets/images/product_images.png',
  ),
  const Product(
    id: 'p9',
    categoryId: 'cat3',
    name: 'Loaded Fries',
    description: 'Fries with cheddar sauce & crispy bacon bits',
    price: 6.9,
    imageUrl: 'assets/images/product_images.png',
  ),
  const Product(
    id: 'p10',
    categoryId: 'cat3',
    name: 'Onion Rings',
    description: 'Crispy battered onion rings',
    price: 5.5,
    imageUrl: 'assets/images/product_images.png',
  ),
  // Drinks
  const Product(
    id: 'p11',
    categoryId: 'cat4',
    name: 'Coca-Cola',
    description: '33cl can',
    price: 2.5,
    imageUrl: 'assets/images/product_images.png',
  ),
  const Product(
    id: 'p12',
    categoryId: 'cat4',
    name: 'Fresh Lemonade',
    description: 'Homemade squeezed lemonade',
    price: 4.0,
    imageUrl: 'assets/images/product_images.png',
  ),
  const Product(
    id: 'p13',
    categoryId: 'cat4',
    name: 'Mineral Water',
    description: '50cl, still',
    price: 1.5,
    imageUrl: 'assets/images/product_images.png',
  ),
  // Desserts
  const Product(
    id: 'p14',
    categoryId: 'cat5',
    name: 'W Milkshake',
    description: 'Vanilla, strawberry or chocolate',
    price: 7.5,
    imageUrl: 'assets/images/product_images.png',
  ),
  const Product(
    id: 'p15',
    categoryId: 'cat5',
    name: 'Ice Cream Cup',
    description: 'Smooth vanilla ice cream',
    price: 4.0,
    imageUrl: 'assets/images/product_images.png',
  ),
  // Combos
  const Product(
    id: 'p16',
    categoryId: 'cat6',
    name: 'W Classic Combo',
    description: 'Classic Burger + Fries + Drink',
    price: 17.9,
    imageUrl: 'assets/images/product_images.png',
  ),
  const Product(
    id: 'p17',
    categoryId: 'cat6',
    name: 'W Double Combo',
    description: 'Double Burger + Loaded Fries + Drink',
    price: 22.9,
    imageUrl: 'assets/images/product_images.png',
  ),
];

// ============================================================
// MOCK STOCK ITEMS
// ============================================================
final List<StockItem> mockStockItems = [
  const StockItem(
      id: 's1',
      name: 'Ground Beef',
      unit: 'kg',
      quantity: 8.5,
      minThreshold: 5.0,
      purchasePrice: 18.0,
      basePrice: 20.0),
  const StockItem(
      id: 's2',
      name: 'Chicken Fillet',
      unit: 'kg',
      quantity: 3.2,
      minThreshold: 4.0,
      purchasePrice: 14.0,
      basePrice: 16.0),
  const StockItem(
      id: 's3',
      name: 'Burger Buns',
      unit: 'pcs',
      quantity: 45,
      minThreshold: 20,
      purchasePrice: 0.35,
      basePrice: 0.5),
  const StockItem(
      id: 's4',
      name: 'Cheddar Slices',
      unit: 'pcs',
      quantity: 80,
      minThreshold: 30,
      purchasePrice: 0.15,
      basePrice: 0.25),
  const StockItem(
      id: 's5',
      name: 'Lettuce',
      unit: 'kg',
      quantity: 1.2,
      minThreshold: 1.5,
      purchasePrice: 2.5,
      basePrice: 3.0),
  const StockItem(
      id: 's6',
      name: 'Tomatoes',
      unit: 'kg',
      quantity: 2.8,
      minThreshold: 2.0,
      purchasePrice: 2.0,
      basePrice: 2.5),
  const StockItem(
      id: 's7',
      name: 'Pickles',
      unit: 'kg',
      quantity: 3.5,
      minThreshold: 1.0,
      purchasePrice: 3.5,
      basePrice: 4.0),
  const StockItem(
      id: 's8',
      name: 'Potatoes',
      unit: 'kg',
      quantity: 12.0,
      minThreshold: 8.0,
      purchasePrice: 1.2,
      basePrice: 1.5),
  const StockItem(
      id: 's9',
      name: 'Frying Oil',
      unit: 'l',
      quantity: 4.0,
      minThreshold: 3.0,
      purchasePrice: 4.0,
      basePrice: 5.0),
  const StockItem(
      id: 's10',
      name: 'Coca-Cola Cans',
      unit: 'pcs',
      quantity: 18,
      minThreshold: 24,
      purchasePrice: 1.0,
      basePrice: 1.2),
  const StockItem(
      id: 's11',
      name: 'BBQ Sauce',
      unit: 'kg',
      quantity: 2.1,
      minThreshold: 1.0,
      purchasePrice: 5.0,
      basePrice: 6.0),
  const StockItem(
      id: 's12',
      name: 'Mayo',
      unit: 'kg',
      quantity: 1.8,
      minThreshold: 1.5,
      purchasePrice: 4.0,
      basePrice: 5.0),
];

// ============================================================
// MOCK ORDERS (Today's Sales)
// ============================================================
List<Order> _buildMockOrders() {
  final now = DateTime.now();
  final p1 = mockProducts[0];
  final p5 = mockProducts[4];
  final p8 = mockProducts[7];
  final p11 = mockProducts[10];

  return [
    Order(
      id: 'o1',
      ticketNumber: 'T-001',
      createdAt: now.subtract(const Duration(hours: 5, minutes: 12)),
      items: [
        CartItem(product: p1, quantity: 1),
        CartItem(product: p8, quantity: 1),
        CartItem(product: p11, quantity: 1)
      ],
      orderType: OrderType.dineIn,
      paymentType: PaymentType.cash,
      status: OrderStatus.validated,
    ),
    Order(
      id: 'o2',
      ticketNumber: 'T-002',
      createdAt: now.subtract(const Duration(hours: 4, minutes: 45)),
      items: [
        CartItem(product: mockProducts[1], quantity: 2),
        CartItem(product: p8, quantity: 2)
      ],
      orderType: OrderType.takeaway,
      paymentType: PaymentType.card,
      status: OrderStatus.validated,
    ),
    Order(
      id: 'o3',
      ticketNumber: 'T-003',
      createdAt: now.subtract(const Duration(hours: 4, minutes: 10)),
      items: [
        CartItem(product: p5, quantity: 1),
        CartItem(product: mockProducts[9], quantity: 1)
      ],
      orderType: OrderType.takeaway,
      paymentType: PaymentType.cash,
      status: OrderStatus.cancelled,
      cancellationReason: 'Customer changed their mind',
    ),
    Order(
      id: 'o4',
      ticketNumber: 'T-004',
      createdAt: now.subtract(const Duration(hours: 3, minutes: 30)),
      items: [CartItem(product: mockProducts[15], quantity: 1)],
      orderType: OrderType.dineIn,
      paymentType: PaymentType.card,
      status: OrderStatus.validated,
      isQrOrder: true,
      customerName: 'Ahmed B.',
    ),
    Order(
      id: 'o5',
      ticketNumber: 'T-005',
      createdAt: now.subtract(const Duration(hours: 2, minutes: 15)),
      items: [
        CartItem(product: mockProducts[3], quantity: 1),
        CartItem(product: mockProducts[8], quantity: 1),
        CartItem(product: p11, quantity: 2)
      ],
      orderType: OrderType.dineIn,
      paymentType: PaymentType.staff,
      status: OrderStatus.validated,
    ),
    Order(
      id: 'o6',
      ticketNumber: 'T-006',
      createdAt: now.subtract(const Duration(hours: 1, minutes: 45)),
      items: [
        CartItem(product: mockProducts[16], quantity: 1),
        CartItem(product: mockProducts[13], quantity: 1)
      ],
      orderType: OrderType.takeaway,
      paymentType: PaymentType.cash,
      status: OrderStatus.validated,
    ),
    Order(
      id: 'o7',
      ticketNumber: 'T-007',
      createdAt: now.subtract(const Duration(minutes: 55)),
      items: [
        CartItem(product: p1, quantity: 3),
        CartItem(product: p8, quantity: 3),
        CartItem(product: mockProducts[11], quantity: 3)
      ],
      orderType: OrderType.dineIn,
      paymentType: PaymentType.card,
      status: OrderStatus.validated,
    ),
    Order(
      id: 'o8',
      ticketNumber: 'T-008',
      createdAt: now.subtract(const Duration(minutes: 20)),
      items: [
        CartItem(product: mockProducts[5], quantity: 1),
        CartItem(product: mockProducts[8], quantity: 1)
      ],
      orderType: OrderType.takeaway,
      paymentType: PaymentType.cash,
      status: OrderStatus.validated,
    ),
  ];
}

final List<Order> mockOrders = _buildMockOrders();

// ============================================================
// MOCK PURCHASES
// ============================================================
List<Purchase> _buildMockPurchases() {
  final now = DateTime.now();
  return [
    Purchase(
      id: 'pur1',
      createdAt: now.subtract(const Duration(days: 2)),
      lines: [
        PurchaseLine(
            stockItem: mockStockItems[0], quantity: 10, purchasePrice: 18.0),
        PurchaseLine(
            stockItem: mockStockItems[2], quantity: 100, purchasePrice: 0.35),
      ],
      invoiceImagePath: null,
      status: PurchaseStatus.validated,
    ),
    Purchase(
      id: 'pur2',
      createdAt: now.subtract(const Duration(days: 1)),
      lines: [
        PurchaseLine(
            stockItem: mockStockItems[1], quantity: 8, purchasePrice: 14.0),
        PurchaseLine(
            stockItem: mockStockItems[9], quantity: 48, purchasePrice: 1.0),
      ],
      invoiceImagePath: null,
      status: PurchaseStatus.validated,
    ),
  ];
}

final List<Purchase> mockPurchases = _buildMockPurchases();
