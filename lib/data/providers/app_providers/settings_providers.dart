part of '../app_providers.dart';

class PosSettingsNotifier extends StateNotifier<AsyncValue<PosSettings>> {
  PosSettingsNotifier({bool autoFetch = true})
      : super(const AsyncValue.data(PosSettings())) {
    if (autoFetch) {
      unawaited(_bootstrapSettings());
    }
  }

  static const _storageKey = 'wburger_pos_settings_v1';

  DateTime? _lastFetchedAt;
  Future<void>? _inFlight;
  SharedPreferences? _prefs;

  Future<void> _bootstrapSettings() async {
    await _loadCachedSettings();
    await fetchSettings(silent: true);
  }

  Future<SharedPreferences> _preferences() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _loadCachedSettings() async {
    try {
      final prefs = await _preferences();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      state = AsyncValue.data(
        PosSettings.fromJson(Map<String, dynamic>.from(decoded)),
      );
    } catch (e) {
      apiClient.logError('Load cached POS settings error', e);
    }
  }

  Future<void> _cacheSettings(PosSettings settings) async {
    try {
      final prefs = await _preferences();
      await prefs.setString(_storageKey, jsonEncode(settings.toJson()));
    } catch (e) {
      apiClient.logError('Cache POS settings error', e);
    }
  }

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
      final settings = PosSettings.fromJson(data);
      _lastFetchedAt = DateTime.now();
      state = AsyncValue.data(settings);
      unawaited(_cacheSettings(settings));
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
