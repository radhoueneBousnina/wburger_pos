import 'dart:async';

import 'package:flutter/foundation.dart';

import 'customer_display_backend.dart';
import 'customer_display_backend_stub.dart'
    if (dart.library.io) 'customer_display_backend_io.dart';

class CustomerDisplayService {
  CustomerDisplayService._();

  static final CustomerDisplayService instance = CustomerDisplayService._();

  final CustomerDisplayBackend _backend = createCustomerDisplayBackend();
  final ValueNotifier<CustomerDisplayBackendResult?> lastResult =
      ValueNotifier<CustomerDisplayBackendResult?>(null);
  String? _preferredSource;
  Future<void> _pendingWrite = Future<void>.value();

  Future<CustomerDisplayBackendResult> showTotal(double total) async {
    return _writeAmount(label: 'TOTAL', amount: total);
  }

  Future<CustomerDisplayBackendResult> showZeroes() async {
    return _writeAmount(label: 'TOTAL', amount: 0);
  }

  Future<CustomerDisplayBackendResult> showFree() => showZeroes();

  Future<CustomerDisplayBackendResult> _writeAmount({
    required String label,
    required double amount,
  }) {
    final write = _pendingWrite.then(
      (_) => _performWriteAmount(label: label, amount: amount),
    );
    _pendingWrite = write.then<void>((_) {}, onError: (_) {});
    return write;
  }

  Future<CustomerDisplayBackendResult> _performWriteAmount({
    required String label,
    required double amount,
  }) async {
    try {
      final result = await _backend.showAmount(
        label: label,
        amountText: amount.toStringAsFixed(3),
        preferredSource: _preferredSource,
      );
      if (result.success && result.source?.isNotEmpty == true) {
        _preferredSource = result.source;
      }
      lastResult.value = result;
      if (kDebugMode && result.configured && !result.success) {
        debugPrint('[CustomerDisplay] ${result.error}');
      }
      return result;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[CustomerDisplay] $error');
      }
      final result = CustomerDisplayBackendResult.failed(
        error: error.toString(),
        source: _preferredSource,
      );
      lastResult.value = result;
      return result;
    }
  }
}
