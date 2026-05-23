part of '../app_providers.dart';

class TestModeSession {
  final String id;
  final String deviceId;
  final String status;
  final String? requestedBy;
  final String? approvedBy;
  final DateTime? requestedAt;
  final DateTime? activatedAt;
  final DateTime? endedAt;

  const TestModeSession({
    required this.id,
    required this.deviceId,
    required this.status,
    this.requestedBy,
    this.approvedBy,
    this.requestedAt,
    this.activatedAt,
    this.endedAt,
  });

  factory TestModeSession.fromJson(Map<String, dynamic> json) {
    DateTime? parseTime(String key) {
      final raw = json[key]?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toLocal();
    }

    return TestModeSession(
      id: json['id'].toString(),
      deviceId: json['device_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'inactive',
      requestedBy: json['requested_by_username']?.toString(),
      approvedBy: json['approved_by_username']?.toString(),
      requestedAt: parseTime('requested_at'),
      activatedAt: parseTime('activated_at'),
      endedAt: parseTime('ended_at'),
    );
  }
}

class TestModeState {
  final TestModeSession? session;
  final bool loading;
  final bool requesting;
  final String? message;
  final String? error;

  const TestModeState({
    this.session,
    this.loading = false,
    this.requesting = false,
    this.message,
    this.error,
  });

  String get status => session?.status ?? 'inactive';
  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';

  TestModeState copyWith({
    TestModeSession? session,
    bool clearSession = false,
    bool? loading,
    bool? requesting,
    String? message,
    String? error,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return TestModeState(
      session: clearSession ? null : (session ?? this.session),
      loading: loading ?? this.loading,
      requesting: requesting ?? this.requesting,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TestModeNotifier extends StateNotifier<TestModeState> {
  final Ref ref;
  Timer? _timer;

  TestModeNotifier(this.ref) : super(const TestModeState()) {
    unawaited(refreshCurrent(silent: true));
    _timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(refreshCurrent(silent: true)),
    );
  }

  Future<void> requestTestMode() async {
    state = state.copyWith(
      requesting: true,
      clearError: true,
      clearMessage: true,
    );
    try {
      final snapshot = await PosMonitoringService.instance.snapshot();
      final response = await apiClient.dio.post(
        ApiConstants.testModeSessions,
        data: {
          'device_id': snapshot.deviceId,
          'app_version': snapshot.appVersion,
          'metadata': {
            'api_url': snapshot.apiUrl,
            'platform': 'pos',
          },
        },
      );
      final session = TestModeSession.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      _applySession(session);
      state = state.copyWith(
        requesting: false,
        message: session.status == 'active'
            ? 'Training mode is active.'
            : 'Training request sent to admin.',
      );
    } catch (error) {
      state = state.copyWith(
        requesting: false,
        error: apiClient.describeError(
          error,
          fallback: 'Unable to request training mode.',
        ),
      );
    }
  }

  Future<void> refreshCurrent({bool silent = false}) async {
    if (!silent) state = state.copyWith(loading: true, clearError: true);
    try {
      final deviceId = await PosMonitoringService.instance.deviceId();
      final response = await apiClient.dio.get(
        ApiConstants.testModeCurrent,
        queryParameters: {'device_id': deviceId},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final rawSession = data['session'];
      final session = rawSession is Map
          ? TestModeSession.fromJson(Map<String, dynamic>.from(rawSession))
          : null;
      _applySession(session);
      if (!silent) state = state.copyWith(loading: false);
    } catch (error) {
      if (!silent) {
        state = state.copyWith(
          loading: false,
          error: apiClient.describeError(
            error,
            fallback: 'Unable to refresh training mode status.',
          ),
        );
      }
    }
  }

  Future<void> stopTestMode() async {
    final session = state.session;
    if (session == null) return;

    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await apiClient.dio.patch(
        '${ApiConstants.testModeSessions}${session.id}/deactivate/',
      );
      final updated = TestModeSession.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      _applySession(updated.status == 'inactive' ? null : updated);
      state = state.copyWith(
        loading: false,
        message: 'Training mode stopped. Real POS mode restored.',
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: apiClient.describeError(
          error,
          fallback: 'Unable to stop training mode.',
        ),
      );
    }
  }

  void _applySession(TestModeSession? next) {
    final wasActive = state.isActive;
    final isActive = next?.status == 'active';

    state = state.copyWith(
      session: next,
      clearSession: next == null,
      clearError: true,
    );

    if (!wasActive && isActive) {
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(activeSessionStatusProvider);
      ref.read(ordersProvider.notifier).enterTestMode();
      ref.read(purchasesProvider.notifier).enterTestMode();
      unawaited(ref.read(stockProvider.notifier).fetchStock(
            silent: true,
            force: true,
          ));
      state = state.copyWith(message: 'Training mode approved by admin.');
    } else if (wasActive && !isActive) {
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(activeSessionStatusProvider);
      ref.read(ordersProvider.notifier).exitTestMode();
      ref.read(purchasesProvider.notifier).exitTestMode();
      unawaited(ref.read(stockProvider.notifier).fetchStock(
            force: true,
          ));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final testModeProvider =
    StateNotifierProvider<TestModeNotifier, TestModeState>((ref) {
  return TestModeNotifier(ref);
});
