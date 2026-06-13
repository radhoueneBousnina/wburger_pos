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
  });
}
