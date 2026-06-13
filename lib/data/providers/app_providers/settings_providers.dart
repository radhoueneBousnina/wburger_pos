part of '../app_providers.dart';

class PosSettingsNotifier extends StateNotifier<AsyncValue<PosSettings>> {
  PosSettingsNotifier() : super(const AsyncValue.data(PosSettings())) {
    fetchSettings(silent: true);
  }

  DateTime? _lastFetchedAt;
  Future<void>? _inFlight;

  bool _isFresh(Duration maxAge) {
    final lastFetchedAt = _lastFetchedAt;
    return state.asData != null &&
        lastFetchedAt != null &&
        DateTime.now().difference(lastFetchedAt) < maxAge;
  }

  Future<void> refreshIfStale({
    Duration maxAge = const Duration(minutes: 10),
  }) {
    if (_isFresh(maxAge)) return Future.value();
    return fetchSettings(silent: true);
  }

  Future<void> fetchSettings({
    bool silent = false,
    bool force = false,
  }) {
    if (_inFlight != null && !force) return _inFlight!;

    final future = _fetchSettings(silent: silent);
    _inFlight = future.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  Future<void> _fetchSettings({required bool silent}) async {
    final hadData = state.asData != null;
    try {
      if (!silent || !hadData) {
        state = const AsyncValue.loading();
      }

      final res = await apiClient.dio.get(ApiConstants.posSettings);
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : const <String, dynamic>{};
      _lastFetchedAt = DateTime.now();
      state = AsyncValue.data(PosSettings.fromJson(data));
    } catch (e, st) {
      apiClient.logError('POS settings error', e);
      if (!silent || !hadData) {
        state = AsyncValue.error(
          apiClient.describeError(
            e,
            fallback: 'Unable to load POS settings from the server.',
          ),
          st,
        );
      }
    }
  }
}

final posSettingsProvider =
    StateNotifierProvider<PosSettingsNotifier, AsyncValue<PosSettings>>((ref) {
  return PosSettingsNotifier();
});
