part of '../app_providers.dart';

class PosConnectionState {
  final bool checked;
  final bool internetOnline;
  final bool backendOnline;
  final DateTime? checkedAt;
  final String message;

  const PosConnectionState({
    required this.checked,
    required this.internetOnline,
    required this.backendOnline,
    required this.checkedAt,
    required this.message,
  });

  const PosConnectionState.initial()
      : checked = false,
        internetOnline = true,
        backendOnline = true,
        checkedAt = null,
        message = '';

  factory PosConnectionState.fromSnapshot(MonitoringSnapshot snapshot) {
    return PosConnectionState(
      checked: true,
      internetOnline: snapshot.internetStatus == 'online',
      backendOnline: snapshot.backendStatus == 'online',
      checkedAt: DateTime.now(),
      message: snapshot.lastError,
    );
  }

  factory PosConnectionState.offline(String message) {
    return PosConnectionState(
      checked: true,
      internetOnline: false,
      backendOnline: false,
      checkedAt: DateTime.now(),
      message: message,
    );
  }

  bool get isOffline => checked && (!internetOnline || !backendOnline);
}

class PosConnectionNotifier extends StateNotifier<PosConnectionState> {
  static const _pollInterval = Duration(seconds: 3);

  Timer? _timer;
  StreamSubscription<void>? _connectionSubscription;
  bool _checking = false;

  PosConnectionNotifier() : super(const PosConnectionState.initial()) {
    _connectionSubscription =
        PosMonitoringService.instance.connectionChanged.listen((_) {
      unawaited(_refreshFromSnapshot());
    });
    unawaited(checkNow());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(checkNow()));
  }

  Future<void> _refreshFromSnapshot() async {
    try {
      final snapshot = await PosMonitoringService.instance.snapshot();
      state = PosConnectionState.fromSnapshot(snapshot);
    } catch (error) {
      state = PosConnectionState.offline(error.toString());
    }
  }

  Future<void> checkNow() async {
    if (_checking) return;
    _checking = true;
    try {
      await PosMonitoringService.instance.sendHeartbeat();
      final snapshot = await PosMonitoringService.instance.snapshot();
      state = PosConnectionState.fromSnapshot(snapshot);
    } catch (error) {
      state = PosConnectionState.offline(error.toString());
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_connectionSubscription?.cancel());
    super.dispose();
  }
}

final posConnectionProvider =
    StateNotifierProvider<PosConnectionNotifier, PosConnectionState>(
  (ref) => PosConnectionNotifier(),
);
