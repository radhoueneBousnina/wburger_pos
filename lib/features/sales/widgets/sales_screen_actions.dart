part of '../screens/sales_screen.dart';

String _salesPaymentLabel(PaymentType? type) {
  if (type == null) return 'Payment pending';
  switch (type) {
    case PaymentType.cash:
      return 'Cash';
    case PaymentType.card:
      return 'Card';
    case PaymentType.staff:
      return 'Staff';
    case PaymentType.other:
      return 'Other';
    case PaymentType.points:
      return 'Points';
    case PaymentType.deal:
      return 'Deal';
  }
}
