abstract class CustomerDisplayBackend {
  Future<CustomerDisplayBackendResult> showAmount({
    required String label,
    required String amountText,
    String? preferredSource,
  });
}

class CustomerDisplayBackendResult {
  final bool configured;
  final bool success;
  final String? source;
  final String? error;

  const CustomerDisplayBackendResult({
    required this.configured,
    required this.success,
    this.source,
    this.error,
  });

  const CustomerDisplayBackendResult.disabled()
      : configured = false,
        success = false,
        source = null,
        error = null;

  const CustomerDisplayBackendResult.ok({this.source})
      : configured = true,
        success = true,
        error = null;

  const CustomerDisplayBackendResult.failed({
    required this.error,
    this.source,
  })  : configured = true,
        success = false;
}
