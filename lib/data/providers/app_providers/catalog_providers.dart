part of '../app_providers.dart';

class CategoriesNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  CategoriesNotifier() : super(const AsyncValue.loading()) {
    fetchCategories();
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
    return fetchCategories(silent: true);
  }

  Future<void> fetchCategories({
    bool silent = false,
    bool force = false,
  }) {
    if (_inFlight != null && !force) return _inFlight!;

    final future = _fetchCategories(silent: silent);
    _inFlight = future.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  Future<void> _fetchCategories({required bool silent}) async {
    final hadData = state.asData != null;
    try {
      if (!silent || !hadData) {
        state = const AsyncValue.loading();
      }

      final res = await apiClient.dio.get(
        ApiConstants.categories,
        queryParameters: const {'active_only': 'true'},
      );
      final List data =
          res.data is List ? res.data : (res.data['results'] ?? []);

      final List<Category> cats =
          data.map((j) => Category.fromJson(j)).toList();
      cats.insert(
        0,
        const Category(
          id: 'meals',
          name: 'Meals & Combos',
          iconEmoji: '🍔',
          imageUrl: null,
        ),
      );

      _lastFetchedAt = DateTime.now();
      state = AsyncValue.data(cats);
    } catch (e, st) {
      apiClient.logError('Categories error', e);
      if (!silent || !hadData) {
        state = AsyncValue.error(
          apiClient.describeError(
            e,
            fallback: 'Unable to load categories from the server.',
          ),
          st,
        );
      }
    }
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, AsyncValue<List<Category>>>(
        (ref) {
  return CategoriesNotifier();
});

class ProductsNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  ProductsNotifier() : super(const AsyncValue.loading()) {
    fetchProducts();
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
    Duration maxAge = const Duration(minutes: 5),
  }) {
    if (_isFresh(maxAge)) return Future.value();
    return fetchProducts(silent: true);
  }

  Future<void> fetchProducts({
    bool silent = false,
    bool force = false,
  }) {
    if (_inFlight != null && !force) return _inFlight!;

    final future = _fetchProducts(silent: silent);
    _inFlight = future.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  Future<void> _fetchProducts({required bool silent}) async {
    final hadData = state.asData != null;
    try {
      if (!silent || !hadData) {
        state = const AsyncValue.loading();
      }

      final responses = await Future.wait([
        apiClient.dio.get(
          ApiConstants.products,
          queryParameters: const {'active_only': 'true'},
        ),
        apiClient.dio.get(
          ApiConstants.meals,
          queryParameters: const {'active_only': 'true'},
        ),
      ]);

      final List productData = responses[0].data is List
          ? responses[0].data
          : (responses[0].data['results'] ?? []);
      final products = productData.map((j) => Product.fromJson(j)).toList();

      final List mealData = responses[1].data is List
          ? responses[1].data
          : (responses[1].data['results'] ?? []);
      final meals = mealData.map((j) => Product.fromMealJson(j)).toList();

      _lastFetchedAt = DateTime.now();
      state = AsyncValue.data([...meals, ...products]);
    } catch (e, st) {
      apiClient.logError('Products error', e);
      if (!silent || !hadData) {
        state = AsyncValue.error(
          apiClient.describeError(
            e,
            fallback: 'Unable to load products from the server.',
          ),
          st,
        );
      }
    }
  }
}

final productsProvider =
    StateNotifierProvider<ProductsNotifier, AsyncValue<List<Product>>>((ref) {
  return ProductsNotifier();
});

final productsByCategoryProvider =
    Provider.family<AsyncValue<List<Product>>, String>((ref, categoryId) {
  final productsAsync = ref.watch(productsProvider);
  return productsAsync.whenData((products) =>
      products.where((p) => p.categoryId == categoryId && p.isActive).toList());
});

// ============================================================
// STAFF PROVIDER
// ============================================================

class StaffListNotifier extends StateNotifier<AsyncValue<List<StaffMember>>> {
  StaffListNotifier() : super(const AsyncValue.loading()) {
    fetchStaff();
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
    return fetchStaff(silent: true);
  }

  Future<void> fetchStaff({
    bool silent = false,
    bool force = false,
  }) {
    if (_inFlight != null && !force) return _inFlight!;

    final future = _fetchStaff(silent: silent);
    _inFlight = future.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  Future<void> _fetchStaff({required bool silent}) async {
    final hadData = state.asData != null;
    try {
      if (!silent || !hadData) {
        state = const AsyncValue.loading();
      }

      final res = await apiClient.dio.get('/api/v1/accounts/staff/');
      final List data =
          res.data is List ? res.data : (res.data['results'] ?? []);
      _lastFetchedAt = DateTime.now();
      state =
          AsyncValue.data(data.map((j) => StaffMember.fromJson(j)).toList());
    } catch (e, st) {
      apiClient.logError('Staff list error', e);
      if (!silent || !hadData) {
        state = AsyncValue.error(
          apiClient.describeError(
            e,
            fallback: 'Unable to load staff members.',
          ),
          st,
        );
      }
    }
  }
}

final staffListProvider =
    StateNotifierProvider<StaffListNotifier, AsyncValue<List<StaffMember>>>(
        (ref) {
  return StaffListNotifier();
});

// ============================================================
// CART PROVIDER
// ============================================================
