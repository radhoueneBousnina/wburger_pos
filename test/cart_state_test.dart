import 'package:flutter_test/flutter_test.dart';
import 'package:wburger_pos/data/models/order_models.dart';
import 'package:wburger_pos/data/providers/app_providers.dart';

void main() {
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
}
