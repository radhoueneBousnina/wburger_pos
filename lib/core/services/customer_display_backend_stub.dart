import 'customer_display_backend.dart';

CustomerDisplayBackend createCustomerDisplayBackend() =>
    const _NoopCustomerDisplayBackend();

class _NoopCustomerDisplayBackend implements CustomerDisplayBackend {
  const _NoopCustomerDisplayBackend();

  @override
  Future<CustomerDisplayBackendResult> showAmount({
    required String label,
    required String amountText,
    String? preferredSource,
  }) async {
    return const CustomerDisplayBackendResult.disabled();
  }
}
