class ApiConstants {
  // Base URL for the backend API
  // Use http://10.0.2.2:8000 on Android emulator
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://w-burger.com:8000',
  );
  static const String apiPrefix = '/api/v1';

  // Auth
  static const String login = '$apiPrefix/auth/login/';
  static const String logout = '$apiPrefix/auth/logout/';

  // Catalog
  static const String categories = '$apiPrefix/catalog/categories/';
  static const String products = '$apiPrefix/catalog/products/';
  static const String meals = '$apiPrefix/catalog/meals/';

  // Inventory
  static const String stockItems = '$apiPrefix/inventory/items/';
  static const String stockMovements = '$apiPrefix/inventory/movements/';
  static const String recipes = '$apiPrefix/inventory/recipes/';
  static const String purchases = '$apiPrefix/purchases/';
  static const String purchaseInvoiceUpload = '/invoice-upload-session/';

  // Sales
  static const String orders = '$apiPrefix/sales/orders/';
  static const String lookupByQr = '$apiPrefix/sales/orders/lookup_by_qr/';
  static const String confirmPayment = '/confirm_payment/';
  static const String addItem = '/add_item/';
  static const String printProxy = '$apiPrefix/sales/print-proxy/';
  static const String drawerStatusProxy =
      '$apiPrefix/sales/drawer-status-proxy/';

  static const String dailySessions = '$apiPrefix/sales/daily-sessions/';
  static const String sessionStatus = '$apiPrefix/sales/daily-sessions/status/';
  static const String sessionOpenToday = '${dailySessions}open_today/';
  static const String sessionReopenToday = '${dailySessions}reopen_today/';
  static const String sessionClose = '/close/';
  static const String sessionTpeUpload = '/tpe-upload-session/';

  static const String closures = '$apiPrefix/sales/closures/';
  static const String stockVerificationSubmit =
      '$apiPrefix/sales/stock-verifications/submit/';
  static const String drawerLogs = '$apiPrefix/sales/drawer-logs/';

  // Monitoring
  static const String monitoringEvents = '$apiPrefix/monitoring/events/';
  static const String posHeartbeat = '$apiPrefix/monitoring/pos/heartbeat/';
  static const String testModeSessions =
      '$apiPrefix/monitoring/test-mode-sessions/';
  static const String testModeCurrent =
      '$apiPrefix/monitoring/test-mode-sessions/current/';

  // Utility to resolve image paths to absolute URLs
  static String resolveImageUrl(String? path) {
    if (path == null) return '';
    var value = path.trim();
    if (value.isEmpty) return '';

    if (value.contains('%3A')) {
      try {
        value = Uri.decodeFull(value);
      } catch (_) {}
    }

    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return value;
    }
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('data:') || value.startsWith('blob:')) return value;

    final normalizedPath = value.startsWith('/') ? value : '/$value';
    return '$baseUrl$normalizedPath';
  }

  static String optimizedImageUrl(String? path, int targetSize) {
    final resolved = resolveImageUrl(path);
    if (resolved.isEmpty ||
        resolved.startsWith('data:') ||
        resolved.startsWith('blob:')) {
      return resolved;
    }

    final uri = Uri.tryParse(resolved);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return resolved;
    }

    const mediaSegment = '/media/';
    final mediaIndex = uri.path.indexOf(mediaSegment);
    if (mediaIndex == -1 || uri.path.contains('/media/optimized/')) {
      return resolved;
    }

    final relativePath = uri.path.substring(mediaIndex + mediaSegment.length);
    if (relativePath.isEmpty) return resolved;

    final bucket = targetSize.clamp(96, 1600);
    final mediaBasePath =
        uri.path.substring(0, mediaIndex + mediaSegment.length);
    return uri
        .replace(path: '${mediaBasePath}optimized/$bucket/$relativePath')
        .toString();
  }
}
