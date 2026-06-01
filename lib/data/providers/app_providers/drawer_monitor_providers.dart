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
  static const Duration _unsupportedRetryInterval = Duration(seconds: 15);

  final Ref _ref;
  Timer? _timer;
  bool? _lastIsOpen;
  bool _isPolling = false;
  bool _disposed = false;
  DateTime? _lastLoggedAt;
  DateTime? _nextStatusProbeAt;

  CashDrawerKeyMonitor(this._ref);

  void start() {
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
    unawaited(_poll());
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    if (_isPolling || _disposed) return;

    final nextStatusProbeAt = _nextStatusProbeAt;
    if (nextStatusProbeAt != null &&
        DateTime.now().isBefore(nextStatusProbeAt)) {
      return;
    }

    final auth = _ref.read(authProvider);
    if (!auth.isAuthenticated) {
      _lastIsOpen = null;
      return;
    }

    _isPolling = true;
    try {
      final status =
          await ReceiptPrinterService.instance.readCashDrawerStatus();
      if (!status.supported) {
        _lastIsOpen = null;
        _nextStatusProbeAt = DateTime.now().add(_unsupportedRetryInterval);
        return;
      }
      _nextStatusProbeAt = null;
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
