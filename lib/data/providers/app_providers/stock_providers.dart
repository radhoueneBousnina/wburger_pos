part of '../app_providers.dart';

class StockNotifier extends StateNotifier<AsyncValue<List<StockItem>>> {
  StockNotifier() : super(const AsyncValue.loading()) {
    fetchStock();
  }

  DateTime? _lastFetchedAt;
  Future<void>? _inFlight;
  Future<void>? _recipesInFlight;
  bool _trainingMode = false;
  List<StockItem>? _realStockSnapshot;
  List<StockRecipeLine> _recipes = const [];

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
      if (_trainingMode && hadData) {
        _lastFetchedAt = DateTime.now();
        return;
      }
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

  Future<void> fetchRecipes({bool force = false}) {
    if (_recipesInFlight != null && !force) return _recipesInFlight!;

    final future = _fetchRecipes();
    _recipesInFlight = future.whenComplete(() => _recipesInFlight = null);
    return _recipesInFlight!;
  }

  Future<void> _fetchRecipes() async {
    try {
      final res = await apiClient.dio.get(
        ApiConstants.recipes,
        queryParameters: const {'page_size': '500'},
      );
      final List data =
          res.data is List ? res.data : (res.data['results'] ?? []);
      _recipes = data
          .whereType<Map>()
          .map((json) => StockRecipeLine.fromJson(
                Map<String, dynamic>.from(json),
              ))
          .where((line) => line.stockItemId.isNotEmpty && line.quantity > 0)
          .toList();
    } catch (e) {
      apiClient.logError('Fetch recipes error', e);
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

  void applySaleCart(CartState cart) {
    if (cart.items.isEmpty) return;
    final deltas = <String, double>{};

    for (final item in cart.items) {
      final recipeLines = _recipesForProduct(item.product);
      for (final recipe in recipeLines) {
        deltas[recipe.stockItemId] = (deltas[recipe.stockItemId] ?? 0) -
            (recipe.quantity * item.quantity);
      }
    }

    _applyStockDeltas(deltas);
  }

  void restoreSaleCart(CartState cart) {
    if (cart.items.isEmpty) return;
    final deltas = <String, double>{};

    for (final item in cart.items) {
      final recipeLines = _recipesForProduct(item.product);
      for (final recipe in recipeLines) {
        deltas[recipe.stockItemId] = (deltas[recipe.stockItemId] ?? 0) +
            (recipe.quantity * item.quantity);
      }
    }

    _applyStockDeltas(deltas);
  }

  List<StockRecipeLine> _recipesForProduct(Product product) {
    if (product.isMeal) {
      return _recipes.where((line) => line.mealId == product.id).toList();
    }
    return _recipes.where((line) => line.productId == product.id).toList();
  }

  void _applyStockDeltas(Map<String, double> deltas) {
    final current = state.asData?.value;
    if (current == null || deltas.isEmpty) return;

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

  void enterTestMode() {
    _trainingMode = true;
    _realStockSnapshot = state.asData?.value
        .map((item) => item.copyWith(quantity: item.quantity))
        .toList();

    if (state.asData == null) {
      unawaited(fetchStock(silent: true, force: true));
    } else {
      _lastFetchedAt = DateTime.now();
    }
    unawaited(fetchRecipes(force: true));
  }

  void exitTestMode() {
    final snapshot = _realStockSnapshot;
    _trainingMode = false;
    _realStockSnapshot = null;
    _recipes = const [];
    _lastFetchedAt = null;
    if (snapshot == null) {
      state = const AsyncValue.loading();
      unawaited(fetchStock(force: true));
    } else {
      state = AsyncValue.data(snapshot);
      unawaited(fetchStock(silent: true, force: true));
    }
  }
}

final stockProvider =
    StateNotifierProvider<StockNotifier, AsyncValue<List<StockItem>>>((ref) {
  return StockNotifier();
});

// ============================================================
// PURCHASES PROVIDER
// ============================================================
