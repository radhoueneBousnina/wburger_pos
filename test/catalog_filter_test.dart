import 'package:flutter_test/flutter_test.dart';
import 'package:wburger_pos/data/models/order_models.dart';
import 'package:wburger_pos/data/providers/app_providers.dart';

void main() {
  test('all products follow the visible category order', () {
    const categories = [
      Category(id: 'burgers', name: 'Burgers'),
      Category(id: 'sides', name: 'Sides'),
      Category(id: 'drinks', name: 'Drinks'),
    ];
    const products = [
      Product(
        id: 'cola',
        categoryId: 'drinks',
        name: 'Cola',
        description: '',
        price: 3,
      ),
      Product(
        id: 'fries',
        categoryId: 'sides',
        name: 'Fries',
        description: '',
        price: 5,
      ),
      Product(
        id: 'classic',
        categoryId: 'burgers',
        name: 'Classic Burger',
        description: '',
        price: 12,
      ),
      Product(
        id: 'rings',
        categoryId: 'sides',
        name: 'Onion Rings',
        description: '',
        price: 6,
      ),
      Product(
        id: 'unknown',
        categoryId: 'specials',
        name: 'Special',
        description: '',
        price: 10,
      ),
    ];

    final ordered = orderProductsByCategorySequence(products, categories);

    expect(
      ordered.map((product) => product.id),
      ['classic', 'fries', 'rings', 'cola', 'unknown'],
    );
  });
}
