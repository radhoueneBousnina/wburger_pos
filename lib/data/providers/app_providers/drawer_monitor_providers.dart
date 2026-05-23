part of '../app_providers.dart';

final cashDrawerKeyMonitorProvider = Provider<CashDrawerKeyMonitor>((ref) {
  final monitor = CashDrawerKeyMonitor(ref);
  ref.onDispose(monitor.dispose);
  monitor.start();
  return monitor;
});

class CashDrawerKeyMonitor {
  static const Duration _pollInterval = Duration(seconds: 1);
  static const Duration _logCooldown = Duration(seconds: 4);

  final Ref _ref;
  Timer? _timer;
  bool? _lastIsOpen;
  bool _isPolling = false;
  DateTime? _lastLoggedAt;

  CashDrawerKeyMonitor(this._ref);

  void start() {
    unawaited(_poll());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
  }

  void dispose() {
    _timer?.cancel();
  }

  Future<void> _poll() async {
    if (_isPolling) return;

    final auth = _ref.read(authProvider);
    if (!auth.isAuthenticated) {
      _lastIsOpen = null;
      return;
    }

    _isPolling = true;
    try {
      final status =
          await ReceiptPrinterService.instance.readCashDrawerStatus();
      if (!status.isReliable) return;

      final isOpen = status.isOpen!;
      final wasOpen = _lastIsOpen;
      _lastIsOpen = isOpen;

      if (wasOpen == false && isOpen) {
        await _logPhysicalKeyOpening(status);
      }
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _logPhysicalKeyOpening(CashDrawerStatusResult status) async {
    if (ReceiptPrinterService.instance.consumeExpectedDrawerOpen()) {
      return;
    }

    final now = DateTime.now();
    final lastLoggedAt = _lastLoggedAt;
    if (lastLoggedAt != null && now.difference(lastLoggedAt) < _logCooldown) {
      return;
    }
    _lastLoggedAt = now;

    final source = status.source?.trim();
    final reason = source == null || source.isEmpty
        ? 'Physical key opening detected automatically by printer drawer-status signal.'
        : 'Physical key opening detected automatically by printer drawer-status signal ($source).';

    await _ref.read(ordersProvider.notifier).logKeyOpening(reason);
  }
}
