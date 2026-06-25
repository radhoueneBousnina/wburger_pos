import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wburger_pos/data/models/order_models.dart';
import 'package:wburger_pos/data/providers/app_providers.dart';

void main() {
  test('product parses meal eligibility flag', () {
    final mealEligible = Product.fromJson({
      'id': 1,
      'category_id': 2,
      'name': 'Classic',
      'price': '9.000',
      'can_be_meal': true,
    });
    final notEligible = Product.fromJson({
      'id': 2,
      'category_id': 2,
      'name': 'Sauce Cup',
      'price': '1.000',
    });

    expect(mealEligible.canBeMeal, isTrue);
    expect(notEligible.canBeMeal, isFalse);
  });

  test('staff totals use configured discount from original subtotal', () {
    final product = Product(
      id: '1',
      categoryId: 'burgers',
      name: 'Classic',
      description: '',
      price: 10,
    );
    final cart = CartState(
      items: [
        CartItem(product: product, quantity: 2, discountPercent: 50),
      ],
    );

    expect(cart.subtotal, 10);
    expect(cart.originalSubtotal, 20);
    expect(cart.staffDiscountAmount(40), 8);
    expect(
      cart.payableTotalFor(
        PaymentType.staff,
        staffDiscountPercent: 40,
      ),
      12,
    );
    expect(
      cart.discountAmountFor(
        PaymentType.staff,
        staffDiscountPercent: 40,
      ),
      8,
    );
    expect(cart.payableTotalFor(PaymentType.gift), 0);
    expect(cart.discountAmountFor(PaymentType.gift), 20);
    expect(cart.payableTotalFor(PaymentType.other), 10);
    expect(cart.discountAmountFor(PaymentType.other), 10);
  });

  test('order discount applies to the whole item-discounted cart', () {
    final product = Product(
      id: '1',
      categoryId: 'burgers',
      name: 'Classic',
      description: '',
      price: 10,
    );
    final cart = CartState(
      orderDiscountPercent: 10,
      items: [
        CartItem(product: product, quantity: 2),
        CartItem(product: product, quantity: 1, discountPercent: 50),
      ],
    );

    expect(cart.originalSubtotal, 30);
    expect(cart.itemDiscountAmount, 5);
    expect(cart.itemSubtotal, 25);
    expect(cart.orderDiscountAmount, 2.5);
    expect(cart.discountAmount, 7.5);
    expect(cart.subtotal, 22.5);
    expect(cart.payableTotalFor(PaymentType.other), 22.5);
    expect(cart.discountAmountFor(PaymentType.other), 7.5);
  });

  test('discount percentages are clamped for item and order totals', () {
    final product = Product(
      id: '1',
      categoryId: 'burgers',
      name: 'Classic',
      description: '',
      price: 10,
    );

    final overDiscountedItem = CartItem(
      product: product,
      quantity: 2,
      discountPercent: 150,
    );
    expect(overDiscountedItem.discountPercent, 100);
    expect(overDiscountedItem.unitPrice, 0);
    expect(overDiscountedItem.total, 0);
    expect(overDiscountedItem.discountAmount, 20);
    expect(overDiscountedItem.toJson('order-1')['unit_price'], '0.000');
    expect(overDiscountedItem.toLocalJson()['discount_percent'], 100);

    final negativeDiscountItem = CartItem(
      product: product,
      quantity: 2,
      discountPercent: -25,
    );
    expect(negativeDiscountItem.discountPercent, isNull);
    expect(negativeDiscountItem.unitPrice, 10);
    expect(negativeDiscountItem.total, 20);
    expect(negativeDiscountItem.discountAmount, 0);
    expect(negativeDiscountItem.toLocalJson().containsKey('discount_percent'),
        isFalse);

    final restoredItem = CartItem.fromLocalJson({
      ...overDiscountedItem.toLocalJson(),
      'discount_percent': '175',
    });
    expect(restoredItem.discountPercent, 100);
    expect(restoredItem.total, 0);

    final overOrderDiscountCart = CartState(
      orderDiscountPercent: 150,
      items: [CartItem(product: product, quantity: 2)],
    );
    expect(overOrderDiscountCart.orderDiscountAmount, 20);
    expect(overOrderDiscountCart.subtotal, 0);
    expect(overOrderDiscountCart.discountAmount, 20);

    final negativeOrderDiscountCart = CartState(
      orderDiscountPercent: -50,
      items: [CartItem(product: product, quantity: 2)],
    );
    expect(negativeOrderDiscountCart.orderDiscountAmount, 0);
    expect(negativeOrderDiscountCart.subtotal, 20);

    expect(overOrderDiscountCart.staffDiscountAmount(125), 20);
    expect(overOrderDiscountCart.staffTotal(125), 0);
    expect(overOrderDiscountCart.staffDiscountAmount(-25), 0);
    expect(overOrderDiscountCart.staffTotal(-25), 20);
  });

  test('product taps always create separate cart lines', () {
    final product = Product(
      id: '1',
      categoryId: 'burgers',
      name: 'Classic',
      description: '',
      price: 10,
    );
    const ketchup = CartSauceSelection(
      stockItemId: '11',
      name: 'Ketchup',
      productId: '1',
      productName: 'Classic',
      quantityRequired: 0.02,
    );
    const mayo = CartSauceSelection(
      stockItemId: '12',
      name: 'Mayo',
      productId: '1',
      productName: 'Classic',
      quantityRequired: 0.02,
    );

    final notifier = CartNotifier();
    notifier.addProduct(product, sauces: const [ketchup]);
    notifier.addProduct(product, sauces: const [mayo]);
    notifier.addProduct(product, sauces: const [ketchup]);

    expect(notifier.state.items, hasLength(3));
    expect(notifier.state.items.first.quantity, 1);
    expect(notifier.state.items.last.quantity, 1);

    notifier.updateQuantity(0, 2);
    expect(notifier.state.items.first.quantity, 2);

    final json = notifier.state.items.first.toJson('order-1');
    expect(json['selected_sauces'], isA<List>());
    expect(json['selected_sauces'].first['name'], 'Ketchup');
  });

  test('offline order snapshot preserves cart details and client line id', () {
    const product = Product(
      id: '1',
      categoryId: 'burgers',
      name: 'Classic',
      description: '',
      price: 10,
      canBeMeal: true,
    );
    const soda = Product(
      id: '2',
      categoryId: 'drinks',
      name: 'Soda',
      description: '',
      price: 3,
      isSoda: true,
    );
    const sauce = CartSauceSelection(
      stockItemId: '11',
      name: 'Ketchup',
      productId: '1',
      productName: 'Classic',
      quantityRequired: 1,
    );
    final item = CartItem(
      lineId: 'client-order-line-1',
      product: product,
      sauces: const [sauce],
      isMealUpgrade: true,
      mealAddOnPrice: 2,
      mealSodaProduct: soda,
    );
    final order = Order(
      id: 'offline-pos-order',
      ticketNumber: 'W-220626-106',
      createdAt: DateTime(2026, 6, 22, 12),
      items: [item],
      orderType: OrderType.takeaway,
      paymentType: PaymentType.cash,
      status: OrderStatus.validated,
      totalAmount: item.total,
    );

    final restored = Order.fromLocalJson(order.toLocalJson());
    expect(restored.id, order.id);
    expect(restored.items.single.displayName, 'Classic - Meal');
    expect(restored.items.single.product.canBeMeal, isTrue);
    expect(restored.items.single.mealSodaProduct?.isSoda, isTrue);
    expect(restored.items.single.sauces.single.name, 'Ketchup');

    final itemPayload = item.toJson(
      'server-order',
      includeItemDiscount: false,
      clientLineId: item.lineId,
    );
    expect(itemPayload['client_line_id'], 'client-order-line-1');
    expect(itemPayload['is_meal_upgrade'], isTrue);
  });

  test('offline queue stores item and order discounts consistently', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OfflineOrderQueueStore();
    final product = Product(
      id: '1',
      categoryId: 'burgers',
      name: 'Classic',
      description: '',
      price: 10,
    );
    final cart = CartState(
      orderDiscountPercent: 10,
      items: [
        CartItem(
          lineId: 'line-discounted',
          product: product,
          quantity: 2,
          discountPercent: 25,
        ),
        CartItem(
          lineId: 'line-full',
          product: product,
        ),
      ],
    );
    final localOrder = Order(
      id: 'offline-client-1',
      ticketNumber: 'W-220626-108',
      createdAt: DateTime(2026, 6, 22, 12),
      items: cart.items,
      orderType: OrderType.takeaway,
      paymentType: PaymentType.cash,
      status: OrderStatus.validated,
      totalAmount: cart.subtotal,
      discountAmount: cart.discountAmount,
    );

    await store.enqueue(
      OfflineQueuedOrder(
        clientOrderId: 'client-1',
        localOrderId: localOrder.id,
        serverOrderId: null,
        queuedAt: localOrder.createdAt,
        createPayload: const {'client_order_id': 'client-1'},
        itemPayloads: [
          for (final item in cart.items)
            item.toJson(
              localOrder.id,
              includeItemDiscount: false,
              clientLineId: item.lineId,
            ),
        ],
        discountPayload: {
          'discount_amount': cart.discountAmount.toStringAsFixed(3),
        },
        confirmPayload: const {'payment_type': 'cash'},
        localOrderJson: localOrder.toLocalJson(),
      ),
    );

    final queued = await store.load();
    expect(queued, hasLength(1));
    expect(queued.single.itemPayloads.first['unit_price'], '10.000');
    expect(queued.single.itemPayloads.first['discount_percent'], isNull);
    expect(
        queued.single.itemPayloads.first['client_line_id'], 'line-discounted');
    expect(queued.single.discountPayload, {'discount_amount': '7.500'});
    expect(queued.single.localOrder.discountAmount, 7.5);
    expect(queued.single.localOrder.total, 22.5);
  });

  test('offline ticket counter continues from known daily ticket', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OfflineOrderQueueStore();

    await store.rememberTicketNumbers(['W-220626-105']);

    expect(
      await store.reserveTicketNumber(dateStr: '220626'),
      'W-220626-106',
    );
    expect(
      await store.reserveTicketNumber(dateStr: '220626'),
      'W-220626-107',
    );

    await store.rememberTicketNumbers(['W-220626-150']);
    expect(
      await store.reserveTicketNumber(dateStr: '220626'),
      'W-220626-151',
    );
  });

  test('offline order queue preserves fifo order when replacing entries',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = OfflineOrderQueueStore();

    OfflineQueuedOrder entry(String id, {int attempts = 0}) {
      final localOrder = Order(
        id: 'offline-$id',
        ticketNumber: 'W-220626-${id == 'first' ? '101' : '102'}',
        createdAt: DateTime(2026, 6, 22, id == 'first' ? 10 : 11),
        items: const [],
        orderType: OrderType.dineIn,
        paymentType: PaymentType.cash,
        status: OrderStatus.validated,
      );
      return OfflineQueuedOrder(
        clientOrderId: id,
        localOrderId: localOrder.id,
        serverOrderId: null,
        queuedAt: localOrder.createdAt,
        createPayload: {'client_order_id': id},
        itemPayloads: const [],
        discountPayload: null,
        confirmPayload: const {'payment_type': 'cash'},
        localOrderJson: localOrder.toLocalJson(),
        attempts: attempts,
      );
    }

    await store.enqueue(entry('first'));
    await store.enqueue(entry('second'));
    await store.enqueue(entry('first', attempts: 1));

    final queued = await store.load();
    expect(queued.map((entry) => entry.clientOrderId), ['first', 'second']);
    expect(queued.first.attempts, 1);
  });

  test('offline sync applies queued orders by ticket number order', () {
    OfflineQueuedOrder entry({
      required String id,
      required String ticketNumber,
      required DateTime queuedAt,
    }) {
      final localOrder = Order(
        id: 'offline-$id',
        ticketNumber: ticketNumber,
        createdAt: queuedAt,
        items: const [],
        orderType: OrderType.dineIn,
        paymentType: PaymentType.cash,
        status: OrderStatus.validated,
        totalAmount: 0,
        hasBackendTotal: true,
      );
      return OfflineQueuedOrder(
        clientOrderId: id,
        localOrderId: localOrder.id,
        serverOrderId: null,
        queuedAt: queuedAt,
        createPayload: {'client_order_id': id},
        itemPayloads: const [],
        discountPayload: null,
        confirmPayload: {
          'payment_type': 'cash',
          'ticket_number': ticketNumber,
          'client_confirmed_at': queuedAt.toUtc().toIso8601String(),
        },
        localOrderJson: localOrder.toLocalJson(),
      );
    }

    final ordered = orderOfflineQueueForSync([
      entry(
        id: 'late',
        ticketNumber: 'W-220626-103',
        queuedAt: DateTime(2026, 6, 22, 12, 3),
      ),
      entry(
        id: 'early',
        ticketNumber: 'W-220626-101',
        queuedAt: DateTime(2026, 6, 22, 12, 1),
      ),
      entry(
        id: 'middle',
        ticketNumber: 'W-220626-102',
        queuedAt: DateTime(2026, 6, 22, 12, 2),
      ),
    ]);

    expect(
      ordered.map((entry) => entry.localOrder.ticketNumber),
      ['W-220626-101', 'W-220626-102', 'W-220626-103'],
    );
  });
}
