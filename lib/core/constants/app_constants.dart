class AppConstants {
  AppConstants._();

  static const String appName = 'W Burger - POS';
  static const String appVersion = '1.0.0';

  // QR Code
  static const int qrExpiryMinutes = 5;

  // Pagination
  static const int defaultPageSize = 50;

  // Discount
  static const double maxDiscountPercent = 30.0;

  // Stock alert threshold multiplier
  static const double lowStockWarningMultiplier = 1.5;

  // Currency
  static const String currencySymbol = 'DT';
  static const String currencyCode = 'TND';

  // Loyalty
  static const int pointsPerDinar = 10;
}
