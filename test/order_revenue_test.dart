import 'package:flutter_test/flutter_test.dart';
import 'package:wburger_pos/data/models/order_models.dart';

Map<String, dynamic> _orderJson({
  required String paymentType,
  Object? recognizedRevenue,
}) {
  return {
    'id': '1',
    'ticket_number': 'W-TEST-1',
    'created_at': '2026-09-15T10:00:00Z',
    'service_type': 'dine_in',
    'payment_type': paymentType,
    'status': 'confirmed',
    'total_amount': '10.000',
    'recognized_revenue_amount': recognizedRevenue,
    'items': <dynamic>[],
  };
}

void main() {
  test('uses server-recognized revenue for non-cash payment types', () {
    final points = Order.fromJson(
      _orderJson(paymentType: 'points', recognizedRevenue: '0.000'),
    );
    final settledGlovo = Order.fromJson(
      _orderJson(paymentType: 'glovo', recognizedRevenue: '8.000'),
    );

    expect(points.total, 10);
    expect(points.recognizedRevenue, 0);
    expect(settledGlovo.recognizedRevenue, 8);
  });

  test('falls back to the total for local monetary orders', () {
    final cash = Order.fromJson(
      _orderJson(paymentType: 'cash')..remove('recognized_revenue_amount'),
    );

    expect(cash.recognizedRevenue, 10);
  });
}
