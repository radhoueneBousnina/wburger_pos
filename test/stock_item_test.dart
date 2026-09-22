import 'package:flutter_test/flutter_test.dart';
import 'package:wburger_pos/data/models/stock_models.dart';

void main() {
  test(
      'stock warning and closure flag defaults off and survives quantity updates',
      () {
    final unchecked = StockItem.fromJson({
      'id': 1,
      'name': 'Paper',
      'current_stock_quantity': '0.000',
      'minimum_threshold': '5.000',
    });
    expect(unchecked.requiresStockCheck, isFalse);
    expect(unchecked.isLowStock, isFalse);
    expect(unchecked.isCritical, isFalse);

    final checked = StockItem.fromJson({
      'id': 2,
      'name': 'Chicken',
      'current_stock_quantity': '0.000',
      'minimum_threshold': '5.000',
      'requires_stock_check': true,
    });
    expect(checked.requiresStockCheck, isTrue);
    expect(checked.isLowStock, isTrue);
    expect(checked.copyWith(quantity: 10).requiresStockCheck, isTrue);
    expect(checked.copyWith(quantity: 10).isLowStock, isFalse);
    final inactive = StockItem.fromJson({
      'id': 3,
      'name': 'Old item',
      'current_stock_quantity': '0.000',
      'minimum_threshold': '5.000',
      'requires_stock_check': true,
      'is_active': false,
    });
    expect(inactive.isActive, isFalse);
    expect(inactive.isLowStock, isFalse);
  });
}
