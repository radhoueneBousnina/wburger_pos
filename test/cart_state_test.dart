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
}
