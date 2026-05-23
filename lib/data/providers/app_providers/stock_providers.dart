part of '../app_providers.dart';

class StockNotifier extends StateNotifier<AsyncValue<List<StockItem>>> {
  StockNotifier() : super(const AsyncValue.loading()) {
    fetchStock();
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
    Duration maxAge = const Duration(seconds: 45),
  }) {
    if (_isFresh(maxAge)) return Future.value();
    return fetchStock(silent: true);
  }

  Future<void> fetchStock({
    bool silent = false,
    bool force = false,
  }) {
    if (_inFlight != null && !force) return _inFlight!;

    final future = _fetchStock(silent: silent);
    _inFlight = future.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  Future<void> _fetchStock({required bool silent}) async {
    final hadData = state.asData != null;
    try {
      if (!silent || !hadData) {
        state = const AsyncValue.loading();
      }
      final res = await apiClient.dio.get(ApiConstants.stockItems);
      final List data =
          res.data is List ? res.data : (res.data['results'] ?? []);
      final stock = data.map((j) => StockItem.fromJson(j)).toList();
      _lastFetchedAt = DateTime.now();
      state = AsyncValue.data(stock);
    } catch (e, st) {
      apiClient.logError('Fetch stock error', e);
      if (!silent || !hadData) {
        state = AsyncValue.error(
          apiClient.describeError(
            e,
            fallback: 'Unable to load stock from the server.',
          ),
          st,
        );
      }
    }
  }

  void applyPurchaseLines(List<Map<String, dynamic>> lines) {
    final current = state.asData?.value;
    if (current == null || lines.isEmpty) return;

    final deltas = <String, double>{};
    for (final line in lines) {
      final stockItemId = line['stock_item']?.toString();
      final quantity = double.tryParse(line['quantity']?.toString() ?? '');
      if (stockItemId == null || quantity == null) continue;
      deltas[stockItemId] = (deltas[stockItemId] ?? 0) + quantity;
    }

    if (deltas.isEmpty) return;

    state = AsyncValue.data(
      current
          .map(
            (item) => deltas.containsKey(item.id)
                ? item.copyWith(quantity: item.quantity + deltas[item.id]!)
                : item,
          )
          .toList(),
    );
    _lastFetchedAt = DateTime.now();
  }
}

final stockProvider =
    StateNotifierProvider<StockNotifier, AsyncValue<List<StockItem>>>((ref) {
  return StockNotifier();
});

// ============================================================
// PURCHASES PROVIDER
// ============================================================
