part of '../app_providers.dart';

class StockNotifier extends StateNotifier<AsyncValue<List<StockItem>>> {
  StockNotifier() : super(const AsyncValue.loading()) {
    fetchStock();
  }

  DateTime? _lastFetchedAt;
  Future<void>? _inFlight;
  Future<void>? _recipesInFlight;
  DateTime? _recipesFetchedAt;
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
    final recipesFetchedAt = _recipesFetchedAt;
    if (!force &&
        recipesFetchedAt != null &&
        DateTime.now().difference(recipesFetchedAt) <
            const Duration(minutes: 5)) {
      return Future.value();
    }
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
      final recipeLines = <StockRecipeLine>[];

      String? idFrom(Object? value) {
        if (value is Map) return value['id']?.toString();
        return value?.toString();
      }

      for (final rawRecipe in data.whereType<Map>()) {
        final recipe = Map<String, dynamic>.from(rawRecipe);
        final productId =
            idFrom(recipe['product'] ?? recipe['product_details']);
        final productDetails = recipe['product_details'];
        final productName = productDetails is Map
            ? productDetails['name']?.toString()
            : recipe['product_name']?.toString();
        final items = recipe['items'];
        if (items is! List) {
          recipeLines.add(StockRecipeLine.fromJson(recipe));
          continue;
        }
        for (final rawItem in items.whereType<Map>()) {
          final item = Map<String, dynamic>.from(rawItem);
          if (productId != null && productId.isNotEmpty) {
            item['product'] = productId;
          }
          if (productName != null && productName.isNotEmpty) {
            item['product_name'] = productName;
          }
          recipeLines.add(StockRecipeLine.fromJson(item));
        }
      }

      _recipes = recipeLines
          .where((line) => line.stockItemId.isNotEmpty && line.quantity > 0)
          .toList();
      _recipesFetchedAt = DateTime.now();
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
      _addBaseRecipeDeltas(deltas, item, direction: -1);
      _addSelectedSauceDeltas(deltas, item, direction: -1);
    }

    _applyStockDeltas(deltas);
  }

  void restoreSaleCart(CartState cart) {
    if (cart.items.isEmpty) return;
    final deltas = <String, double>{};

    for (final item in cart.items) {
      _addBaseRecipeDeltas(deltas, item, direction: 1);
      _addSelectedSauceDeltas(deltas, item, direction: 1);
    }

    _applyStockDeltas(deltas);
  }

  List<ProductSauceOption> sauceOptionsForProduct(Product product) {
    if (!product.hasSauces) return const [];
    return _allSauceOptionsForProduct(
      productId: product.id,
      productName: product.name,
    );
  }

  List<MealComponent> saucyMealComponents(Product meal) {
    if (!meal.isMeal) return const [];
    return meal.mealComponents
        .map((component) {
          final options = component.hasSauces
              ? _allSauceOptionsForProduct(
                  productId: component.productId,
                  productName: component.name,
                )
              : const <ProductSauceOption>[];
          return component.copyWith(sauceOptions: options);
        })
        .where((component) => component.sauceOptions.isNotEmpty)
        .toList();
  }

  List<ProductSauceOption> _allSauceOptionsForProduct({
    required String productId,
    required String productName,
  }) {
    final sauceStockItems =
        state.asData?.value.where((item) => item.isSauce).toList() ?? const [];
    if (sauceStockItems.isEmpty) return const [];

    return sauceStockItems.map((stockItem) {
      return ProductSauceOption(
        stockItemId: stockItem.id,
        name: stockItem.name,
        unit: stockItem.unit,
        quantityRequired: 1,
        productId: productId,
        productName: productName,
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void _addBaseRecipeDeltas(
    Map<String, double> deltas,
    CartItem item, {
    required double direction,
  }) {
    if (item.product.isMeal && item.product.mealComponents.isNotEmpty) {
      for (final component in item.product.mealComponents) {
        final componentQuantity =
            component.quantity <= 0 ? 1 : component.quantity;
        for (final recipe in _recipesForProductId(component.productId)) {
          if (recipe.isSauce && component.hasSauces) continue;
          deltas[recipe.stockItemId] = (deltas[recipe.stockItemId] ?? 0) +
              (direction * recipe.quantity * componentQuantity * item.quantity);
        }
      }
      return;
    }

    for (final recipe in _recipesForProduct(item.product)) {
      if (_shouldSkipRecipeLine(item.product, recipe)) continue;
      deltas[recipe.stockItemId] = (deltas[recipe.stockItemId] ?? 0) +
          (direction * recipe.quantity * item.quantity);
    }

    final sodaProduct = item.mealSodaProduct;
    if (item.isMealUpgrade && sodaProduct != null) {
      for (final recipe in _recipesForProduct(sodaProduct)) {
        if (_shouldSkipRecipeLine(sodaProduct, recipe)) continue;
        deltas[recipe.stockItemId] = (deltas[recipe.stockItemId] ?? 0) +
            (direction * recipe.quantity * item.quantity);
      }
    }
  }

  bool _shouldSkipRecipeLine(Product product, StockRecipeLine recipe) {
    return recipe.isSauce && product.hasSauces;
  }

  void _addSelectedSauceDeltas(
    Map<String, double> deltas,
    CartItem item, {
    required double direction,
  }) {
    for (final sauce in item.sauces) {
      if (sauce.stockItemId.isEmpty) continue;
      final portionCount =
          sauce.quantityRequired > 0 ? sauce.quantityRequired : 1;
      final quantity = portionCount *
          _saucePortionQuantity(sauce.stockItemId) *
          _componentQuantityForSauce(item, sauce);
      if (quantity <= 0) continue;
      deltas[sauce.stockItemId] = (deltas[sauce.stockItemId] ?? 0) +
          (direction * quantity * item.quantity);
    }
  }

  double _saucePortionQuantity(String stockItemId) {
    final stockItems = state.asData?.value ?? const <StockItem>[];
    for (final item in stockItems) {
      if (item.id != stockItemId) continue;
      final unit = item.unit.trim().toLowerCase();
      if (unit == 'kg' || unit == 'kilogram' || unit == 'kilograms') {
        return 0.050;
      }
      return 50.000;
    }
    return 50.000;
  }

  int _componentQuantityForSauce(CartItem item, CartSauceSelection sauce) {
    if (!item.product.isMeal) return 1;
    final productId = sauce.productId;
    if (productId == null || productId.isEmpty) return 1;
    for (final component in item.product.mealComponents) {
      if (component.productId == productId) {
        return component.quantity <= 0 ? 1 : component.quantity;
      }
    }
    return 1;
  }

  List<StockRecipeLine> _recipesForProduct(Product product) {
    if (product.isMeal) {
      return _recipes.where((line) => line.mealId == product.id).toList();
    }
    return _recipesForProductId(product.id);
  }

  List<StockRecipeLine> _recipesForProductId(String productId) {
    return _recipes.where((line) => line.productId == productId).toList();
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
    _recipesFetchedAt = null;
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
